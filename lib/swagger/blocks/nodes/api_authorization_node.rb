module Swagger
  module Blocks
    module Nodes
      # v1.2: NOTE: in the spec this is different than Resource Listing's authorization.
      # v1.2: http://goo.gl/PvwUXj#515-authorization-object
      class ApiAuthorizationNode < Node
        def as_json
          # Special case: the API Authorization object is weirdly the only array of hashes.
          # Override the default hash behavior and return an array.
          self.data[:_scopes] ||= []
          self.data[:_scopes].map { |s| s.as_json }
        end

        def scope(inline_keys = nil, &block)
          self.data[:_scopes] ||= []
          self.data[:_scopes] << Swagger::Blocks::Nodes::ApiAuthorizationScopeNode.call(version: version, inline_keys: inline_keys, &block)
        end
      end
    end
  end
end
