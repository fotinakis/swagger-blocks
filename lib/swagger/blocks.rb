require 'json'
require 'swagger/blocks/version'

module Swagger
  module Blocks

    # Some custom error classes.
    class Error < Exception; end
    class DeclarationError < Error; end
    class NotFoundError < Error; end
    class NotSupportedError < Error; end

    # Inject the swagger_root, swagger_api_root, and swagger_model class methods.
    def self.included(base)
      base.extend(ClassMethods)
    end

    def self.build_root_json(swaggered_classes)
      data = Swagger::Blocks::InternalHelpers.parse_swaggered_classes(swaggered_classes)

      if data[:root_node].is_swagger_2_0?
        data[:root_node].key(:paths, data[:path_nodes]) # Required, so no empty check.
        if data[:schema_nodes] && !data[:schema_nodes].empty?
          data[:root_node].key(:definitions, data[:schema_nodes])
        end
      end

      data[:root_node].as_json
    end

    def self.build_api_json(resource_name, swaggered_classes)
      data = Swagger::Blocks::InternalHelpers.parse_swaggered_classes(swaggered_classes)
      if !data[:root_node].is_swagger_1_2?
        raise NotSupportedError.new(
          'build_api_json only supports Swagger 1.2, you do not need to call this method ' +
          'for Swagger >= 2.0 definitions.'
        )
      end

      api_node = data[:api_node_map][resource_name.to_sym]
      raise Swagger::Blocks::NotFoundError.new(
        "Not found: swagger_api_root named #{resource_name}") if !api_node

      # Aggregate all model definitions into a new ModelsNode tree and add it to the JSON.
      temp_models_node = Swagger::Blocks::ModelsNode.call(name: 'models') { }
      data[:models_nodes].each { |models_node| temp_models_node.merge!(models_node) }
      result = api_node.as_json
      result.merge!(temp_models_node.as_json) if temp_models_node
      result
    end

    module InternalHelpers
      # Return [root_node, api_node_map] from all of the given swaggered_classes.
      def self.parse_swaggered_classes(swaggered_classes)
        root_nodes = []

        api_node_map = {}
        models_nodes = []

        path_node_map = {}
        schema_node_map = {}
        swaggered_classes.each do |swaggered_class|
          next unless swaggered_class.respond_to?(:_swagger_nodes, true)
          swagger_nodes = swaggered_class.send(:_swagger_nodes)
          root_node = swagger_nodes[:root_node]
          root_nodes << root_node if root_node

          # 2.0
          if swagger_nodes[:path_node_map]
            path_node_map.merge!(swagger_nodes[:path_node_map])
          end
          if swagger_nodes[:schema_node_map]
            schema_node_map.merge!(swagger_nodes[:schema_node_map])
          end

          # 1.2
          if swagger_nodes[:api_node_map]
            api_node_map.merge!(swagger_nodes[:api_node_map])
          end
          if swagger_nodes[:models_node]
            models_nodes << swagger_nodes[:models_node]
          end
        end
        data = {root_node: self.limit_root_node(root_nodes)}
        if data[:root_node].is_swagger_2_0?
          data[:path_nodes] = path_node_map
          data[:schema_nodes] = schema_node_map
        else
          data[:api_node_map] = api_node_map
          data[:models_nodes] = models_nodes
        end
        data
      end

      # Make sure there is exactly one root_node and return it.
      # TODO should this merge the contents of the root nodes instead?
      def self.limit_root_node(root_nodes)
        if root_nodes.length == 0
          raise Swagger::Blocks::DeclarationError.new(
            'swagger_root must be declared')
        elsif root_nodes.length > 1
          raise Swagger::Blocks::DeclarationError.new(
            'Only one swagger_root declaration is allowed.')
        end
        root_nodes.first
      end
    end

    module ClassMethods
      private

      # v1.2: Defines a Swagger Resource Listing.
      # v1.2: http://goo.gl/PvwUXj#51-resource-listing
      # v2.0: Defines a Swagger Object
      # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#swagger-object
      def swagger_root(inline_keys = nil, &block)
        @swagger_root_node ||= Swagger::Blocks::RootNode.call(inline_keys: inline_keys, &block)
      end

      # v1.2: Defines a Swagger API Declaration.
      # v1.2: http://goo.gl/PvwUXj#52-api-declaration
      # v1.2:
      # v1.2: @param resource_name [Symbol] An identifier for this API. All swagger_api_root declarations
      # v1.2:   with the same resource_name will be  into a single API root node.
      def swagger_api_root(resource_name, inline_keys = nil, &block)
        resource_name = resource_name.to_sym

        # Map of path names to ApiDeclarationNodes.
        @swagger_api_root_node_map ||= {}

        # Grab a previously declared node if it exists, otherwise create a new ApiDeclarationNode.
        # This merges all declarations of swagger_api_root with the same resource_name key.
        api_node = @swagger_api_root_node_map[resource_name]
        if api_node
          # Merge this swagger_api_root declaration into the previous one by the same resource_name.
          api_node.instance_eval(&block)
        else
          # First time we've seen this `swagger_api_root :resource_name`.
          api_node = Swagger::Blocks::ApiDeclarationNode.call(version: '1.2', inline_keys: inline_keys, &block)
        end

        # Add it into the resource_name to node map (may harmlessly overwrite the same object).
        @swagger_api_root_node_map[resource_name] = api_node
      end

      # v2.0: Defines a Swagger Path Item object
      # https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#path-item-object
      def swagger_path(path, &block)
        path = path.to_sym

        # TODO enforce that path name begins with a '/'
        #   (or x- , but need to research Vendor Extensions first)

        @swagger_path_node_map ||= {}

        path_node = @swagger_path_node_map[path]
        if path_node
          # Merge this path declaration into the previous one
          path_node.instance_eval(&block)
        else
          # First time we've seen this path
          @swagger_path_node_map[path] = Swagger::Blocks::PathNode.call(version: '2.0', &block)
        end
      end

      # v1.2: Defines a Swagger Model.
      # v1.2: http://goo.gl/PvwUXj#526-models-object
      def swagger_model(name, inline_keys = nil, &block)
        @swagger_models_node ||= Swagger::Blocks::ModelsNode.new
        @swagger_models_node.version = '1.2'
        @swagger_models_node.model(name, inline_keys, &block)
      end

      # v2.0: Defines a Swagger Definition Schema,
      # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#definitionsObject and
      # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#schema-object
      def swagger_schema(name, inline_keys = nil, &block)
        @swagger_schema_node_map ||= {}

        schema_node = @swagger_schema_node_map[name]
        if schema_node
          # Merge this schema_node declaration into the previous one
          schema_node.instance_eval(&block)
        else
          # First time we've seen this schema_node
          @swagger_schema_node_map[name] = Swagger::Blocks::SchemaNode.call(version: '2.0', inline_keys: inline_keys, &block)
        end
      end

      def _swagger_nodes
        # Avoid initialization warnings.
        @swagger_root_node ||= nil
        @swagger_path_node_map ||= {}
        @swagger_schema_node_map ||= nil
        @swagger_api_root_node_map ||= {}
        @swagger_models_node ||= nil

        data = {root_node: @swagger_root_node}
        data[:path_node_map] = @swagger_path_node_map
        data[:schema_node_map] = @swagger_schema_node_map
        data[:api_node_map] = @swagger_api_root_node_map
        data[:models_node] = @swagger_models_node
        data
      end

    end

    # -----

    # Base node for representing every object in the Swagger DSL.
    class Node
      attr_accessor :name
      attr_writer :version

      def self.call(options = {}, &block)
        # Create a new instance and evaluate the block into it.
        instance = new
        instance.name = options[:name] if options[:name]
        instance.version = options[:version]
        instance.keys options[:inline_keys]
        instance.instance_eval(&block) if block
        instance
      end

      def as_json
        result = {}

        self.data.each do |key, value|
          if value.is_a?(Node)
            result[key] = value.as_json
          elsif value.is_a?(Array)
            result[key] = []
            value.each { |v| result[key] << (v.respond_to?(:as_json) ? v.as_json : v) }
          elsif is_swagger_2_0? && value.is_a?(Hash)
            result[key] = {}
            value.each_pair {|k, v| result[key][k] = (v.respond_to?(:as_json) ? v.as_json : v) }
          elsif is_swagger_2_0? && key.to_s.eql?('$ref') && (value.to_s !~ %r{^#/})
            result[key] = "#/definitions/#{value}"
          else
            result[key] = value
          end
        end
        return result if !name
        # If 'name' is given to this node, wrap the data with a root element with the given name.
        {name => result}
      end

      def data
        @data ||= {}
      end

      def keys(data)
        self.data.merge!(data) if data
      end

      def key(key, value)
        self.data[key] = value
      end

      def version
        return @version if instance_variable_defined?('@version') && @version
        if data.has_key?(:swagger) && data[:swagger] == '2.0'
          '2.0'
        elsif data.has_key?(:swaggerVersion) && data[:swaggerVersion] == '1.2'
          '1.2'
        else
          raise DeclarationError.new("You must specify swaggerVersion '1.2' or swagger '2.0'")
        end
      end

      def is_swagger_1_2?
        version == '1.2'
      end

      def is_swagger_2_0?
        version == '2.0'
      end
    end

    class RootNode < Node
      def initialize(*args)
        # An internal list of the user-defined names that uniquely identify each API tree.
        # Only used in Swagger 1.2, but when initializing a root node we haven't seen the
        # swaggerVersion/swagger key yet
        @api_paths = []
        super
      end

      def has_api_path?(api_path)
        raise NotSupportedError unless is_swagger_1_2?

        api_paths = self.data[:apis].map { |x| x.data[:path] }
        api_paths.include?(api_path)
      end

      def authorization(name, inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_1_2?

        self.data[:authorizations] ||= Swagger::Blocks::ResourceListingAuthorizationsNode.new
        self.data[:authorizations].version = version
        self.data[:authorizations].authorization(name, inline_keys, &block)
      end

      def info(inline_keys = nil, &block)
        self.data[:info] = Swagger::Blocks::InfoNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def api(inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_1_2?

        self.data[:apis] ||= []
        self.data[:apis] << Swagger::Blocks::ResourceNode.call(version: version, inline_keys: inline_keys ,&block)
      end

      def parameter(param, inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_2_0?

        # TODO validate 'param' is as per spec
        self.data[:parameters] ||= {}
        self.data[:parameters][param] = Swagger::Blocks::ParameterNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def response(resp, inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_2_0?

        # TODO validate 'resp' is as per spec
        self.data[:responses] ||= {}
        self.data[:responses][resp] = Swagger::Blocks::ResponseNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def security_definition(name, inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_2_0?

        self.data[:securityDefinitions] ||= {}
        self.data[:securityDefinitions][name] = Swagger::Blocks::SecuritySchemeNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def security(inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_2_0?

        self.data[:security] ||= []
        self.data[:security] << Swagger::Blocks::SecurityRequirementNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def tag(inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_2_0?

        self.data[:tags] ||= []
        self.data[:tags] << Swagger::Blocks::TagNode.call(version: version, inline_keys: inline_keys, &block)
      end

      # Use 'tag' instead.
      # @deprecated
      alias_method :tags, :tag
    end

    # v1.2: http://goo.gl/PvwUXj#512-resource-object
    class ResourceNode < Node; end

    # v1.2: NOTE: in the spec this is different than API Declaration authorizations.
    # v1.2: http://goo.gl/PvwUXj#514-authorizations-object
    class ResourceListingAuthorizationsNode < Node
      def authorization(name, inline_keys = nil, &block)
        self.data[name] = Swagger::Blocks::ResourceListingAuthorizationNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # v1.2: NOTE: in the spec this is different than API Declaration authorization.
    # v1.2: http://goo.gl/PvwUXj#515-authorization-object
    class ResourceListingAuthorizationNode < Node
      GRANT_TYPES = [:implicit, :authorization_code].freeze

      def scope(inline_keys = nil, &block)
        self.data[:scopes] ||= []
        self.data[:scopes] << Swagger::Blocks::ScopeNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def grant_type(name, inline_keys = nil, &block)
        raise ArgumentError.new("#{name} not in #{GRANT_TYPES}") if !GRANT_TYPES.include?(name)
        self.data[:grantTypes] ||= Swagger::Blocks::GrantTypesNode.new
        self.data[:grantTypes].version = version
        self.data[:grantTypes].implicit(inline_keys, &block) if name == :implicit
        self.data[:grantTypes].authorization_code(inline_keys, &block) if name == :authorization_code
      end
    end

    # v1.2: http://goo.gl/PvwUXj#513-info-object
    # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#infoObject
    class InfoNode < Node
      def contact(inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_2_0?

        self.data[:contact] = Swagger::Blocks::ContactNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def license(inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_2_0?

        self.data[:license] = Swagger::Blocks::LicenseNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#contact-object
    class ContactNode < Node; end

    # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#license-object
    class LicenseNode < Node; end

    # v1.2: http://goo.gl/PvwUXj#516-scope-object
    class ScopeNode < Node; end

    # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#scopes-object
    class ScopesNode < Node; end

    # v1.2: http://goo.gl/PvwUXj#517-grant-types-object
    class GrantTypesNode < Node
      def implicit(inline_keys, &block)
        self.data[:implicit] = Swagger::Blocks::ImplicitNode.call(inline_keys: inline_keys, version: version, &block)
      end

      def authorization_code(inline_keys, &block)
        self.data[:authorization_code] = Swagger::Blocks::AuthorizationCodeNode.call(inline_keys: inline_keys, version: version, &block)
      end
    end

    # v1.2: http://goo.gl/PvwUXj#518-implicit-object
    class ImplicitNode < Node
      def login_endpoint(&block)
        self.data[:loginEndpoint] = Swagger::Blocks::LoginEndpointNode.call(version: version, &block)
      end
    end

    # v1.2: http://goo.gl/PvwUXj#5110-login-endpoint-object
    class LoginEndpointNode < Node; end

    # v1.2: http://goo.gl/PvwUXj#519-authorization-code-object
    class AuthorizationCodeNode < Node
      def token_request_endpoint(inline_keys = nil, &block)
        self.data[:tokenRequestEndpoint] = Swagger::Blocks::TokenRequestEndpointNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def token_endpoint(inline_keys = nil, &block)
        self.data[:tokenEndpoint] = Swagger::Blocks::TokenEndpointNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # v1.2: http://goo.gl/PvwUXj#5111-token-request-endpoint-object
    class TokenRequestEndpointNode < Node; end

    # v1.2: http://goo.gl/PvwUXj#5112-token-endpoint-object
    class TokenEndpointNode < Node; end

    # -----
    # v1.2: Nodes for API Declarations.
    # -----

    # v1.2: http://goo.gl/PvwUXj#52-api-declaration
    class ApiDeclarationNode < Node
      def api(inline_keys = nil, &block)
        self.data[:apis] ||= []

        # Important: to conform with the Swagger spec, merge with any previous API declarations
        # that have the same :path key. This ensures that operations affecting the same resource
        # are all in the same operations node.
        #
        # http://goo.gl/PvwUXj#522-api-object
        # - The API Object describes one or more operations on a single path. In the apis array,
        #   there MUST be only one API Object per path.
        temp_api_node = Swagger::Blocks::ApiNode.call(version: version, inline_keys: inline_keys, &block)
        api_node = self.data[:apis].select do |api|
          api.data[:path] == temp_api_node.data[:path]
        end[0]  # Embrace Ruby wtfs.

        if api_node
          # Merge this block with the previous ApiNode by the same path key.
          api_node.instance_eval(&block)
        else
          # First time we've seen an api block with the given path key.
          self.data[:apis] << temp_api_node
        end
      end
    end

    # v1.2: http://goo.gl/PvwUXj#522-api-object
    class ApiNode < Node
      def operation(inline_keys = nil, &block)
        self.data[:operations] ||= []
        self.data[:operations] << Swagger::Blocks::OperationNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#path-item-object
    class PathNode < Node
      OPERATION_TYPES = [:get, :put, :post, :delete, :options, :head, :patch].freeze

      # TODO support ^x- Vendor Extensions
      def operation(op, inline_keys = nil, &block)
        op = op.to_sym
        raise ArgumentError.new("#{name} not in #{OPERATION_TYPES}") if !OPERATION_TYPES.include?(op)
        self.data[op] = Swagger::Blocks::OperationNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def parameter(inline_keys = nil, &block)
        self.data[:parameters] ||= []
        self.data[:parameters] << Swagger::Blocks::ParameterNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # v1.2: http://goo.gl/PvwUXj#523-operation-object
    # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#operation-object
    class OperationNode < Node

      def parameter(inline_keys = nil, &block)
        self.data[:parameters] ||= []
        self.data[:parameters] << Swagger::Blocks::ParameterNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def response_message(inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_1_2?

        self.data[:responseMessages] ||= []
        self.data[:responseMessages] << Swagger::Blocks::Node.call(version: version, inline_keys: inline_keys, &block)
      end

      def authorization(name, inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_1_2?

        self.data[:authorizations] ||= Swagger::Blocks::ApiAuthorizationsNode.new
        self.data[:authorizations].version = version
        self.data[:authorizations].authorization(name, inline_keys, &block)
      end

      def items(inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_1_2?

        self.data[:items] = Swagger::Blocks::ItemsNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def response(resp, inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_2_0?

        # TODO validate 'resp' is as per spec
        self.data[:responses] ||= {}
        self.data[:responses][resp] = Swagger::Blocks::ResponseNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def externalDocs(inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_2_0?

        self.data[:externalDocs] = Swagger::Blocks::ExternalDocsNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def security(inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_2_0?

        self.data[:security] ||= []
        self.data[:security] << Swagger::Blocks::SecurityRequirementNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#externalDocumentationObject
    class ExternalDocsNode < Node; end

    # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#securityRequirementObject
    class SecurityRequirementNode < Node; end

    # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#security-scheme-object
    class SecuritySchemeNode < Node
      # TODO support ^x- Vendor Extensions

      def scopes(inline_keys = nil, &block)
        self.data[:scopes] = Swagger::Blocks::ScopesNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # v1.2: NOTE: in the spec this is different than Resource Listing's authorizations.
    # v1.2: http://goo.gl/PvwUXj#514-authorizations-object
    class ApiAuthorizationsNode < Node
      def authorization(name, inline_keys, &block)
        self.data[name] ||= Swagger::Blocks::ApiAuthorizationNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # v1.2: NOTE: in the spec this is different than Resource Listing's authorization.
    # v1.2: http://goo.gl/PvwUXj#515-authorization-object
    class ApiAuthorizationNode < Node
      def as_json
        # Special case: the API Authorization object is weirdly the only array of hashes.
        # Override the default hash behavior and return an array.
        self.data[:_scopes] ||= []
        self.data[:_scopes].map { |s| s.as_json }
      end

      def scope(inline_keys = nil, &block)
        self.data[:_scopes] ||= []
        self.data[:_scopes] << Swagger::Blocks::ApiAuthorizationScopeNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # v1.2: NOTE: in the spec this is different than Resource Listing's scope object.
    # v1.2: http://goo.gl/PvwUXj#5211-scope-object
    class ApiAuthorizationScopeNode < Node; end

    # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#responseObject
    class ResponseNode < Node
      def schema(inline_keys = nil, &block)
        self.data[:schema] = Swagger::Blocks::SchemaNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def header(head, inline_keys = nil, &block)
        # TODO validate 'head' is as per spec
        self.data[:headers] ||= {}
        self.data[:headers][head] = Swagger::Blocks::HeaderNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def example(exam, inline_keys = nil, &block)
        # TODO validate 'exam' is as per spec
        self.data[:examples] ||= {}
        self.data[:examples][exam] = Swagger::Blocks::ExampleNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    class AllOfNode < Node
      def as_json
        result = []

        self.data.each do |value|
          if value.is_a?(Node)
            result << value.as_json
          elsif value.is_a?(Array)
            r = []
            value.each { |v| r << (v.respond_to?(:as_json) ? v.as_json : v) }
            result << r
          elsif is_swagger_2_0? && value.is_a?(Hash)
            r = {}
            value.each_pair {|k, v| r[k] = (v.respond_to?(:as_json) ? v.as_json : v) }
            result << r
          else
            result = value
          end
        end
        return result if !name
        # If 'name' is given to this node, wrap the data with a root element with the given name.
        {name => result}
      end

      def data
        @data ||= []
      end

      def key(key, value)
        raise NotSupportedError
      end

      def schema(inline_keys = nil, &block)
        data << Swagger::Blocks::SchemaNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#schema-object
    class SchemaNode < Node
      def items(inline_keys = nil, &block)
        self.data[:items] = Swagger::Blocks::ItemsNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def allOf(&block)
        self.data[:allOf] = Swagger::Blocks::AllOfNode.call(version: version, &block)
      end

      def property(name, inline_keys = nil, &block)
        self.data[:properties] ||= Swagger::Blocks::PropertiesNode.new
        self.data[:properties].version = version
        self.data[:properties].property(name, inline_keys, &block)
      end

      def xml(inline_keys = nil, &block)
        self.data[:xml] = Swagger::Blocks::XmlNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def externalDocs(inline_keys = nil, &block)
        self.data[:externalDocs] = Swagger::Blocks::ExternalDocsNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#headerObject
    class HeaderNode < Node
      def items(inline_keys = nil, &block)
        self.data[:items] = Swagger::Blocks::ItemsNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # v2.0:
    class XmlNode < Node; end

    # v2.0:
    class ExampleNode < Node; end

    # v1.2:
    # v2.0:
    class ItemsNode < Node
      def property(name, inline_keys = nil, &block)
        self.data[:properties] ||= Swagger::Blocks::PropertiesNode.new
        self.data[:properties].version = version
        self.data[:properties].property(name, inline_keys, &block)
      end
    end

    # v1.2: http://goo.gl/PvwUXj#524-parameter-object
    # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#parameter-object
    class ParameterNode < Node
      def schema(inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_2_0?

        self.data[:schema] = Swagger::Blocks::SchemaNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def items(inline_keys = nil, &block)
        raise NotSupportedError unless is_swagger_2_0?

        self.data[:items] = Swagger::Blocks::ItemsNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#tag-object
    class TagNode < Node

      # TODO support ^x- Vendor Extensions

      def externalDocs(inline_keys = nil, &block)
        self.data[:externalDocs] = Swagger::Blocks::ExternalDocsNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # -----
    # v1.2: Nodes for Models.
    # -----

    # v1.2: http://goo.gl/PvwUXj#526-models-object
    class ModelsNode < Node
      def merge!(other_models_node)
        self.data.merge!(other_models_node.data)
      end

      def model(name, inline_keys, &block)
        self.data[name] ||= Swagger::Blocks::ModelNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # v1.2: http://goo.gl/PvwUXj#527-model-object
    class ModelNode < Node
      def property(name, inline_keys = nil, &block)
        self.data[:properties] ||= Swagger::Blocks::PropertiesNode.new
        self.data[:properties].version = version
        self.data[:properties].property(name, inline_keys, &block)
      end
    end

    # v1.2: http://goo.gl/PvwUXj#527-model-object
    class PropertiesNode < Node
      def property(name, inline_keys = nil, &block)
        self.data[name] = Swagger::Blocks::PropertyNode.call(version: version, inline_keys: inline_keys, &block)
      end
    end

    # v1.2: http://goo.gl/PvwUXj#527-model-object
    class PropertyNode < Node
      def items(inline_keys = nil, &block)
        self.data[:items] = Swagger::Blocks::ItemsNode.call(version: version, inline_keys: inline_keys, &block)
      end

      def property(name, inline_keys = nil, &block)
        self.data[:properties] ||= Swagger::Blocks::PropertiesNode.new
        self.data[:properties].version = version
        self.data[:properties].property(name, inline_keys, &block)
      end
    end
  end
end
