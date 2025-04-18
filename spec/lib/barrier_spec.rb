# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'BarrierTest' do
  context 'async instance method' do
    it 'keep as pending until Thread execute' do
      id4 = MethodAsync.execute_async(user_id: 4)

      expect(id4.state).to eq(:pending)

      sleep 0.01

      expect(id4.state).to eq(:pending)

      id4.await

      expect(id4.state).to eq(:fulfilled)
      expect(id4.value).to eq(4)
    end

    it 'check if promises was resolved' do
      promises = [
        MethodAsync.execute_async(user_id: 1),
        MethodAsync.execute_async(user_id: 2),
        MethodAsync.execute_async(user_id: 3),
        MethodAsync.execute_async(user_id: 4),
        MethodAsync.new(user_id: 5).with_ract
      ]

      sleep 0.01

      expect(promises.map(&:state).uniq).to eq([:pending])

      Ract.take(promises)

      expect(promises.map(&:state).uniq).to eq([:fulfilled])
    end

    it 'should be return an array' do
      promises = [
        MethodAsync.execute_async(user_id: 1),
        MethodAsync.execute_async(user_id: 2),
        MethodAsync.execute_async(user_id: 3),
        MethodAsync.execute_async(user_id: 4),
        MethodAsync.new(user_id: 5).with_ract
      ]

      result = Ract.all(promises, raise_on_error: false)

      expect(result.length).to eq(5)
      expect(result).to eq([1, 2, 3, 4, 5])
    end

    it 'should be running in the same time' do
      promises = [
        Ract { sleep 1; 1 },
        Ract { sleep 1; 2 },
        Ract { sleep 1; 3 },
        Ract { sleep 1; 4 },
        Ract { sleep 1; 5 },
        Ract { sleep 1; 6 },
        Ract { sleep 1; 7 },
        Ract { sleep 1; 8 },
        Ract { sleep 1; 9 }
      ]

      start = Time.now
      Ract.take(promises)
      elapsed = Time.now - start

      expect(elapsed.to_i).to be <= 1
    end
  end

  context 'async singleton method' do
    it 'should be return an array' do
      start = Time.now

      result = Ract.all([
        Table::Base.execute_async(user_id: 1),
        Table::Base.execute_async(user_id: 2),
        Table::Base.execute_async(user_id: 3),
        Table::Base.execute_async(user_id: 4),
        Table::Posts.execute_async(user_id: 5)
      ], raise_on_error: false)

      end_time = Time.now
      elapsed = end_time - start

      expect(result).to be_an(Array)
      expect(result.length).to eq(5)
      expect(result).to eq([1, 2, 3, 4, 5])
      expect(elapsed < 2).to be true
    end
  end

  context 'block' do
    it 'should be return an array' do
      class RactBlock < Table::Base
        def self.execute(...)
          ract { new(...).execute! }
        end
      end

      start = Time.now

      result = Ract.all([
        RactBlock.execute(user_id: 1),
        RactBlock.execute(user_id: 2),
      ], raise_on_error: false)

      end_time = Time.now
      elapsed = end_time - start

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result).to eq([1, 2])
      expect(elapsed < 2).to be true
    end
  end

  context 'ract block' do
    it 'should be return an array' do
      class GoBlock < Table::Base
        def self.call(...)
          ract { new(...).execute! }
        end
      end

      start = Time.now

      result = Ract.all([
        GoBlock.call(user_id: 1),
        GoBlock.call(user_id: 2),
      ], raise_on_error: false)

      end_time = Time.now
      elapsed = end_time - start

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result).to eq([1, 2])
      expect(elapsed < 2).to be true
    end
  end

  context 'when raise_on_error is true' do
    it 'should be raise an error' do
      class ErrorMethod < Table::Base
        async def self.execute(...)
          new(...).execute!
        end

        def execute!
          raise StandardError
        end
      end

      expect do
        Ract.all([
          ErrorMethod.execute(user_id: 1),
          ErrorMethod.execute(user_id: 2),
        ])
      end.to raise_error StandardError
    end
  end

  context 'when raise_on_error is false' do
    it 'should be raise an error' do
      class NotRaised < Table::Base
        def self.execute(...)
          ract { new(...).execute! }
        end

        def execute!
          raise StandardError
        end
      end

      expect do
        Ract.all([
          Table::Base.execute(user_id: 1),
          NotRaised.execute(user_id: 2),
        ], raise_on_error: false)
      end.to_not raise_error
    end
  end
end
