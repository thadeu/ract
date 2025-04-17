# frozen_string_literal: true # :rdoc

class Ract
  class Settled
    attr_reader :type, :raise_on_error

    def initialize(promises, type: :all, raise_on_error: true)
      @results = Array.new(promises.size)
      @batch = Batch.new(promises)
      @type = type
      @raise_on_error = raise_on_error
    end

    def run!
      return Result.new([]) if @batch.promises.empty?

      @batch.run! do |type, index, value|
        case type
        when :success
          @results[index] = success_row(value)
        when :error
          raise Rejected, value if @raise_on_error && @type == :all

          @results[index] = rejected_row(value)
        end
      end

      Result.new(@results)
    end

    def success_row(value)
      return value if @type == :all

      { status: Ract::FULFILLED, value: value }
    end

    def rejected_row(reason)
      return reason if @type == :all

      { status: Ract::REJECTED, reason: reason }
    end
  end
end
