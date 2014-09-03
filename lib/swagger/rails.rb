require 'json'
require 'swagger/rails/version'

module Swagger::Rails
  def self.included(base)
    base.extend(ClassMethods)
  end

  def self.build_resource_listing_json(resource_listing_class)
    resource_listing_class.send(:_swagger_nodes)[:resource_listing].as_json

    # resource_listing = {}
    # # Build the simple resource_listing keys from the swagger_resource_listing node.
    # resource_listing.merge!(nodes[:resource_listing].data)

    # # Build the resource_listing "apis" key from each of the swagger_api nodes.
    # resource_listing[:apis] = {}
    # nodes[:apis].each do |api_node|
    #   api_data = api_node.data
    #   api_data[:name] = api_node.name

    #   api_node.parameters.each do |parameter_node|
    #     api_data[:parameters] ||= {}
    #     api_data[:parameters] = parameter_node.data
    #   end

    #   resource_listing[:apis].merge!(api_data)
    # end
  end

  def self.build_api_json(resource_class)
  end

  module ClassMethods
    private

    def swagger_resource_listing(&block)
      # There is only one of these allowed per object.
      @swagger_resource_listing_node ||= Swagger::Rails::ResourceListingNode.call(&block)
    end

    def swagger_api_root(name, &block)
      # Each swagger_api declaration appends a new ApiNode.
      node = Swagger::Rails::ApiNode.call(&block)
      @swagger_api_nodes ||= []
      @swagger_api_nodes << node
    end

    def swagger_api_operation(name, &block)
      # Each swagger_api declaration appends a new ApiNode.
      node = Swagger::Rails::Node.call(&block)
    end

    def _swagger_nodes
      {
        resource_listing: @swagger_resource_listing_node || {},
        apis: @swagger_api_nodes || [],
      }
    end
  end

  # -----

  # Nodes that represent each object in the Swagger DSL.
  class Node
    attr_accessor :name

    def self.call(name: nil, &block)
      # Create a new instance and evaluate the block into it.
      instance = new
      instance.instance_eval(&block)

      # Set the first parameter given as the name.
      instance.name = name if name
      instance
    end

    def as_json
      result = {}
      self.data.each do |key, value|
        if value.is_a?(Node)
          result[key] = value.as_json
        elsif value.is_a?(Array)
          result[key] = []
          value.each do |v|
            result[key] << v.as_json
          end
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
      # raise TypeError.new('key values MUST be strings') if !value.is_a?(String) && !value.is_a?(Bool)
      self.data[key] = value
    end
  end

  # -----

  # https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#51-resource-listing
  class ResourceListingNode < Node
    def info(&block)
      self.data[:info] = InfoNode.call(&block)
    end

    def authorization(name, &block)
      self.data[:authorizations] ||= AuthorizationsNode.new
      self.data[:authorizations].authorization(name, &block)
    end
  end

  # https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#514-authorizations-object
  class AuthorizationsNode < Node
    def authorization(name, &block)
      self.data[name] = AuthorizationNode.call(&block)
    end
  end

  # https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#513-info-object
  class AuthorizationNode < Node
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

  # https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#513-info-object
  class InfoNode < Node; end

  # https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#516-scope-object
  class ScopeNode < Node; end

  # https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#517-grant-types-object
  class GrantTypesNode < Node
    def implicit(&block)
      self.data[:implicit] = ImplicitNode.call(&block)
    end

    def authorization_code(&block)
      self.data[:authorization_code] = AuthorizationCodeNode.call(&block)
    end
  end

  # https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#518-implicit-object
  class ImplicitNode < Node
    def login_endpoint(&block)
      self.data[:loginEndpoint] = LoginEndpointNode.call(&block)
    end
  end

  # https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#5110-login-endpoint-object
  class LoginEndpointNode < Node; end

  # https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#519-authorization-code-object
  class AuthorizationCodeNode < Node
    def token_request_endpoint(&block)
      self.data[:tokenRequestEndpoint] = TokenRequestEndpointNode.call(&block)
    end

    def token_endpoint(&block)
      self.data[:tokenEndpoint] = TokenEndpointNode.call(&block)
    end
  end

  # https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#5111-token-request-endpoint-object
  class TokenRequestEndpointNode < Node; end

  # https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#5112-token-endpoint-object
  class TokenEndpointNode < Node; end

  # -----

  # https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#42-file-structure
  class ApiNode < Node
    def operations(&block)
      self.data[:operations] ||= []
      self.data[:operations] << OperationNode.call(&block)
    end
  end

  class OperationNode < Node
    def parameter(name, &block)
      self.data[:parameters] ||= []
      self.data[:parameters] << ParameterNode.call(name: name, &block)
    end

    def response_message(&block)
      self.data[:responseMessages] ||= []
      self.data[:responseMessages] << Node.call(&block)
    end
  end

  # https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#524-parameter-object
  class ParameterNode < Node; end
end
