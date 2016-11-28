require 'json'
require 'swagger/blocks/version'

module Swagger
  module Blocks

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
        raise Errors::NotSupportedError.new(
          'build_api_json only supports Swagger 1.2, you do not need to call this method ' +
          'for Swagger >= 2.0 definitions.'
        )
      end

      api_node = data[:api_node_map][resource_name.to_sym]
      raise Swagger::Blocks::Errors::NotFoundError.new(
        "Not found: swagger_api_root named #{resource_name}") if !api_node

      # Aggregate all model definitions into a new ModelsNode tree and add it to the JSON.
      temp_models_node = Swagger::Blocks::Nodes::ModelsNode.call(name: 'models') { }
      data[:models_nodes].each { |models_node| temp_models_node.merge!(models_node) }
      result = api_node.as_json
      result.merge!(temp_models_node.as_json) if temp_models_node
      result
    end
  end
end
