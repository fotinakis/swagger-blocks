require 'json'
require 'swagger/blocks'

# TODO Test data originally based on the Swagger UI example data

RESOURCE_LISTING_JSON_V3 = open(File.expand_path('../swagger_v3_api_declaration.json', __FILE__)).read

class PetControllerV3
  include Swagger::Blocks

  swagger_root do
    key :openapi, '3.0.0'
    info version: '1.0.1' do
      key :title, 'Swagger Petstore'
      key :description, 'A sample API that uses a petstore as an example to ' \
                        'demonstrate features in the swagger-2.0 specification'
      key :termsOfService, 'http://helloreverb.com/terms/'
      contact do
        key :name, 'Wordnik API Team'
      end
      license do
        key :name, 'MIT'
      end
    end

    server do
      key :url, "http://petstore.swagger.io/v1"
    end

    tag do
      key :name, "dogs"
      key :description, "Dogs"
    end

    tag do
      key :name, "cats"
      key :description, "Cats"
    end
  end

  swagger_path '/pets' do
    operation :get do
      key :summary, 'List all pets'
      key :operationId, 'listPets'
      key :tags, [
        'pets'
      ]
      parameter do
        key :name, :limit
        key :in, :query
        key :description, 'How many items to return at one time (max 100)'
        key :required, false
        schema do
          key :type, :integer
          key :format, :int32
        end
      end
      response 200 do
        key :description, 'A paged array of pets'
        header :'x-next' do
          key :description, 'A link to the next page of responses'
          schema do
            key :type, :string
          end
        end
        content :'application/json' do
          schema do
            key :'$ref', :Pets
          end
        end
      end
      response :default do
        key :description, 'unexpected error'
        content :'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
    end
    operation :post do
      key :summary, 'Create a pet'
      key :operationId, 'createPets'
      key :tags, [
        'pets'
      ]
      parameter do
        key :name, :pet
        key :in, :body
        key :description, 'Pet to add to the store'
        key :required, true
        schema do
          key :'$ref', :PetInput
        end
      end
      response 201 do
        key :description, 'Null response'
      end
      response :default, description: 'unexpected error' do
        content :'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
    end
  end

  swagger_path '/pets/{petId}' do
    operation :get do
      key :summary, 'Info for a specific pet'
      key :operationId, 'showPetById'
      key :tags, [
        'pets'
      ]
      parameter do
        key :name, :petId
        key :in, :path
        key :required, true
        key :description, 'The id of the pet to retrieve'
        schema do
          key :type, 'string'
        end
      end
      response 200 do
        key :description, 'Expected response to a valid request'
        content :'application/json' do
          schema do
            key :'$ref', :Pet
          end
        end
      end
      response :default do
        key :description, 'unexpected error'
        content :'application/json' do
          schema do
            key :'$ref', :Error
          end
        end
      end
    end
  end
end

class PetV3
  include Swagger::Blocks

  swagger_component do
    schema :Pet, required: [:id, :name] do
      property :id do
        key :type, :integer
        key :format, :int64
      end
      property :name do
        key :type, :string
      end
      property :tag do
        key :type, :string
      end
    end

    schema :Pets do
      key :type, :array
      items do
        key :'$ref', :Pet
      end
    end
  end
end

class ErrorModelV3
  include Swagger::Blocks

  swagger_component do
    schema :Error do
      key :required, [:code, :message]
      property :code do
        key :type, :integer
        key :format, :int32
      end
      property :message do
        key :type, :string
      end
    end
  end
end

describe 'Swagger::Blocks v3' do
  describe 'build_json' do
    it 'outputs the correct data' do
      swaggered_classes = [
        PetControllerV3,
        PetV3,
        ErrorModelV3
      ]
      actual = Swagger::Blocks.build_root_json(swaggered_classes)
      actual = JSON.parse(actual.to_json)  # For access consistency.
      data = JSON.parse(RESOURCE_LISTING_JSON_V3)

      # Multiple expectations for better test diff output.
      expect(actual['info']).to eq(data['info'])
      expect(actual['paths']).to be
      expect(actual['paths']['/pets']).to be
      expect(actual['paths']['/pets']).to eq(data['paths']['/pets'])
      expect(actual['paths']['/pets/{petId}']).to be
      expect(actual['paths']['/pets/{petId}']['get']).to be
      expect(actual['paths']['/pets/{petId}']['get']).to eq(data['paths']['/pets/{petId}']['get'])
      expect(actual['paths']).to eq(data['paths'])
      expect(actual['components']).to eq(data['components'])
      expect(actual).to eq(data)
    end
    it 'is idempotent' do
      swaggered_classes = [PetControllerV3, PetV3, ErrorModelV3]
      actual = JSON.parse(Swagger::Blocks.build_root_json(swaggered_classes).to_json)
      data = JSON.parse(RESOURCE_LISTING_JSON_V3)
      expect(actual).to eq(data)
    end
    it 'errors if no swagger_root is declared' do
      expect {
        Swagger::Blocks.build_root_json([])
      }.to raise_error(Swagger::Blocks::DeclarationError)
    end
    it 'errors if multiple swagger_roots are declared' do
      expect {
        Swagger::Blocks.build_root_json([PetControllerV3, PetControllerV3])
      }.to raise_error(Swagger::Blocks::DeclarationError)
    end
  end
end
