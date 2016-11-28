module Swagger
  module Blocks
    module Nodes
      # v1.2: http://goo.gl/PvwUXj#517-grant-types-object
      class GrantTypesNode < Node
        def implicit(inline_keys, &block)
          self.data[:implicit] = Swagger::Blocks::Nodes::ImplicitNode.call(inline_keys: inline_keys, version: version, &block)
        end

        def authorization_code(inline_keys, &block)
          self.data[:authorization_code] = Swagger::Blocks::Nodes::AuthorizationCodeNode.call(inline_keys: inline_keys, version: version, &block)
        end
      end
    end
  end
end
