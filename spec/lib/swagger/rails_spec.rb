require 'json'
require 'swagger/rails'


# Some test data directly copied from the swagger docs:
#
# https://github.com/wordnik/swagger-codegen/blob/master/src/test/resources/petstore-1.2/api-docs
RESOURCE_LISTING_JSON = open(File.expand_path('../swagger_resource_listing.json', __FILE__)).read
# https://github.com/wordnik/swagger-codegen/blob/master/src/test/resources/petstore-1.2/pet
API_DECLARATION_JSON = open(File.expand_path('../swagger_api_declaration.json', __FILE__)).read

class PetController
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
    key :description, 'Operations about pets'
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
end

class StoreController
  include Swagger::Rails

  swagger_api_root :store do
    key :path, '/store'
    key :description, 'Operations about store'
  end
end

class UserController
  include Swagger::Rails

  swagger_api_root :user do
    key :path, '/user'
    key :description, 'Operations about user'
  end
end

class BlankController
end


describe Swagger::Rails do
  describe 'build_resource_listing_json' do
    it 'outputs the correct data' do
      swaggered_classes = [
        PetController,
        UserController,
        StoreController,
      ]
      actual = Swagger::Rails.build_root_json(swaggered_classes)
      actual = JSON.parse(actual.to_json)  # For access consistency.

      # Multiple expectations for better test diff output.
      data = JSON.parse(RESOURCE_LISTING_JSON)
      expect(actual['info']).to eq(data['info'])
      expect(actual['authorizations']).to eq(data['authorizations'])
      expect(actual['apis']).to eq(data['apis'])
      expect(actual).to eq(data)
    end
    it 'is idempotent' do
      swaggered_classes = [PetController, UserController, StoreController]
      actual = JSON.parse(Swagger::Rails.build_root_json(swaggered_classes).to_json)
      actual = JSON.parse(Swagger::Rails.build_root_json(swaggered_classes).to_json)
      data = JSON.parse(RESOURCE_LISTING_JSON)
      expect(actual).to eq(data)
    end
    it 'errors if no swagger_resource_listing is declared' do
      expect {
        Swagger::Rails.build_root_json([])
      }.to raise_error(Swagger::Rails::DeclarationError)
    end
    it 'errors if mulitple swagger_resource_listings are declared' do
      expect {
        Swagger::Rails.build_root_json([PetController, PetController])
      }.to raise_error(Swagger::Rails::DeclarationError)
    end
    it 'does not error if given non-swaggered classes' do
      Swagger::Rails.build_root_json([PetController, BlankController])
    end
  end
  describe 'build_api_json' do
    it 'outputs the correct data' do
      swaggered_classes = [
        PetController,
        UserController,
        StoreController,
      ]
      actual = Swagger::Rails.build_api_json(:pets, swaggered_classes)
      actual = JSON.parse(actual.to_json)  # For access consistency.

      # Multiple expectations for better test diff output.
      data = JSON.parse(RESOURCE_LISTING_JSON)
      expect(actual['apis']).to eq(data['apis'])
      expect(actual['models']).to eq(data['models'])
      expect(actual).to eq(data)
    end
    it 'errors if no swagger_resource_listing is declared' do
      expect {
        Swagger::Rails.build_root_json([])
      }.to raise_error(Swagger::Rails::DeclarationError)
    end
    it 'errors if mulitple swagger_resource_listings are declared' do
      expect {
        Swagger::Rails.build_root_json([PetController, PetController])
      }.to raise_error(Swagger::Rails::DeclarationError)
    end
  end
end
