module Swagger
  module Blocks
    module Nodes
      # v1.2: http://goo.gl/PvwUXj#523-operation-object
      # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#operation-object
      class OperationNode < Node
        def parameter(inline_keys = nil, &block)
          inline_keys = {'$ref' => "#/parameters/#{inline_keys}"} if inline_keys.is_a?(Symbol)

          self.data[:parameters] ||= []
          self.data[:parameters] << Swagger::Blocks::Nodes::ParameterNode.call(version: version, inline_keys: inline_keys, &block)
        end

        def response_message(inline_keys = nil, &block)
          raise NotSupportedError unless is_swagger_1_2?

          self.data[:responseMessages] ||= []
          self.data[:responseMessages] << Swagger::Blocks::Node.call(version: version, inline_keys: inline_keys, &block)
        end

        def authorization(name, inline_keys = nil, &block)
          raise NotSupportedError unless is_swagger_1_2?

          self.data[:authorizations] ||= Swagger::Blocks::Nodes::ApiAuthorizationsNode.new
          self.data[:authorizations].version = version
          self.data[:authorizations].authorization(name, inline_keys, &block)
        end

        def items(inline_keys = nil, &block)
          raise NotSupportedError unless is_swagger_1_2?

          self.data[:items] = Swagger::Blocks::Nodes::ItemsNode.call(version: version, inline_keys: inline_keys, &block)
        end

        def response(resp, inline_keys = nil, &block)
          raise NotSupportedError unless is_swagger_2_0?

          # TODO validate 'resp' is as per spec
          self.data[:responses] ||= {}
          self.data[:responses][resp] = Swagger::Blocks::Nodes::ResponseNode.call(version: version, inline_keys: inline_keys, &block)
        end

        def externalDocs(inline_keys = nil, &block)
          raise NotSupportedError unless is_swagger_2_0?

          self.data[:externalDocs] = Swagger::Blocks::Nodes::ExternalDocsNode.call(version: version, inline_keys: inline_keys, &block)
        end

        def security(inline_keys = nil, &block)
          raise NotSupportedError unless is_swagger_2_0?

          self.data[:security] ||= []
          self.data[:security] << Swagger::Blocks::Nodes::SecurityRequirementNode.call(version: version, inline_keys: inline_keys, &block)
        end
      end
    end
  end
end
