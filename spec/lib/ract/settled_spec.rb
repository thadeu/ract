# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ract::Settled do
  describe '#initialize' do
    it 'stores promises' do
      promises = [Ract.new, Ract.new]

      settled = Ract::Settled.new(promises)

      expect(settled.type).to eq(:all)
      expect(settled.raise_on_error).to eq(true)
    end
  end

  describe '#run!' do
    context 'type: settled' do
      context 'when we have success promises' do
        it 'runs promises concurrently' do
          promises = [Ract.new { 1 }, Ract.new { 2 }]

          opts = { type: :settled, raise_on_error: false }
          settled = Ract::Settled.new(promises, **opts)

          result = settled.run!

          expect(result.value).to eq([
            { status: :fulfilled, value: 1 },
            { status: :fulfilled, value: 2 }
          ])
        end
      end

      context 'when we have error promises' do
        it 'runs promises concurrently' do
          promises = [Ract.new { 1 }, Ract.new { raise 'Error' }]

          opts = { type: :settled, raise_on_error: false }
          settled = Ract::Settled.new(promises, **opts)

          result = settled.run!
          first, last = result.value

          expect(first[:status]).to eq(:fulfilled)
          expect(first[:value]).to eq(1)

          expect(last[:status]).to eq(:rejected)
          expect(last[:reason].to_s).to eq('Error')
        end
      end
    end

    context 'type: all' do
      context 'when we have success promises' do
        it 'runs promises concurrently' do
          promises = [Ract.new { 1 }, Ract.new { 2 }]

          opts = { type: :all, raise_on_error: false }
          settled = Ract::Settled.new(promises, **opts)

          result = settled.run!

          expect(result.value).to eq([1, 2])
        end
      end

      context 'when we have error promises' do
        it 'runs promises concurrently' do
          promises = [Ract.new { 1 }, Ract.new { raise 'Error' }]

          opts = { type: :all, raise_on_error: false }
          settled = Ract::Settled.new(promises, **opts)

          result = settled.run!
          first, last = result.value

          expect(first).to eq(1)
          expect(last.to_s).to eq('Error')
        end
      end
    end
  end

  describe '#success_row' do
    it 'returns success row' do
      settled = Ract::Settled.new([])

      expect(settled.success_row(1)).to eq(1)
    end

    it 'when settled set up' do
      settled = Ract::Settled.new([], type: :settled)

      expect(settled.success_row(1)).to eq({ status: :fulfilled, value: 1 })
    end
  end

  describe '#rejected_row' do
    it 'returns rejected row' do
      settled = Ract::Settled.new([])

      expect(settled.rejected_row('Error')).to eq('Error')
    end

    it 'when settled set up' do
      settled = Ract::Settled.new([], type: :settled)

      expect(settled.rejected_row('Error')).to eq({ status: :rejected, reason: 'Error' })
    end
  end
end
