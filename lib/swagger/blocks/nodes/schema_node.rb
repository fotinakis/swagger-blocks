module Swagger
  module Blocks
    module Nodes
      # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#schema-object
      class SchemaNode < Node
        def items(inline_keys = nil, &block)
          self.data[:items] = Swagger::Blocks::Nodes::ItemsNode.call(parent: self, version: version, inline_keys: inline_keys, &block)
        end

        def allOf(&block)
          self.data[:allOf] = Swagger::Blocks::Nodes::AllOfNode.call(parent: self, version: version, &block)
        end

        def property(name, inline_keys = nil, &block)
          self.data[:properties] ||= Swagger::Blocks::Nodes::PropertiesNode.new
          self.data[:properties].version = version
          self.data[:properties].property(name, inline_keys, &block)
        end

        def xml(inline_keys = nil, &block)
          self.data[:xml] = Swagger::Blocks::Nodes::XmlNode.call(parent: self, version: version, inline_keys: inline_keys, &block)
        end

        def externalDocs(inline_keys = nil, &block)
          self.data[:externalDocs] = Swagger::Blocks::Nodes::ExternalDocsNode.call(parent: self, version: version, inline_keys: inline_keys, &block)
        end

        def example(inline_keys = nil, &block)
          self.data[:example] = Swagger::Blocks::Nodes::ExampleNode.call(parent: self, version: version, inline_keys: inline_keys, &block)
        end

        def one_of(&block)
          self.data[:oneOf] ||= []
          self.data[:oneOf] << Swagger::Blocks::Nodes::OneOfNode.call(parent: self, version: version, &block)
        end
      end
    end
  end
end
