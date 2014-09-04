require 'json'
require 'swagger/rails/version'

module Swagger::Rails
  # Some custom error classes.
  class Error < Exception; end
  class DeclarationError < Error; end
  class NotFoundError < Error; end

  # Inject the swagger_root, swagger_api_root, and swagger_model class methods.
  def self.included(base)
    base.extend(ClassMethods)
  end

  module_function def build_root_json(swaggered_classes)
    data = InternalHelpers.parse_swaggered_classes(swaggered_classes)
    data[:root_node].as_json
  end

  module_function def build_api_json(resource_name, swaggered_classes)
    data = InternalHelpers.parse_swaggered_classes(swaggered_classes)
    api_node = data[:api_node_map][resource_name.to_sym]
    raise Swagger::Rails::NotFoundError.new(
      "Not found: swagger_api_root named #{resource_name}") if !api_node

    # Aggregate all model definitions into a new ModelsNode tree and add it to the JSON.
    temp_models_node = Swagger::Rails::ModelsNode.call(name: 'models') { }
    data[:models_nodes].each do |models_node|
      temp_models_node.merge!(models_node)
    end
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
      swaggered_classes.each do |swaggered_class|
        next if !swaggered_class.respond_to?(:_swagger_nodes, true)
        swagger_nodes = swaggered_class.send(:_swagger_nodes)
        root_node = swagger_nodes[:resource_listing_node]
        root_nodes << root_node if root_node
        api_node_map.merge!(swagger_nodes[:api_node_map])
        models_nodes << swagger_nodes[:models_node] if swagger_nodes[:models_node]
      end
      root_node = self.get_resource_listing(root_nodes)

      {
        root_node: root_node,
        api_node_map: api_node_map,
        models_nodes: models_nodes,
      }
    end

    # Make sure there is exactly one root_node and return it.
    def self.get_resource_listing(root_nodes)
      if root_nodes.length == 0
        raise Swagger::Rails::DeclarationError.new(
          'swagger_root must be declared')
      elsif root_nodes.length > 1
        raise Swagger::Rails::DeclarationError.new(
          'Only one swagger_root declaration is allowed.')
      end
      root_nodes.first
    end
  end

  module ClassMethods
    private

    # Defines a Swagger Resource Listing.
    # http://goo.gl/PvwUXj#51-resource-listing
    def swagger_root(&block)
      @swagger_root_node ||= Swagger::Rails::ResourceListingNode.call(&block)
    end

    # Defines a Swagger API Declaration.
    # http://goo.gl/PvwUXj#52-api-declaration
    #
    # @param resource_name [Symbol] An identifier for this API. All swagger_api_root declarations
    #   with the same resource_name will be merged into a single API root node.
    def swagger_api_root(resource_name, &block)
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
        api_node = Swagger::Rails::ApiDeclarationNode.call(&block)
      end

      # Add it into the resource_name to node map (may harmlessly overwrite the same object).
      @swagger_api_root_node_map[resource_name] = api_node
    end

    # Defines a Swagger Model.
    # http://goo.gl/PvwUXj#526-models-object
    def swagger_model(name, &block)
      @swagger_models_node ||= Swagger::Rails::ModelsNode.new
      @swagger_models_node.model(name, &block)
    end

    def _swagger_nodes
      @swagger_root_node ||= nil  # Avoid initialization warnings.
      @swagger_api_root_node_map ||= {}
      @swagger_models_node ||= nil
      {
        resource_listing_node: @swagger_root_node,
        api_node_map: @swagger_api_root_node_map,
        models_node: @swagger_models_node,
      }
    end
  end

  # -----

  # Base node for representing every object in the Swagger DSL.
  class Node
    attr_accessor :name

    def self.call(name: nil, &block)
      # Create a new instance and evaluate the block into it.
      instance = new
      instance.name = name if name # Set the first parameter given as the name.
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

  # http://goo.gl/PvwUXj#51-resource-listing
  class ResourceListingNode < Node
    def initialize(*args)
      # An internal list of the user-defined names that uniquely identify each API tree.
      @api_paths = []
      super
    end

    def has_api_path?(api_path)
      api_paths = self.data[:apis].map { |x| x.data[:path] }
      api_paths.include?(api_path)
    end

    def info(&block)
      self.data[:info] = InfoNode.call(&block)
    end

    def authorization(name, &block)
      self.data[:authorizations] ||= ResourceListingAuthorizationsNode.new
      self.data[:authorizations].authorization(name, &block)
    end

    def api(&block)
      self.data[:apis] ||= []
      self.data[:apis] << ResourceNode.call(&block)
    end
  end

  # http://goo.gl/PvwUXj#512-resource-object
  class ResourceNode < Node; end

  # NOTE: in the spec this is different than API Declaration authorizations.
  # http://goo.gl/PvwUXj#514-authorizations-object
  class ResourceListingAuthorizationsNode < Node
    def authorization(name, &block)
      self.data[name] = ResourceListingAuthorizationNode.call(&block)
    end
  end

  # NOTE: in the spec this is different than API Declaration authorization.
  # http://goo.gl/PvwUXj#515-authorization-object
  class ResourceListingAuthorizationNode < Node
    GRANT_TYPES = [:implicit, :authorization_code].freeze

    def scope(&block)
      self.data[:scopes] ||= []
      self.data[:scopes] << ScopeNode.call(&block)
    end

    def grant_type(name, &block)
      raise ArgumentError.new("#{name} not in #{GRANT_TYPES}") if !GRANT_TYPES.include?(name)
      self.data[:grantTypes] ||= GrantTypesNode.new
      self.data[:grantTypes].implicit(&block) if name == :implicit
      self.data[:grantTypes].authorization_code(&block) if name == :authorization_code
    end
  end

  # http://goo.gl/PvwUXj#513-info-object
  class InfoNode < Node; end

  # http://goo.gl/PvwUXj#516-scope-object
  class ScopeNode < Node; end

  # http://goo.gl/PvwUXj#517-grant-types-object
  class GrantTypesNode < Node
    def implicit(&block)
      self.data[:implicit] = ImplicitNode.call(&block)
    end

    def authorization_code(&block)
      self.data[:authorization_code] = AuthorizationCodeNode.call(&block)
    end
  end

  # http://goo.gl/PvwUXj#518-implicit-object
  class ImplicitNode < Node
    def login_endpoint(&block)
      self.data[:loginEndpoint] = LoginEndpointNode.call(&block)
    end
  end

  # http://goo.gl/PvwUXj#5110-login-endpoint-object
  class LoginEndpointNode < Node; end

  # http://goo.gl/PvwUXj#519-authorization-code-object
  class AuthorizationCodeNode < Node
    def token_request_endpoint(&block)
      self.data[:tokenRequestEndpoint] = TokenRequestEndpointNode.call(&block)
    end

    def token_endpoint(&block)
      self.data[:tokenEndpoint] = TokenEndpointNode.call(&block)
    end
  end

  # http://goo.gl/PvwUXj#5111-token-request-endpoint-object
  class TokenRequestEndpointNode < Node; end

  # http://goo.gl/PvwUXj#5112-token-endpoint-object
  class TokenEndpointNode < Node; end

  # -----
  # Nodes for API Declarations.
  # -----

  # http://goo.gl/PvwUXj#52-api-declaration
  class ApiDeclarationNode < Node
    def api(&block)
      self.data[:apis] ||= []

      # Important: to conform with the Swagger spec, merge with any previous API declarations
      # that have the same :path key. This ensures that operations affecting the same resource
      # are all in the same operations node.
      #
      # http://goo.gl/PvwUXj#522-api-object
      # - The API Object describes one or more operations on a single path. In the apis array,
      #   there MUST be only one API Object per path.
      temp_api_node = ApiNode.call(&block)
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

  # http://goo.gl/PvwUXj#522-api-object
  class ApiNode < Node
    def operation(&block)
      self.data[:operations] ||= []
      self.data[:operations] << OperationNode.call(&block)
    end
  end

  class OperationNode < Node
    def parameter(&block)
      self.data[:parameters] ||= []
      self.data[:parameters] << ParameterNode.call(&block)
    end

    def response_message(&block)
      self.data[:responseMessages] ||= []
      self.data[:responseMessages] << Node.call(&block)
    end

    def authorization(name, &block)
      self.data[:authorizations] ||= ApiAuthorizationsNode.new
      self.data[:authorizations].authorization(name, &block)
    end

    def items(&block)
      self.data[:items] = ItemsNode.call(&block)
    end
  end

  # NOTE: in the spec this is different than Resource Listing's authorizations.
  # http://goo.gl/PvwUXj#514-authorizations-object
  class ApiAuthorizationsNode < Node
    def authorization(name, &block)
      self.data[name] ||= ApiAuthorizationNode.call(&block)
    end
  end

  # NOTE: in the spec this is different than Resource Listing's authorization.
  # http://goo.gl/PvwUXj#515-authorization-object
  class ApiAuthorizationNode < Node
    def as_json
      # Special case: the API Authorization object is weirdly the only array of hashes.
      # Override the default hash behavior and return an array.
      self.data[:_scopes] ||= []
      self.data[:_scopes].map { |s| s.as_json }
    end

    def scope(&block)
      self.data[:_scopes] ||= []
      self.data[:_scopes] << ApiAuthorizationScopeNode.call(&block)
    end
  end

  # NOTE: in the spec this is different than Resource Listing's scope object.
  # http://goo.gl/PvwUXj#5211-scope-object
  class ApiAuthorizationScopeNode < Node; end

  # http://goo.gl/PvwUXj#434-items-object
  class ItemsNode < Node; end

  # http://goo.gl/PvwUXj#524-parameter-object
  class ParameterNode < Node; end

  # -----
  # Nodes for Models.
  # -----

  # http://goo.gl/PvwUXj#526-models-object
  class ModelsNode < Node
    def merge!(other_models_node)
      self.data.merge!(other_models_node.data)
    end

    def model(name, &block)
      self.data[name] ||= ModelNode.call(&block)
    end
  end

  # http://goo.gl/PvwUXj#527-model-object
  class ModelNode < Node
    def property(name, &block)
      self.data[:properties] ||= PropertiesNode.new
      self.data[:properties].property(name, &block)
    end
  end

  # http://goo.gl/PvwUXj#527-model-object
  class PropertiesNode < Node
    def property(name, &block)
      self.data[name] = PropertyNode.call(&block)
    end
  end

  # http://goo.gl/PvwUXj#527-model-object
  class PropertyNode < Node
    def items(&block)
      self.data[:items] = ItemsNode.call(&block)
    end
  end
end
