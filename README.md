# Swagger::Blocks

[![Build Status](https://travis-ci.org/fotinakis/swagger-blocks.svg?branch=master)](https://travis-ci.org/fotinakis/swagger-blocks)

Swagger::Blocks helps you write API docs in the [Swagger](https://helloreverb.com/developers/swagger) style for your Rails/Sinatra app, and then builds JSON compatible with [Swagger UI](http://petstore.swagger.wordnik.com/#!/pet).

## Features

* Supports **live updating** by design. Change code, refresh your API docs.
* **Works with all Ruby web frameworks** including Rails, Sinatra, etc.
* **100% support** for all features of the [Swagger 1.2 spec](https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md).
* Flexible, you include swagger blocks 

## Installation

Add this line to your application's Gemfile:

    gem 'swagger-blocks'
    
Or install directly with `gem install swagger-blocks`. Requires Ruby 2.1+

## Example (Rails)

Simplified example based on the design for the Petstore [Swagger Sample App](http://petstore.swagger.wordnik.com/#!/pet):

#### PetsController

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
end
```

#### Pet model

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
    property :status do
      key :type, :string
      key :description, 'pet status in the store'
      key :enum, [:available, :pending, :sold]
    end
  end
```

#### Docs controller

```Ruby

class PetsController < ActionController::Base
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
end

```

## Reference

https://github.com/fotinakis/swagger-blocks/blob/master/spec/lib/swagger_blocks_spec.rb

## Contributing

1. Fork it ( https://github.com/fotinakis/swagger-blocks/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Credits

Original idea inspired by **[@richhollis](https://github.com/richhollis/)**'s [swagger-docs](https://github.com/richhollis/swagger-docs/) gem.
