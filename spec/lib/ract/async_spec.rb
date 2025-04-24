# frozen_string_literal: true

require 'spec_helper'

MockedRact = Class.new(Object)

RSpec.describe Ract::Async do
  describe 'included' do
    it 'includes module' do
      class MockedRact
        include Ract::Async

        async def self.execute
        end

        async def call
        end
      end

      expect(MockedRact.included_modules).to include(Ract::Async)
      expect(MockedRact.respond_to? :async).to eq(true)
      expect(MockedRact.new.respond_to? :call_async).to eq(true)
      expect(MockedRact.respond_to? :execute_async).to eq(true)
    end

    it 'check if call is async' do
      MockedRact.class_eval do
        async def call
          1
        end
      end

      mock = MockedRact.new

      expect(mock).to respond_to(:call_async)
      expect(mock.call_async).to be_a(Ract)
      expect(mock.call_async.state).to eq(:idle)

      promises = [mock.call_async]
      result = Ract.all(promises)

      expect(promises[0].state).to eq(:fulfilled)
      expect(result).to eq([1])
    end
  end

  describe 'extended' do
    it 'extends module' do
      MockRactModule = Module.new do
        module_function

        extend Ract::Async

        async def execute
          'delayed'
        end
      end

      expect(MockRactModule.respond_to?(:execute)).to eq(true)
      expect(MockRactModule.execute_async).to be_a(Ract)
      expect(MockRactModule.execute_async.state).to eq(:idle)

      result = Ract.all([MockRactModule.execute_async])
      expect(result[0]).to eq('delayed')
    end
  end
end
