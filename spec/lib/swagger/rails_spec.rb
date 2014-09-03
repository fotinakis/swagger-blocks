require 'json'
require 'swagger/rails'


# Some test data directly copied from the swagger docs:
#
# https://github.com/wordnik/swagger-codegen/blob/master/src/test/resources/petstore-1.2/api-docs
RESOURCE_LISTING_JSON = open(File.expand_path('../swagger_resource_listing.json', __FILE__)).read
# https://github.com/wordnik/swagger-codegen/blob/master/src/test/resources/petstore-1.2/pet
API_DECLARATION_JSON = open(File.expand_path('../swagger_api_declaration.json', __FILE__)).read

class SimpleObject
  include Swagger::Rails

  swagger_resource_listing do
    key :swaggerVersion, '1.2'
    key :apiVersion, '1.0.0'

    info do
      key :title, 'Swagger Sample App'
      key :description, "This is a sample server Petstore server.  You can find out more about Swagger \n    at <a href=\"http://swagger.wordnik.com\">http://swagger.wordnik.com</a> or on irc.freenode.net, #swagger.  For this sample,\n    you can use the api key \"special-key\" to test the authorization filters"
      key :termsOfServiceUrl, 'http://helloreverb.com/terms/'
      key :contact, 'apiteam@wordnik.com'
      key :license, 'Apache 2.0'
      key :licenseUrl, 'http://www.apache.org/licenses/LICENSE-2.0.html'
    end

    authorization :oauth2 do
      key :type, 'oauth2'

      scope do
        key :scope, 'email'
        key :description, 'Access to your email address'
      end

      scope do
        key :scope, 'pets'
        key :description, 'Access to your pets'
      end

      grant_type :implicit do
        login_endpoint do
          key :url, 'http://petstore.swagger.wordnik.com/oauth/dialog'
        end

        key :tokenName, 'access_token'
      end

      grant_type :authorization_code do
        token_request_endpoint do
          key :url, 'http://petstore.swagger.wordnik.com/oauth/requestToken'
          key :clientIdName, 'client_id'
          key :clientSecretName, 'client_secret'
        end

        token_endpoint do
          key :url, 'http://petstore.swagger.wordnik.com/oauth/token'
          key :tokenName, 'access_code'
        end
      end
    end
  end

  swagger_api_root :pets do
    key :path, '/pet'
  end

  swagger_api_operation :pets do
    key :method, 'GET'
    key :path, '/pet/{petId}'
    key :summary, 'Find pet by ID'
    key :notes, 'Returns a pet based on ID'
    key :type, :Pet
    key :nickname, :getPetById
    key :produces, ['application/json', 'application/xml']

    parameter do
      key :name, :petId
      key :description, 'ID of pet that needs to be fetched'
      key :required, true
      key :type, :integer
      key :format, :int64
      key :paramType, :path
      key :minimum, '1.0'
      key :maximum, '100000.0'
    end

    response_message do
      key :code, 400
      key :message, 'Invalid ID supplied'
      key :responseModel, 'Pet'
    end

    response_message do
      key :code, 404
      key :message, 'Pet not found'
    end
  end

  # https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md#51-resource-listing

  # swagger_api :simple do
  #   key :apiVersion, '1.0.0'
  #   key :swaggerVersion, '1.2'
  #   key :basePath, 'http://localhost:8002/api'
  #   key :resourcePath, '/pet'
  #   key :produces, [
  #     'application/json',
  #     'application/xml',
  #     'text/plain',
  #     'text/html',
  #   ]
  #   key :authorizations, ['oauth2']
  # end

  # swagger_api :show do
  #   key :method, 'GET'
  #   key :summary, 'Find pet by ID'
  #   key :notes, 'Returns a pet based on ID'
  #   key :type, :Pet
  #   key :nickname, :getPetById
  #   key :produces, ['application/json', 'application/xml']
  #   key :authorizations, ['oauth2']
  #   parameter :petId do
  #     key :description, 'ID of pet that needs to be fetched'
  #     key :required, true
  #     key :allowMultiple, false
  #     key :type, :string
  #     key :paramType, :path
  #   end
  #   response_message :bad_request do
  #     key :message, 'Invalid ID supplied'
  #     key :responseModel, 'Pet'
  #   end
  #   response_message :not_found do
  #     key :message, 'Pet not found'
  #   end
  # end
end

describe Swagger::Rails do
  describe 'build_resource_listing_json' do
    it 'outputs the correct data' do
      actual = Swagger::Rails.build_resource_listing_json(SimpleObject)
      actual = JSON.parse(actual.to_json)  # For access consistency below.

      # Multiple expectations for better test diff output:
      data = JSON.parse(RESOURCE_LISTING_JSON)
      expect(actual['info']).to eq(data['info'])
      expect(actual['authorizations']).to eq(data['authorizations'])
      expect(actual['apis']).to eq(data['apis'])
      expect(actual).to eq(data)
    end
  end
  # describe 'build_api_json' do
  #   it 'outputs the correct data' do
  #     data = {
  #       apiVersion: '1.0.0',
  #       swaggerVersion: '1.2',
  #       basePath: 'http://localhost:8002/api',
  #       resourcePath: '/pet',
  #       produces: [
  #         'application/json',
  #         'application/xml',
  #         'text/plain',
  #         'text/html',
  #       ],
  #       authorizations: ['oauth2'],
  #       apis: {
  #         method: 'GET',
  #         summary: 'Find pet by ID',
  #         notes: 'Returns a pet based on ID',
  #         type: :Pet,
  #         nickname: :getPetById,
  #         produces: ['application/json', 'application/xml'],
  #         authorizations: ['oauth2'],
  #         name: :show,
  #         parameters: {
  #           description: 'ID of pet that needs to be fetched',
  #           required: true,
  #           allowMultiple: false,
  #           type: :string,
  #           paramType: :path,
  #         }
  #       }
  #     }
  #     actual = Swagger::Rails.build_api_json(SimpleObject)
  #     expect(actual[:apis]).to eq(data[:apis])
  #     expect(actual).to eq(data)
  #   end
  # end
end
