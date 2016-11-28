module Swagger
  module Blocks
    module Nodes
      # v1.2: http://goo.gl/PvwUXj#524-parameter-object
      # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#parameter-object
      class ParameterNode < Node
        def schema(inline_keys = nil, &block)
          raise NotSupportedError unless is_swagger_2_0?

          self.data[:schema] = Swagger::Blocks::Nodes::SchemaNode.call(version: version, inline_keys: inline_keys, &block)
        end

        def items(inline_keys = nil, &block)
          raise NotSupportedError unless is_swagger_2_0?

          self.data[:items] = Swagger::Blocks::Nodes::ItemsNode.call(version: version, inline_keys: inline_keys, &block)
        end
      end
    end
  end
end
