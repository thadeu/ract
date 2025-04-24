# frozen_string_literal: true

# frozen_string_literal: true # :rdoc

class Ract
  class Result
    include Enumerable

    attr_reader :value

    def initialize(value)
      @value = value
    end

    def deconstruct
      [@value]
    end

    def deconstruct_keys(_keys)
      { value: @value, count: @value.size }
    end

    def and_then(&block)
      return self unless block_given?

      block.call(@value)

      self
    end

    def each(&)
      return enum_for(:each) unless block_given?

      @value.each(&)

      self
    end
  end
end
