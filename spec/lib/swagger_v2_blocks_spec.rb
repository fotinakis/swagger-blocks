require 'json'
require 'swagger/blocks_v2'

# TODO Test data originally based on the Swagger UI example data

RESOURCE_LISTING_JSON_V2 = open(File.expand_path('../swagger_v2_partial.json', __FILE__)).read

class PetControllerV2
  include Swagger::BlocksV2

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
    # paths do

    # end
  end

end

class Pet
  include Swagger::BlocksV2

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

  # swagger_definition(:petInput) do
  #   key :allOf
  # end
end

describe Swagger::BlocksV2 do
  describe 'build_json' do
    it 'outputs the correct data' do
      swaggered_classes = [
        PetControllerV2,
        Pet
      ]
      actual = Swagger::BlocksV2.build_json(swaggered_classes)

      # Multiple expectations for better test diff output.
      actual = JSON.parse(actual.to_json)  # For access consistency.
      data = JSON.parse(RESOURCE_LISTING_JSON_V2)

      expect(actual['info']).to eq(data['info'])
      # expect(actual['authorizations']).to eq(data['authorizations'])
      # actual['apis'].each_with_index do |api_data, i|
      #   expect(api_data).to eq(data['apis'][i])
      # end
      expect(actual).to eq(data)
    end
    it 'is idempotent' do
      swaggered_classes = [PetControllerV2, Pet]
      actual = JSON.parse(Swagger::BlocksV2.build_json(swaggered_classes).to_json)
      actual = JSON.parse(Swagger::BlocksV2.build_json(swaggered_classes).to_json)
      data = JSON.parse(RESOURCE_LISTING_JSON_V2)
      expect(actual).to eq(data)
    end
    it 'errors if no swagger_root is declared' do
      expect {
        Swagger::BlocksV2.build_json([])
      }.to raise_error(Swagger::BlocksV2::DeclarationError)
    end
    it 'errors if mulitple swagger_roots are declared' do
      expect {
        Swagger::BlocksV2.build_json([PetControllerV2, PetControllerV2])
      }.to raise_error(Swagger::BlocksV2::DeclarationError)
    end
    # it 'does not error if given non-swaggered classes' do
    #   Swagger::BlocksV2.build_json([PetControllerV2])
    # end
  end
end
