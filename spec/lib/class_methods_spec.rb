require 'swagger/blocks'

class PetController
  include Swagger::Blocks

  swagger_path '/pets'
end

describe 'ClassMethods' do
  describe 'swagger_path' do
    it 'creates a path node' do
      path_map = PetController.instance_variable_get(:@swagger_path_node_map)
      path_node = path_map[:'/pets']
      expect(path_node.path).to eq('/pets')
    end
  end
end
