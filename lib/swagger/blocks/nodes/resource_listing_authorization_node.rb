module Swagger
  module Blocks
    module Nodes
      # v1.2: NOTE: in the spec this is different than API Declaration authorization.
      # v1.2: http://goo.gl/PvwUXj#515-authorization-object
      class ResourceListingAuthorizationNode < Node
        GRANT_TYPES = [:implicit, :authorization_code].freeze

        def scope(inline_keys = nil, &block)
          self.data[:scopes] ||= []
          self.data[:scopes] << Swagger::Blocks::Nodes::ScopeNode.call(version: version, inline_keys: inline_keys, &block)
        end

        def grant_type(name, inline_keys = nil, &block)
          raise ArgumentError.new("#{name} not in #{GRANT_TYPES}") if !GRANT_TYPES.include?(name)
          self.data[:grantTypes] ||= Swagger::Blocks::Nodes::GrantTypesNode.new
          self.data[:grantTypes].version = version
          self.data[:grantTypes].implicit(inline_keys, &block) if name == :implicit
          self.data[:grantTypes].authorization_code(inline_keys, &block) if name == :authorization_code
        end
      end
    end
  end
end
