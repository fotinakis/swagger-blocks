require 'swagger/blocks'

describe 'OperationNode' do
  describe 'call' do
    it 'sets the operation' do
      version, operation = '3.0.0', :get
      operation_node = Swagger::Blocks::Nodes::OperationNode.call(version: version, operation: operation)

      expect(operation_node).to be_a(Swagger::Blocks::Nodes::OperationNode)
      expect(operation_node.operation).to eq(operation)
      expect(operation_node.version).to eq(version)
    end
  end
end
