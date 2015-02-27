require 'json'
require 'swagger/blocks/version'

module Swagger
  module BlocksMerged

    def spec_version=(spec_version)
      raise NotSupportedError unless ['1.2', '2.0'].include?(spec_version)
      @spec_version ||= spec_version.split('.')
    end

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
      data = Swagger::BlocksMerged::InternalHelpers.
        parse_swaggered_classes(swaggered_classes)

      if is_swagger_2_0?
        data[:root_node].key(:paths, data[:paths]) # required, so no empty? check
        unless data[:definitions].empty?
          data[:root_node].key(:definitions, data[:definitions])
        end
      end

      data[:root_node].as_json
    end

    def self.build_api_json(resource_name, swaggered_classes)
      raise NotSupportedError unless is_swagger_1_2?

      data = Swagger::Blocks::InternalHelpers.parse_swaggered_classes(swaggered_classes)
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
        root_nodes          = []

        api_node_map        = {}
        models_nodes        = []

        path_node_map       = {}
        definition_node_map = {}
        swaggered_classes.each do |swaggered_class|
          next unless swaggered_class.respond_to?(:_swagger_nodes, true)
          swagger_nodes = swaggered_class.send(:_swagger_nodes)
          root_node = swagger_nodes[:root_node]
          root_nodes << root_node if root_node
          if is_swagger_2_0?
            path_node_map.merge!(swagger_nodes[:path_node_map])
            definition_node_map.merge!(swagger_nodes[:definition_node_map])
          else
            api_node_map.merge!(swagger_nodes[:api_node_map])
            models_nodes << swagger_nodes[:models_node] if swagger_nodes[:models_node]
          end
        end
        data = {root_node: self.limit_root_node(root_nodes) }
        if is_swagger_2_0?
          data[:path_nodes]       = path_node_map
          data[:definition_nodes] = definition_node_map
        else
          data[:api_node_map]     = api_node_map
          data[:models_nodes]     = models_nodes
        end
        data
      end

      # Make sure there is exactly one root_node and return it.
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

      # 1.2: Defines a Swagger Resource Listing.
      # 1.2: http://goo.gl/PvwUXj#51-resource-listing
      # 2.0:
      # 2.0:
      def swagger_root(&block)
        @swagger_root_node ||= Swagger::Blocks::RootNode.call(&block)
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

    class RootNode < Node

      def initialize(*args)
        # An internal list of the user-defined names that uniquely identify each API tree.
        if Swagger::BlocksMerged.is_swagger_1_2?
          @api_paths = []
        end
        super
      end

      def has_api_path?(api_path)
        raise NotSupportedError unless is_swagger_1_2?
        api_paths = self.data[:apis].map { |x| x.data[:path] }
        api_paths.include?(api_path)
      end

      def authorization(name, &block)
        raise NotSupportedError unless is_swagger_1_2?
        self.data[:authorizations] ||= Swagger::Blocks::ResourceListingAuthorizationsNode.new
        self.data[:authorizations].authorization(name, &block)
      end

      def info(&block)
        self.data[:info] = InfoNode.call(&block)
      end

      def api(&block)
        raise NotSupportedError unless is_swagger_1_2?
        self.data[:apis] ||= []
        self.data[:apis] << Swagger::Blocks::ResourceNode.call(&block)
      end

      def parameter(param, &block)
        raise NotSupportedError unless is_swagger_2_0?
        # TODO validate 'param' is as per spec
        self.data[:parameters] ||= {}
        self.data[:parameters][param] = Swagger::BlocksV2::ParameterNode.call(&block)
      end

      def path(pth, &block)
        raise NotSupportedError unless is_swagger_2_0?

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
        raise NotSupportedError unless is_swagger_2_0?

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
        raise NotSupportedError unless is_swagger_2_0?

        # TODO validate 'resp' is as per spec
        self.data[:responses] ||= {}
        self.data[:responses][resp] = Swagger::BlocksV2::ResponseNode.call(&block)
      end

      def security_definition(name, &block)
        raise NotSupportedError unless is_swagger_2_0?

        self.data[:securityDefinitions] ||= {}
        self.data[:securityDefinitions][name] = Swagger::BlocksV2::SecuritySchemeNode.call(&block)
      end

      def security(&block)
        raise NotSupportedError unless is_swagger_2_0?

        self.data[:security] ||= []
        self.data[:security] << Swagger::BlocksV2::SecurityRequirementNode.call(&block)
      end
    end

    private

    def self.is_swagger_1_2?
      @spec_version.nil? || (@spec_version == ['1', '2'])
    end

    def self.is_swagger_2_0?
      !@spec_version.nil? && (@spec_version == ['2', '0'])
    end

  end
end