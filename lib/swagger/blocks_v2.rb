require 'json'
require 'swagger/blocks/version'

module Swagger
  module BlocksV2
    # Some custom error classes.
    class Error < Exception; end
    class DeclarationError < Error; end
    class NotFoundError < Error; end

    # Inject the swagger_root, swagger_api_root, and swagger_model class methods.
    def self.included(base)
      base.extend(ClassMethods)
    end

    def self.build_json(swaggered_classes)
      data = Swagger::BlocksV2::InternalHelpers.
        parse_swaggered_classes(swaggered_classes)
      data[:root].key(:paths, data[:paths]) unless data[:paths].empty?
      data[:root].key(:definitions, data[:definitions]) unless data[:definitions].empty?
      data[:root].as_json
    end

    module InternalHelpers
      # Return [root_node, api_node_map] from all of the given swaggered_classes.
      def self.parse_swaggered_classes(swaggered_classes)
        root_nodes          = []
        path_node_map       = {}
        definition_node_map = {}
        swaggered_classes.each do |swaggered_class|
          next unless swaggered_class.respond_to?(:_swagger_nodes, true)
          swagger_nodes = swaggered_class.send(:_swagger_nodes)
          root_node = swagger_nodes[:root_node]
          root_nodes << root_node if root_node
          path_node_map.merge!(swagger_nodes[:path_node_map])
          definition_node_map.merge!(swagger_nodes[:definition_node_map])
        end
        data = {
          root:        self.limit_root_node(root_nodes),
          paths:       path_node_map,
          definitions: definition_node_map,
        }
        data
      end

      # Make sure there is exactly one root_node and return it.
      def self.limit_root_node(root_nodes)
        if root_nodes.length == 0
          raise Swagger::BlocksV2::DeclarationError.new(
            'swagger_root must be declared')
        elsif root_nodes.length > 1
          raise Swagger::BlocksV2::DeclarationError.new(
            'Only one swagger_root declaration is allowed.')
        end
        root_nodes.first
      end
    end

    module ClassMethods
      private

      # Defines a Swagger Object
      # https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#swagger-object-
      def swagger_root(&block)
        @swagger_root_node ||= Swagger::BlocksV2::RootNode.call(&block)
      end

      # Defines a Swagger API Declaration.
      # http://goo.gl/PvwUXj#52-api-declaration
      #
      # @param resource_name [Symbol] An identifier for this API. All swagger_api_root declarations
      #   with the same resource_name will be merged into a single API root node.
      def swagger_path(path, &block)
        path = path.to_sym

        @swagger_paths_node_map ||= {}

        path_node = @swagger_paths_node_map[path]
        if path_node
          # Merge this path declaration into the previous one
          path_node.instance_eval(&block)
        else
          # First time we've seen this path
          Swagger::BlocksV2::PathNode.call(&block)
          @swagger_paths_node_map[path] = path_node
        end
      end

      # Defines a Swagger Model.
      # http://goo.gl/PvwUXj#526-models-object
      def swagger_definition(name, &block)
        @swagger_definitions_node ||= Swagger::BlocksV2::DefinitionsNode.new
        @swagger_definitions_node.definition(name, &block)
      end

      def _swagger_nodes
        @swagger_root_node           ||= nil  # Avoid initialization warnings
        @swagger_path_node_map       ||= {}
        @swagger_definition_node_map ||= {}
        {
          root_node:           @swagger_root_node,
          path_node_map:       @swagger_path_node_map,
          definition_node_map: @swagger_definition_node_map,
        }
      end
    end

    # -----

    # Base node for representing every object in the Swagger DSL.
    class Node
      attr_accessor :name

      def self.call(options = {}, &block)
        # Create a new instance and evaluate the block into it.
        instance = new
        instance.name = options[:name] if options[:name]
        instance.instance_eval(&block)
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
          else
            result[key] = value
          end
        end
        return result if !name
        # If "name" is given to this node, wrap the data with a root element with the given name.
        {name => result}
      end

      def data
        @data ||= {}
      end

      def key(key, value)
        self.data[key] = value
      end
    end

    # -----
    # Nodes for the Resource Listing.
    # -----

    # https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#swagger-object-
    class RootNode < Node
      def info(&block)
        self.data[:info] = InfoNode.call(&block)
      end

      # def authorization(name, &block)
      #   self.data[:authorizations] ||= Swagger::BlocksV2::ResourceListingAuthorizationsNode.new
      #   self.data[:authorizations].authorization(name, &block)
      # end
    end

    # # http://goo.gl/PvwUXj#512-resource-object
    # class ResourceNode < Node; end

    # # NOTE: in the spec this is different than API Declaration authorizations.
    # # http://goo.gl/PvwUXj#514-authorizations-object
    # class ResourceListingAuthorizationsNode < Node
    #   def authorization(name, &block)
    #     self.data[name] = Swagger::BlocksV2::ResourceListingAuthorizationNode.call(&block)
    #   end
    # end

    # # NOTE: in the spec this is different than API Declaration authorization.
    # # http://goo.gl/PvwUXj#515-authorization-object
    # class ResourceListingAuthorizationNode < Node
    #   GRANT_TYPES = [:implicit, :authorization_code].freeze

    #   def scope(&block)
    #     self.data[:scopes] ||= []
    #     self.data[:scopes] << Swagger::BlocksV2::ScopeNode.call(&block)
    #   end

    #   def grant_type(name, &block)
    #     raise ArgumentError.new("#{name} not in #{GRANT_TYPES}") if !GRANT_TYPES.include?(name)
    #     self.data[:grantTypes] ||= Swagger::BlocksV2::GrantTypesNode.new
    #     self.data[:grantTypes].implicit(&block) if name == :implicit
    #     self.data[:grantTypes].authorization_code(&block) if name == :authorization_code
    #   end
    # end

    # http://goo.gl/PvwUXj#513-info-object
    class InfoNode < Node
      def contact(&block)
        self.data[:contact] = ContactNode.call(&block)
      end

      def license(&block)
        self.data[:license] = LicenseNode.call(&block)
      end
    end

    # https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#contact-object-
    class ContactNode < Node; end

    # https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#license-object-
    class LicenseNode < Node; end

    # # http://goo.gl/PvwUXj#516-scope-object
    # class ScopeNode < Node; end

    # # http://goo.gl/PvwUXj#517-grant-types-object
    # class GrantTypesNode < Node
    #   def implicit(&block)
    #     self.data[:implicit] = Swagger::BlocksV2::ImplicitNode.call(&block)
    #   end

    #   def authorization_code(&block)
    #     self.data[:authorization_code] = Swagger::BlocksV2::AuthorizationCodeNode.call(&block)
    #   end
    # end

    # # http://goo.gl/PvwUXj#518-implicit-object
    # class ImplicitNode < Node
    #   def login_endpoint(&block)
    #     self.data[:loginEndpoint] = Swagger::BlocksV2::LoginEndpointNode.call(&block)
    #   end
    # end

    # # http://goo.gl/PvwUXj#5110-login-endpoint-object
    # class LoginEndpointNode < Node; end

    # # http://goo.gl/PvwUXj#519-authorization-code-object
    # class AuthorizationCodeNode < Node
    #   def token_request_endpoint(&block)
    #     self.data[:tokenRequestEndpoint] = Swagger::BlocksV2::TokenRequestEndpointNode.call(&block)
    #   end

    #   def token_endpoint(&block)
    #     self.data[:tokenEndpoint] = Swagger::BlocksV2::TokenEndpointNode.call(&block)
    #   end
    # end

    # # http://goo.gl/PvwUXj#5111-token-request-endpoint-object
    # class TokenRequestEndpointNode < Node; end

    # # http://goo.gl/PvwUXj#5112-token-endpoint-object
    # class TokenEndpointNode < Node; end

    # -----
    # Nodes for API Declarations.
    # -----

    class PathsNode < Node
      def path(path_str, &block)
        self.data[:paths] ||= {}

        temp_path_node = Swagger::BlocksV2::PathNode.call(&block)
        path_node = self.data[:paths][path_str]

        if path_node
          # Merge this block with the previous PathNode by the same path key.
          path_node.instance_eval(&block)
        else
          # First time we've seen a path block with the given path key.
          self.data[:paths][path_str] = temp_path_node
        end
      end
    end

    class PathNode < Node
      def operation(op, &block)
        # TODO validate operation as per spec
        self.data[:operations] ||= {}
        self.data[:operations][op] = Swagger::BlocksV2::OperationNode.call(&block)
      end
    end

    class OperationNode < Node
      def parameter(&block)
        self.data[:parameters] ||= []
        self.data[:parameters] << Swagger::BlocksV2::ParameterNode.call(&block)
      end

      def response_message(&block)
        self.data[:responseMessages] ||= []
        self.data[:responseMessages] << Swagger::BlocksV2::Node.call(&block)
      end

      # def authorization(name, &block)
      #   self.data[:authorizations] ||= Swagger::BlocksV2::ApiAuthorizationsNode.new
      #   self.data[:authorizations].authorization(name, &block)
      # end

      def items(&block)
        self.data[:items] = Swagger::BlocksV2::ItemsNode.call(&block)
      end
    end

    # # NOTE: in the spec this is different than Resource Listing's authorizations.
    # # http://goo.gl/PvwUXj#514-authorizations-object
    # class ApiAuthorizationsNode < Node
    #   def authorization(name, &block)
    #     self.data[name] ||= Swagger::BlocksV2::ApiAuthorizationNode.call(&block)
    #   end
    # end

    # # NOTE: in the spec this is different than Resource Listing's authorization.
    # # http://goo.gl/PvwUXj#515-authorization-object
    # class ApiAuthorizationNode < Node
    #   def as_json
    #     # Special case: the API Authorization object is weirdly the only array of hashes.
    #     # Override the default hash behavior and return an array.
    #     self.data[:_scopes] ||= []
    #     self.data[:_scopes].map { |s| s.as_json }
    #   end

    #   def scope(&block)
    #     self.data[:_scopes] ||= []
    #     self.data[:_scopes] << Swagger::BlocksV2::ApiAuthorizationScopeNode.call(&block)
    #   end
    # end

    # # NOTE: in the spec this is different than Resource Listing's scope object.
    # # http://goo.gl/PvwUXj#5211-scope-object
    # class ApiAuthorizationScopeNode < Node; end

    # http://goo.gl/PvwUXj#434-items-object
    class ItemsNode < Node; end

    # http://goo.gl/PvwUXj#524-parameter-object
    class ParameterNode < Node; end

    # -----
    # Nodes for Models.
    # -----

    # http://goo.gl/PvwUXj#526-models-object
    class DefinitionsNode < Node
      def merge!(other_definitions_node)
        self.data.merge!(other_definitions_node.data)
      end

      def definition(name, &block)
        self.data[name] ||= Swagger::BlocksV2::DefinitionNode.call(&block)
      end
    end

    # http://goo.gl/PvwUXj#527-model-object
    class DefinitionNode < Node
      def property(name, &block)
        self.data[:properties] ||= Swagger::BlocksV2::PropertiesNode.new
        self.data[:properties].property(name, &block)
      end
    end

    # http://goo.gl/PvwUXj#527-model-object
    class PropertiesNode < Node
      def property(name, &block)
        self.data[name] = Swagger::BlocksV2::PropertyNode.call(&block)
      end
    end

    # http://goo.gl/PvwUXj#527-model-object
    class PropertyNode < Node
      def items(&block)
        self.data[:items] = Swagger::BlocksV2::ItemsNode.call(&block)
      end
    end
  end
end
