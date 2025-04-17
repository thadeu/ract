# frozen_string_literal: true
#
require 'spec_helper'

RSpec.describe Ract::Batch do
  describe '#initialize' do
    it 'stores promises' do
      promises = [Ract.new, Ract.new]

      batch = Ract::Batch.new(promises)

      expect(batch.promises).to eq(promises)
    end

    it 'stores promises only if Ract responds' do
      promises = [Ract.new, Ract.new, Class.new]

      batch = Ract::Batch.new(promises)

      expect(batch.promises.size).to eq(2)
      expect(batch.remaining).to eq(2)
    end
  end

  describe '.run!' do
    it 'runs promises concurrently' do
      promises = [Ract.new { 1 }, Ract.new { 2 }]

      batch = Ract::Batch.new(promises)

      batch.run! {}

      expect(batch.remaining).to eq(0)
    end

    it 'when promise fail running as well' do
      promises = [Ract.new { 1 }, Ract.new { raise 'Error' }]

      batch = Ract::Batch.new(promises)
      output = []

      batch.run! { output << _1 }

      expect(output.size).to eq(2)
      expect(output.last[2].to_s).to eq('Error')
      expect(batch.remaining).to eq(0)
    end

    it 'check queue size' do
      promises = [Ract.new { 1 }]

      batch = Ract::Batch.new(promises)
      queue = batch.instance_variable_get(:@queue)

      batch.run! {}

      expect(queue.size).to eq(0)
    end
  end
end
