module Swagger
  module Blocks
    module Nodes
      class ComponentNode < Node
        def schema(name, inline_keys = nil, &block)
          self.data[:schemas] ||= {}
          schema_node = self.data[:schemas][name]

          if schema_node
            # Merge this schema_node declaration into the previous one
            schema_node.instance_eval(&block)
          else
            # First time we've seen this schema_node
            self.data[:schemas][name] = Swagger::Blocks::Nodes::SchemaNode.call(version: '3.0.0', inline_keys: inline_keys, &block)
          end
        end

        def link(name, inline_keys = nil, &block)
          self.data[:links] ||= {}
          self.data[:links][name] = Swagger::Blocks::Nodes::LinkNode.call(version: version, inline_keys: inline_keys, &block)
        end
      end
    end
  end
end
