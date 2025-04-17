# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ract::Result do
  let(:result) { Ract::Result.new([1, 2, 3]) }

  it 'stores a value' do
    expect(result.value).to eq([1, 2, 3])
  end

  it 'supports pattern matching with deconstruct' do
    # Directly test the deconstruct method
    expect(result.deconstruct).to eq([[1, 2, 3]])

    # Test pattern matching using deconstruct
    case result
    in [array]
      expect(array).to eq([1, 2, 3])
    end
  end

  it 'supports pattern matching with deconstruct_keys' do
    expect(result.deconstruct_keys(nil)).to eq({ value: [1, 2, 3], count: 3 })
  end

  describe '#and_then' do
    it 'supports and_then for chaining' do
      chained_value = nil
      result.and_then { |value| chained_value = value }
      expect(chained_value).to eq([1, 2, 3])
    end

    it 'returns self when no block is given' do
      expect(result.and_then).to eq(result)
    end
  end

  describe '#each' do
    it 'supports each for iteration' do
      iterated_value = []
      result.each { |value| iterated_value << value }
      expect(iterated_value).to eq([1, 2, 3])
    end

    it 'returns an enumerator when no block is given' do
      expect(result.each).to be_a(Enumerator)
      expect(result.each.to_a).to eq([1, 2, 3])
    end
  end
end
