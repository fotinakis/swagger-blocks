module Swagger
  module Blocks
    module Nodes
      # v1.2: NOTE: in the spec this is different than Resource Listing's authorizations.
      # v1.2: http://goo.gl/PvwUXj#514-authorizations-object
      class ApiAuthorizationsNode < Node
        def authorization(name, inline_keys, &block)
          self.data[name] ||= Swagger::Blocks::Nodes::ApiAuthorizationNode.call(version: version, inline_keys: inline_keys, &block)
        end
      end
    end
  end
end
