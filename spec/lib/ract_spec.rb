# frozen_string_literal: true

require 'spec_helper'
require 'timeout'

RSpec.describe Ract do
  describe '#initialize' do
    it 'creates a new Ract with a block' do
      ract = Ract.new { 42 }
      expect(ract.await).to eq(42)
    end

    it 'handles exceptions in the block' do
      ract = Ract.new { raise StandardError, 'Test error' }
      expect { ract.await }.to raise_error(StandardError, 'Test error')
    end
  end

  describe '#await' do
    it 'raises Rejected when rejected' do
      ract = Ract.new
      ract.reject('Error message')

      expect { ract.await }.to raise_error(Ract::Rejected, 'Error message')
    end

    it 'waits for the value when pending' do
      ract = Ract.new
      ract.resolve(42)

      expect(ract.await).to eq(42)
    end
  end

  describe '#resolve' do
    it 'changes state to fulfilled' do
      ract = Ract.new
      ract.resolve(42)

      expect(ract.state).to eq(:fulfilled)
      expect(ract.value).to eq(42)
    end

    it 'does nothing if already rejected' do
      ract = Ract.new

      ract.reject('Error')
      ract.resolve(42)

      expect(ract.state).to eq(:rejected)
      expect(ract.reason).to eq('Error')
    end

    it 'executes callbacks' do
      ract = Ract.new
      result = nil

      ract.then { |value| result = value }
      ract.resolve(42)

      sleep 0.1

      expect(result).to eq(42)
    end
  end

  describe '#reject' do
    it 'changes state to rejected' do
      ract = Ract.new
      ract.reject('Error')
      expect(ract.state).to eq(:rejected)
      expect(ract.reason).to eq('Error')
    end

    it 'does nothing if already rejected' do
      ract = Ract.new
      ract.reject('Error 1')
      ract.reject('Error 2')
      expect(ract.reason).to eq('Error 1')
    end

    it 'executes error callbacks' do
      ract = Ract.new
      error = nil

      ract.rescue { |reason| error = reason }
      ract.reject('Error')
      sleep 0.1

      expect(error).to eq('Error')
    end
  end

  describe '#then' do
    it 'registers a callback for when the ract is fulfilled' do
      ract = Ract.new
      result = nil

      ract.then { |value| result = value }
      ract.resolve(42)
      sleep 0.1

      expect(result).to eq(42)
    end

    it 'chainning then and catch' do
      Ract { 1 }
        .then { expect(_1).to eq(1) }
        .catch { expect { _1 }.not_to raise_error }

      Ract { 1 }
        .then do
          expect(_1).to eq(1)
          raise 'Test error'
        end
        .then do
          expect(_1).not_to eq(1)
        end
        .catch do
          expect(_1.to_s).to eq('Test error')
        end
    end

    it 'does not execute callback if rejected' do
      ract = Ract.new
      result = nil

      ract.then { |value| result = value }
      ract.reject('Error')
      sleep 0.1

      expect(result).to be_nil
    end

    it 'returns self for chaining' do
      ract = Ract.new
      expect(ract.then {}).to eq(ract)
    end
  end

  describe '#rescue' do
    it 'registers a callback for when the ract is rejected' do
      ract = Ract.new
      error = nil

      ract.rescue { |reason| error = reason }
      ract.reject('Error')
      sleep 0.1

      expect(error).to eq('Error')
    end

    it 'executes callback immediately if already rejected' do
      ract = Ract.new
      ract.reject('Error')
      error = nil

      ract.rescue { |reason| error = reason }
      sleep 0.1

      expect(error).to eq('Error')
    end

    it 'does not execute callback if fulfilled' do
      ract = Ract.new
      error = nil

      ract.rescue { |reason| error = reason }
      ract.resolve(42)
      sleep 0.1

      expect(error).to be_nil
    end

    it 'returns self for chaining' do
      ract = Ract.new
      expect(ract.rescue {}).to eq(ract)
    end
  end

  describe '.resolve' do
    it 'creates a fulfilled ract' do
      ract = Ract.resolve(42)

      expect(ract).to eq(42)
    end
  end

  describe '.reject' do
    it 'raises a Rejected error' do
      expect { Ract.reject('Error').await }.to raise_error(Ract::Rejected, 'Error')
    end
  end

  describe '.all' do
    it 'returns an empty array for empty input' do
      result = Ract.all([Ract.new { 1 }])
      expect(result).to eq([1])
    end

    it 'handles non-rejection with raise_on_error: false' do
      ract1 = Ract.new { 1 }
      ract2 = Ract.new
      ract3 = Ract.new { 3 }

      ract2.reject('Error')

      result = Ract.all([ract1, ract2, ract3], raise_on_error: false)

      expect(result[0]).to eq(1)
      expect(result[1].to_s).to eq('Error')
      expect(result[2]).to eq(3)
    end

    it 'handles non-rejection with raise_on_error: true' do
      ract1 = Ract.new { 1 }
      ract2 = Ract.new
      ract3 = Ract.new { 3 }

      ract2.reject('Error')

      expect { Ract.all([ract1, ract2, ract3], raise_on_error: true) }.to raise_error(Ract::Rejected, 'Error')
    end
  end

  describe '.all_settled' do
    it 'resolves with results of all racts regardless of fulfillment or rejection' do
      ract1 = Ract.new { 1 }

      ract2 = Ract.new
      ract2.reject('Error')

      ract3 = Ract.new { 3 }

      result = Ract.all_settled([ract1, ract2, ract3])

      expect(result[0][:status]).to eq(:fulfilled)
      expect(result[0][:value]).to eq(1)
      expect(result[1][:status]).to eq(:rejected)
      expect(result[1][:reason].to_s).to eq('Error')
      expect(result[2][:status]).to eq(:fulfilled)
      expect(result[2][:value]).to eq(3)
    end

    it 'returns an empty array for empty input' do
      result = Ract.all_settled([])
      expect(result).to eq([])
    end
  end

  describe 'concurrent execution' do
    it 'executes multiple racts concurrently' do
      klass = Class.new(Object) do
        async def self.delayed(...)
          new.call!(...)
        end

        def call!(n)
          sleep 0.2
          n
        end
      end

      start_time = Time.now

      result = Ract.all([
        klass.delayed_async(1),
        klass.delayed_async(2),
        klass.delayed_async(3),
        klass.delayed_async(4),
        klass.delayed_async(5)
      ])

      end_time = Time.now
      execution_time = end_time - start_time

      expect(execution_time.to_i).to be <= 0.2
      expect(result).to eq([1, 2, 3, 4, 5])
    end
  end

  describe 'error handling' do
    it 'properly propagates errors' do
      ract = Ract.new { raise 'Test error' }
      expect { Ract.all([ract]) }.to raise_error(Ract::Rejected, 'Test error')
    end

    it 'allows rescuing errors with rescue' do
      ract = Ract.new { raise 'Test error' }
      rescued_error = nil

      ract.rescue { |error| rescued_error = error }

      sleep 0.1

      expect(rescued_error).to be_a(StandardError)
      expect(rescued_error.message).to eq('Test error')
    end
  end

  describe 'chaining' do
    it 'promise resolution using .then' do
      promise = Ract.new { 42 }

      promise.then do |value|
        expect(value).to eq(42)
      end
    end

    it 'promise rejection using .then' do
      promise = Ract.new { raise 'Test error' }

      promise
        .then do |value|
          expect(value).to eq(42)
        end
        .rescue do |error|
          expect(error.message.to_s).to eq('Test error')
        end
    end

    it 'allows chaining then and rescue' do
      ract = Ract.new { 5 }
      results = []

      ract
        .then { results << _1 * 2 }
        .then { results << 'second then' }

      sleep 0.1

      expect(results).to eq([10, 'second then'])
    end

    it 'allows chaining with error handling' do
      ract = Ract.new { raise 'Error' }
      results = []

      ract
        .then { results << _1 * 2 }
        .rescue { |_| results << 'error handled' }

      sleep 0.1

      expect(results).to eq(['error handled'])
    end
  end
end
