require 'swagger/rails/version'

module Swagger::Rails
  def self.included(base)
    base.extend(ClassMethods)
  end

  def self.build_json(controller_class)
    root = {}
    structures = controller_class.send(:_swagger_datablocks)

    # Build the simple root keys from the swagger_controller datablock.
    root.merge!(structures[:controller].data)

    # Build the root "apis" key from each of the swagger_api structures.
    root[:apis] = {}
    structures[:apis].each do |api_datablock|
      api_data = api_datablock.data
      api_data[:name] = api_datablock.name

      api_datablock.parameters.each do |parameter_datablock|
        api_data[:parameters] ||= {}
        api_data[:parameters] = parameter_datablock.data
      end

      root[:apis].merge!(api_data)
    end

    root
  end

  module ClassMethods
    private

    def swagger_controller(name, &block)
      # There should only ever be one of these per controller.
      datablock = Swagger::Rails::DataBlock.call(name, &block)
      @swagger_controller_datablock = datablock
    end

    def swagger_api(name, &block)
      datablock = Swagger::Rails::ApiDataBlock.call(name, &block)
      @swagger_api_datablocks ||= []
      @swagger_api_datablocks << datablock
    end

    def _swagger_datablocks
      {
        controller: @swagger_controller_datablock || {},
        apis: @swagger_api_datablocks || [],
      }
    end
  end

  # -----

  # Dumb data containers for evaluating and holding the originally-definied swagger data.
  # These objects shouldn't know anything about how to represent the data in its finalized swagger
  # form so that certain evaluations can be deferred until all objects have been evaluated.
  class DataBlock
    attr_accessor :name

    def self.call(name, &block)
      # Create a new instance and evaluate the block into it.
      instance = new
      instance.instance_eval(&block)

      # Set the first parameter given as the name.
      instance.name = name
      instance
    end

    def data
      @data ||= {}
    end

    def property(key, value)
      self.data[key] = value
    end
  end

  class ApiDataBlock < DataBlock
    def parameters
      @parameters ||= []
    end

    def parameter(name, &block)
      self.parameters << DataBlock.call(name, &block)
    end

    def response_messages
      @response_messages ||= []
    end

    def response_message(name, &block)
      self.response_messages << DataBlock.call(name, &block)
    end
  end
end
