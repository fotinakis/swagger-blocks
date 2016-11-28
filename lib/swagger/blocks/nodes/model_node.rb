module Swagger
  module Blocks
    module Nodes
      # v1.2: http://goo.gl/PvwUXj#527-model-object
      class ModelNode < Node
        def property(name, inline_keys = nil, &block)
          self.data[:properties] ||= Swagger::Blocks::Nodes::PropertiesNode.new
          self.data[:properties].version = version
          self.data[:properties].property(name, inline_keys, &block)
        end
      end
    end
  end
end
