module Swagger
  module Blocks
    module ClassMethods
      private

      # v1.2: Defines a Swagger Resource Listing.
      # v1.2: http://goo.gl/PvwUXj#51-resource-listing
      # v2.0: Defines a Swagger Object
      # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#swagger-object
      def swagger_root(inline_keys = nil, &block)
        @swagger_root_node ||= Swagger::Blocks::Nodes::RootNode.call(inline_keys: inline_keys, &block)
      end

      # v1.2: Defines a Swagger API Declaration.
      # v1.2: http://goo.gl/PvwUXj#52-api-declaration
      # v1.2:
      # v1.2: @param resource_name [Symbol] An identifier for this API. All swagger_api_root declarations
      # v1.2:   with the same resource_name will be  into a single API root node.
      def swagger_api_root(resource_name, inline_keys = nil, &block)
        resource_name = resource_name.to_sym

        # Map of path names to ApiDeclarationNodes.
        @swagger_api_root_node_map ||= {}

        # Grab a previously declared node if it exists, otherwise create a new ApiDeclarationNode.
        # This merges all declarations of swagger_api_root with the same resource_name key.
        api_node = @swagger_api_root_node_map[resource_name]
        if api_node
          # Merge this swagger_api_root declaration into the previous one by the same resource_name.
          api_node.instance_eval(&block)
        else
          # First time we've seen this `swagger_api_root :resource_name`.
          api_node = Swagger::Blocks::Nodes::ApiDeclarationNode.call(version: '1.2', inline_keys: inline_keys, &block)
        end

        # Add it into the resource_name to node map (may harmlessly overwrite the same object).
        @swagger_api_root_node_map[resource_name] = api_node
      end

      # v2.0: Defines a Swagger Path Item object
      # https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#path-item-object
      def swagger_path(path, &block)
        path = path.to_sym

        # TODO enforce that path name begins with a '/'
        #   (or x- , but need to research Vendor Extensions first)

        @swagger_path_node_map ||= {}

        path_node = @swagger_path_node_map[path]
        if path_node
          # Merge this path declaration into the previous one
          path_node.instance_eval(&block)
        else
          # First time we've seen this path
          @swagger_path_node_map[path] = Swagger::Blocks::Nodes::PathNode.call(version: '2.0', &block)
        end
      end

      # v1.2: Defines a Swagger Model.
      # v1.2: http://goo.gl/PvwUXj#526-models-object
      def swagger_model(name, inline_keys = nil, &block)
        @swagger_models_node ||= Swagger::Blocks::Nodes::ModelsNode.new
        @swagger_models_node.version = '1.2'
        @swagger_models_node.model(name, inline_keys, &block)
      end

      # v2.0: Defines a Swagger Definition Schema,
      # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#definitionsObject and
      # v2.0: https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#schema-object
      def swagger_schema(name, inline_keys = nil, &block)
        @swagger_schema_node_map ||= {}

        schema_node = @swagger_schema_node_map[name]
        if schema_node
          # Merge this schema_node declaration into the previous one
          schema_node.instance_eval(&block)
        else
          # First time we've seen this schema_node
          @swagger_schema_node_map[name] = Swagger::Blocks::Nodes::SchemaNode.call(version: '2.0', inline_keys: inline_keys, &block)
        end
      end

      def _swagger_nodes
        # Avoid initialization warnings.
        @swagger_root_node ||= nil
        @swagger_path_node_map ||= {}
        @swagger_schema_node_map ||= nil
        @swagger_api_root_node_map ||= {}
        @swagger_models_node ||= nil

        data = {root_node: @swagger_root_node}
        data[:path_node_map] = @swagger_path_node_map
        data[:schema_node_map] = @swagger_schema_node_map
        data[:api_node_map] = @swagger_api_root_node_map
        data[:models_node] = @swagger_models_node
        data
      end
    end
  end
end
