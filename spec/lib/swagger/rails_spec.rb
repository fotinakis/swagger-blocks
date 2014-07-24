require 'swagger/rails'

class SimpleController
  include Swagger::Rails

  swagger_controller :simple do
    property :apiVersion, '1.0.0'
    property :swaggerVersion, '1.2'
    property :basePath, 'http://localhost:8002/api'
    property :resourcePath, '/pet'
    property :produces, [
      'application/json',
      'application/xml',
      'text/plain',
      'text/html',
    ]
    property :authorizations, ['oauth2']
  end

  swagger_api :show do
    property :method, 'GET'
    property :summary, 'Find pet by ID'
    property :notes, 'Returns a pet based on ID'
    property :type, :Pet
    property :nickname, :getPetById
    property :produces, ['application/json', 'application/xml']
    property :authorizations, ['oauth2']

    parameter :petId do
      property :description, 'ID of pet that needs to be fetched'
      property :required, true
      property :allowMultiple, false
      property :type, :string
      property :paramType, :path
    end

    response_message :bad_request do
      property :message, 'Invalid ID supplied'
      property :responseModel, 'Pet'
    end
    response_message :not_found do
      property :message, 'Pet not found'
    end
  end
end

describe Swagger::Rails do
  describe 'build_json' do
    it 'outputs the correct data' do
      data = {
        apiVersion: '1.0.0',
        swaggerVersion: '1.2',
        basePath: 'http://localhost:8002/api',
        resourcePath: '/pet',
        produces: [
          'application/json',
          'application/xml',
          'text/plain',
          'text/html',
        ],
        authorizations: ['oauth2'],
        apis: {
          method: 'GET',
          summary: 'Find pet by ID',
          notes: 'Returns a pet based on ID',
          type: :Pet,
          nickname: :getPetById,
          produces: ['application/json', 'application/xml'],
          authorizations: ['oauth2'],
          name: :show,
          parameters: {
            description: 'ID of pet that needs to be fetched',
            required: true,
            allowMultiple: false,
            type: :string,
            paramType: :path,
          }
        }
      }
      actual = Swagger::Rails.build_json(SimpleController)
      expect(actual[:apis]).to eq(data[:apis])
      expect(actual).to eq(data)
    end
  end
end
