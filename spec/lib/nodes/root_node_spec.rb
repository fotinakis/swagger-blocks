require 'swagger/blocks'

describe 'RootNode' do
  describe 'build_json' do
    it 'creates an info node' do
      root_node = Swagger::Blocks::Nodes::RootNode.call(version: '3.0.0')
      info_node = root_node.info

      expect(info_node).to be_a(Swagger::Blocks::Nodes::InfoNode)
      expect(info_node.parent).to eq(root_node)
    end
  end
end
