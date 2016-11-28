module Swagger
  module Blocks
    module Nodes
      # v1.2: http://goo.gl/PvwUXj#518-implicit-object
      class ImplicitNode < Node
        def login_endpoint(&block)
          self.data[:loginEndpoint] = Swagger::Blocks::Nodes::LoginEndpointNode.call(version: version, &block)
        end
      end
    end
  end
end
