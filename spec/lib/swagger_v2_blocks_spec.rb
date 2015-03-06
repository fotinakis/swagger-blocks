require 'json'
require 'swagger/blocks'

# TODO Test data originally based on the Swagger UI example data

RESOURCE_LISTING_JSON_V2 = open(File.expand_path('../swagger_v2_partial.json', __FILE__)).read

class PetControllerV2
  include Swagger::Blocks

  swagger_root do
    key :swagger, '2.0'
    info do
      key :version, "1.0.0"
      key :title, 'Swagger Petstore'
      key :description, "A sample API that uses a petstore as an example to " \
                        "demonstrate features in the swagger-2.0 specification"
      key :termsOfService, 'http://helloreverb.com/terms/'
      contact do
        key :name, "Wordnik API Team"
      end
      license do
        key :name, 'MIT'
      end
    end
    key :host, "petstore.swagger.wordnik.com"
    key :basePath, "/api"
    key :schemes, ["http"]
    key :consumes, ["application/json"]
    key :produces, ["application/json"]
  end

  swagger_path('/pets') do
    operation('get') do
      key :description, "Returns all pets from the system that the user has access to"
      key :operationId, 'findPets'
      key :produces, [
        "application/json",
        "application/xml",
        "text/xml",
        "text/html"
      ]
      parameter do
        key :name, :tags
        key :in, :query
        key :description, "tags to filter by"
        key :required, false
        key :type, :array
        items do
          key :type, :string
        end
        key :collectionFormat, :csv
      end
      parameter do
        key :name, :limit
        key :in, :query
        key :description, "maximum number of results to return"
        key :required, false
        key :type, :integer
        key :format, :int32
      end
      response('200') do
        key :description, "pet response"
        schema do
          key :type, :array
          items do
            key :"$ref", "#/definitions/pet" # TODO reference by definition name
          end
        end
      end
      response('default') do
        key :description, "unexpected error"
        schema do
          key :"$ref", "#/definitions/errorModel"  # TODO reference by definition name
        end
      end
    end
  end

end

class PetV2
  include Swagger::Blocks

  swagger_definition(:pet) do
    key :required, [:id, :name]
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

  # TODO JSON-Schema 'allOf' and similar

end

class ErrorModelV2
  include Swagger::Blocks

  swagger_definition(:errorModel) do
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

describe 'Swagger::Blocks v2' do

  describe 'v2 build_json' do
    it 'outputs the correct data' do
      swaggered_classes = [
        PetControllerV2,
        PetV2,
        ErrorModelV2
      ]
      actual = Swagger::Blocks.build_root_json(swaggered_classes)

      # Multiple expectations for better test diff output.
      actual = JSON.parse(actual.to_json)  # For access consistency.
      data = JSON.parse(RESOURCE_LISTING_JSON_V2)

      expect(actual['info']).to eq(data['info'])
      expect(actual['paths']).to eq(data['paths'])
      expect(actual['definitions']).to eq(data['definitions'])
      expect(actual).to eq(data)
    end
    it 'is idempotent' do
      swaggered_classes = [PetControllerV2, PetV2, ErrorModelV2]
      actual = JSON.parse(Swagger::Blocks.build_root_json(swaggered_classes).to_json)
      actual = JSON.parse(Swagger::Blocks.build_root_json(swaggered_classes).to_json)
      data = JSON.parse(RESOURCE_LISTING_JSON_V2)
      expect(actual).to eq(data)
    end
    it 'errors if no swagger_root is declared' do
      expect {
        Swagger::Blocks.build_root_json([])
      }.to raise_error(Swagger::Blocks::DeclarationError)
    end
    it 'errors if mulitple swagger_roots are declared' do
      expect {
        Swagger::Blocks.build_root_json([PetControllerV2, PetControllerV2])
      }.to raise_error(Swagger::Blocks::DeclarationError)
    end
    it 'errors if calling build_api_json' do
      expect {
        Swagger::Blocks.build_api_json('fake', [PetControllerV2])
      }.to raise_error(Swagger::Blocks::NotSupportedError)
    end
  end
end
