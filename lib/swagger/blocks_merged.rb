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

    private

    def self.is_swagger_1_2?
      @spec_version.nil? || (@spec_version == ['1', '2'])
    end

    def self.is_swagger_2_0?
      !@spec_version.nil? && (@spec_version == ['2', '0'])
    end

  end
end