module Swagger
  module Blocks
    module Nodes
      class ContentNode < Node
        def schema(inline_keys = nil, &block)
          self.data[:schema] = Swagger::Blocks::Nodes::SchemaNode.call(version: version, inline_keys: inline_keys, &block)
        end
      end
    end
  end
end
