module Swagger
  module Blocks
    module Nodes
      # v1.2: http://goo.gl/PvwUXj#522-api-object
      class ApiNode < Node
        def operation(inline_keys = nil, &block)
          self.data[:operations] ||= []
          self.data[:operations] << Swagger::Blocks::Nodes::OperationNode.call(version: version, inline_keys: inline_keys, &block)
        end
      end
    end
  end
end
