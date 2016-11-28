module Swagger
  module Blocks
    module Nodes
      # v1.2: NOTE: in the spec this is different than API Declaration authorizations.
      # v1.2: http://goo.gl/PvwUXj#514-authorizations-object
      class ResourceListingAuthorizationsNode < Node
        def authorization(name, inline_keys = nil, &block)
          self.data[name] = Swagger::Blocks::Nodes::ResourceListingAuthorizationNode.call(version: version, inline_keys: inline_keys, &block)
        end
      end
    end
  end
end
