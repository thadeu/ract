# frozen_string_literal: true # :rdoc

class Ract
  module ClassMethods
    def resolve(value = nil, auto_execute: false)
      new(auto_execute: true) { value }.await
    end

    def reject(reason = nil, auto_execute: false)
      new(auto_execute: true) { raise Rejected, reason }.await
    end

    def all(array = [], raise_on_error: true, &block)
      return [] if array.empty?

      result = Settled.new(
        array,
        type: :all,
        executor: executor,
        raise_on_error: raise_on_error
      ).run!

      block.call(result.value) if block_given?

      result.value
    end
    alias take all

    def all_settled(array = [], &block)
      return [] if array.empty?

      result = Settled.new(
        array,
        type: :all_settled,
        executor: executor,
        raise_on_error: false
      ).run!

      block.call(result.value) if block_given?

      result.value
    end

    def executor
      case Ract.config.isolation_level
      in :thread then Executor::IsolatedThread
      else
        raise ArgumentError, "Unknown executor: #{Ract.config.isolation_level}"
      end
    end
    private :executor
  end
end
