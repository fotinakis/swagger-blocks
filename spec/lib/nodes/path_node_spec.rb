require 'swagger/blocks'

describe 'PathNode' do
  describe 'call' do
    it 'sets the path' do
      version, path = '3.0.0', '/pets'
      path_node = Swagger::Blocks::Nodes::PathNode.call(version: version, path: path)

      expect(path_node).to be_a(Swagger::Blocks::Nodes::PathNode)
      expect(path_node.path).to eq(path)
      expect(path_node.version).to eq(version)
    end
  end
end
