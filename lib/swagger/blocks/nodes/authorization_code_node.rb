module Swagger
  module Blocks
    module Nodes
      # v1.2: http://goo.gl/PvwUXj#519-authorization-code-object
      class AuthorizationCodeNode < Node
        def token_request_endpoint(inline_keys = nil, &block)
          self.data[:tokenRequestEndpoint] = Swagger::Blocks::Nodes::TokenRequestEndpointNode.call(version: version, inline_keys: inline_keys, &block)
        end

        def token_endpoint(inline_keys = nil, &block)
          self.data[:tokenEndpoint] = Swagger::Blocks::Nodes::TokenEndpointNode.call(version: version, inline_keys: inline_keys, &block)
        end
      end
    end
  end
end
