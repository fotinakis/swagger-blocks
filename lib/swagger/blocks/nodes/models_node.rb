module Swagger
  module Blocks
    module Nodes
      # v1.2: http://goo.gl/PvwUXj#526-models-object
      class ModelsNode < Node
        def merge!(other_models_node)
          self.data.merge!(other_models_node.data)
        end

        def model(name, inline_keys, &block)
          self.data[name] ||= Swagger::Blocks::Nodes::ModelNode.call(version: version, inline_keys: inline_keys, &block)
        end
      end
    end
  end
end
