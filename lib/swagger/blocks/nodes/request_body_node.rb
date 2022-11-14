module Swagger
  module Blocks
    module Nodes
      class RequestBodyNode < Node
        def content(type, inline_keys = nil, &block)
          self.data[:content] ||= {}
          self.data[:content][type] = Swagger::Blocks::Nodes::ContentNode.call(parent: self, version: version, inline_keys: inline_keys, &block)
        end
      end
    end
  end
end
