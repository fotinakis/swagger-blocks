module Swagger
  module Blocks
    module Nodes
      # v1.2: http://goo.gl/PvwUXj#52-api-declaration
      class ApiDeclarationNode < Node
        def api(inline_keys = nil, &block)
          self.data[:apis] ||= []

          # Important: to conform with the Swagger spec, merge with any previous API declarations
          # that have the same :path key. This ensures that operations affecting the same resource
          # are all in the same operations node.
          #
          # http://goo.gl/PvwUXj#522-api-object
          # - The API Object describes one or more operations on a single path. In the apis array,
          #   there MUST be only one API Object per path.
          temp_api_node = Swagger::Blocks::Nodes::ApiNode.call(version: version, inline_keys: inline_keys, &block)
          api_node = self.data[:apis].select do |api|
            api.data[:path] == temp_api_node.data[:path]
          end[0]  # Embrace Ruby wtfs.

          if api_node
            # Merge this block with the previous ApiNode by the same path key.
            api_node.instance_eval(&block)
          else
            # First time we've seen an api block with the given path key.
            self.data[:apis] << temp_api_node
          end
        end
      end
    end
  end
end
