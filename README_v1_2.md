# Swagger 1.2 example (Rails)

**NOTE: this is old, you probably want to [use the latest syntax](https://github.com/fotinakis/swagger-blocks).**

This is a simplified example based on the objects in the Petstore [Swagger Sample App](http://petstore.swagger.wordnik.com/#!/pet). For a more complex and complete example, see the [swagger_blocks_spec.rb](https://github.com/fotinakis/swagger-blocks/blob/master/spec/lib/swagger_blocks_spec.rb) file.

Also note that Rails is not required, you can use Swagger::Blocks with any Ruby web framework.

### PetsController

Parameters and features below are defined by the [Swagger 1.2 spec](https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md).

```Ruby
class PetsController < ActionController::Base
  include Swagger::Blocks

  swagger_api_root :pets do
    key :swaggerVersion, '1.2'
    key :apiVersion, '1.0.0'
    key :basePath, 'http://petstore.swagger.wordnik.com/api'
    key :resourcePath, '/pets'
    api do
      key :path, '/pets/{petId}'
      operation do
        key :method, 'GET'
        key :summary, 'Find pet by ID'
        key :notes, 'Returns a pet based on ID'
        key :type, :Pet
        key :nickname, :getPetById
        parameter do
          key :paramType, :path
          key :name, :petId
          key :description, 'ID of pet that needs to be fetched'
          key :required, true
          key :type, :integer
        end
        response_message do
          key :code, 400
          key :message, 'Invalid ID supplied'
        end
        response_message do
          key :code, 404
          key :message, 'Pet not found'
        end
      end
    end
  end

  # ...
end
```

### Pet model

```Ruby
class Pet < ActiveRecord::Base
  include Swagger::Blocks

  swagger_model :Pet do
    key :id, :Pet
    key :required, [:id, :name]
    property :id do
      key :type, :integer
      key :format, :int64
      key :description, 'unique identifier for the pet'
      key :minimum, '0.0'
      key :maximum, '100.0'
    end
    property :name do
      key :type, :string
    end
    property :photoUrls do
      key :type, :array
      items do
        key :type, :string
      end
    end
    property :status do
      key :type, :string
      key :description, 'pet status in the store'
      key :enum, [:available, :pending, :sold]
    end
  end

  # ...
end
```

### Docs controller

To integrate these definitions with Swagger UI, we need a docs controller that can serve the JSON definitions.

```Ruby
resources :apidocs, only: [:index, :show]
```

```Ruby
class ApidocsController < ActionController::Base
  include Swagger::Blocks

  swagger_root do
    key :swaggerVersion, '1.2'
    key :apiVersion, '1.0.0'
    info do
      key :title, 'Swagger Sample App'
    end
    api do
      key :path, '/pets'
      key :description, 'Operations about pets'
    end
  end

  # A list of all classes that have swagger_* declarations.
  SWAGGERED_CLASSES = [
    PetsController,
    Pets,
    self,
  ].freeze

  def index
    render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
  end

  def show
    render json: Swagger::Blocks.build_api_json(params[:id], SWAGGERED_CLASSES)
  end
end

```

The special part of this controller are these lines:

```Ruby
render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
```

```Ruby
render json: Swagger::Blocks.build_api_json(params[:id], SWAGGERED_CLASSES)
```

Those are the only lines necessary to build the root Swagger [Resource Listing](https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#51-resource-listing) JSON and the JSON for each Swagger [API Declaration](https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#52-api-declaration). You simply pass in a list of all the "swaggered" classes in your app.

Now, simply point Swagger UI at `/apidocs` and everything should Just Work™. If you change any of the Swagger block definitions, you can simply refresh Swagger UI to see the changes.
