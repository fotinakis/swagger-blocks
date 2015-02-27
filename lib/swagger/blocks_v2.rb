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
      data[:root].key(:paths, data[:paths]) # required, so no empty? check
      unless data[:definitions].empty?
        data[:root].key(:definitions, data[:definitions])
      end
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

        # TODO enforce that path name begins with a '/'
        #   (or x- , but need to research Vendor Extensions first)

        @swagger_path_node_map ||= {}

        path_node = @swagger_path_node_map[path]
        if path_node
          # Merge this path declaration into the previous one
          path_node.instance_eval(&block)
        else
          # First time we've seen this path
          @swagger_path_node_map[path] =
            Swagger::BlocksV2::PathNode.call(&block)
        end
      end

      # Defines a Swagger Model.
      # http://goo.gl/PvwUXj#526-models-object
      def swagger_definition(name, &block)
        @swagger_definition_node_map ||= {}

        definition_node = @swagger_definition_node_map[name]
        if definition_node
          # Merge this definition_node declaration into the previous one
          definition_node.instance_eval(&block)
        else
          # First time we've seen this definition_node
          @swagger_definition_node_map[name] =
            Swagger::BlocksV2::DefinitionNode.call(&block)
        end
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
          elsif value.is_a?(Hash)
            result[key] = {}
            value.each_pair {|k, v| result[key][k] = (v.respond_to?(:as_json) ? v.as_json : v) }
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

      def parameter(param, &block)
        # TODO validate 'param' is as per spec
        self.data[:parameters] ||= {}
        self.data[:parameters][param] = Swagger::BlocksV2::ParameterNode.call(&block)
      end

      def path(pth, &block)
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

      def definition(name, &block)
        self.data[:definitions] ||= {}

        temp_def_node = Swagger::BlocksV2::DefinitionNode.call(&block)
        def_node = self.data[:definitions][path_str]

        if def_node
          # Merge this block with the previous DefinitionNode by the same key.
          def_node.instance_eval(&block)
        else
          # First time we've seen a definition block with the given key.
          self.data[:definitions][name] = temp_def_node
        end
      end

      def response(resp, &block)
        # TODO validate 'resp' is as per spec
        self.data[:responses] ||= {}
        self.data[:responses][resp] = Swagger::BlocksV2::ResponseNode.call(&block)
      end

      def security_definition(name, &block)
        self.data[:securityDefinitions] ||= {}
        self.data[:securityDefinitions][name] = Swagger::BlocksV2::SecuritySchemeNode.call(&block)
      end

      def security(&block)
        self.data[:security] ||= []
        self.data[:security] << Swagger::BlocksV2::SecurityRequirementNode.call(&block)
      end
    end

    class InfoNode < Node
      def contact(&block)
        self.data[:contact] = ContactNode.call(&block)
      end

      def license(&block)
        self.data[:license] = LicenseNode.call(&block)
      end
    end

    class ContactNode < Node; end

    class LicenseNode < Node; end

    class PathNode < Node
      # TODO support ^x- Vendor Extensions

      def operation(op, &block)
        op = op.to_sym
        # TODO proper exception class
        raise "Invalid operation" unless [:get, :put, :post, :delete,
          :options, :head, :patch].include?(op)
        self.data[op] = Swagger::BlocksV2::OperationNode.call(&block)
      end
    end

    class OperationNode < Node
      def parameter(&block)
        self.data[:parameters] ||= []
        self.data[:parameters] << Swagger::BlocksV2::ParameterNode.call(&block)
      end

      def response(resp, &block)
        # TODO validate 'resp' is as per spec
        self.data[:responses] ||= {}
        self.data[:responses][resp] = Swagger::BlocksV2::ResponseNode.call(&block)
      end

      def externalDocs(&block)
        self.data[:externalDocs] = Swagger::BlocksV2::ExternalDocsNode.call(&block)
      end

      def security(&block)
        self.data[:security] ||= []
        self.data[:security] << Swagger::BlocksV2::SecurityRequirementNode.call(&block)
      end
    end

    class ExternalDocsNode < Node; end

    class SecurityRequirementNode < Node; end

    class SecuritySchemeNode < Node
      # TODO support ^x- Vendor Extensions

      def scope(name, description)
        self.data[:scopes] ||= {}
        self.data[:scopes][name] = description
      end
    end

    class ScopeNode < Node; end

    class ResponseNode < Node
      def schema(&block)
        self.data[:schema] = Swagger::BlocksV2::SchemaNode.call(&block)
      end

      def header(head, &block)
        # TODO validate 'head' is as per spec
        self.data[:headers] ||= {}
        self.data[:headers][head] = Swagger::BlocksV2::HeaderNode.call(&block)
      end

      def example(exam, &block)
        # TODO validate 'exam' is as per spec
        self.data[:examples] ||= {}
        self.data[:examples][exam] = Swagger::BlocksV2::ExampleNode.call(&block)
      end
    end

    class SchemaNode < Node
      def items(&block)
        self.data[:items] = Swagger::BlocksV2::ItemsNode.call(&block)
      end

      # TODO allOf

      # TODO properties

      def xml(&block)
        self.data[:xml] = Swagger::BlocksV2::XmlNode.call(&block)
      end

      def externalDocs(&block)
        self.data[:externalDocs] = Swagger::BlocksV2::ExternalDocsNode.call(&block)
      end

    end

    class HeaderNode < Node
      def items(&block)
        self.data[:items] = Swagger::BlocksV2::ItemsNode.call(&block)
      end
    end

    class XmlNode < Node; end

    class ExampleNode < Node; end

    class ItemsNode < Node; end

    class ParameterNode < Node
      def schema(&block)
        self.data[:schema] = Swagger::BlocksV2::SchemaNode.call(&block)
      end

      def items(&block)
        self.data[:items] = Swagger::BlocksV2::ItemsNode.call(&block)
      end
    end

    class TagNode < Node

      # TODO support ^x- Vendor Extensions

      def externalDocs(&block)
        self.data[:externalDocs] = Swagger::BlocksV2::ExternalDocsNode.call(&block)
      end
    end

    class DefinitionNode < Node
      def property(name, &block)
        self.data[:properties] ||= Swagger::BlocksV2::PropertiesNode.new
        self.data[:properties].property(name, &block)
      end
    end

    class PropertiesNode < Node
      def property(name, &block)
        self.data[name] = Swagger::BlocksV2::PropertyNode.call(&block)
      end
    end

    class PropertyNode < Node
      def items(&block)
        self.data[:items] = Swagger::BlocksV2::ItemsNode.call(&block)
      end
    end
  end
end
