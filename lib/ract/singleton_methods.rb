# frozen_string_literal: true # :rdoc

class Ract
  module SingletonMethods
    def resolve(value = nil, auto_execute: false)
      new(auto_execute: true) { value }.await
    end

    def reject(reason = nil, auto_execute: false)
      new(auto_execute: true) { raise Rejected, reason }.await
    end

    def all(promises, raise_on_error: true, auto_execute: false, &block)
      return [] if promises.empty?

      result = Settled.new(promises, raise_on_error: raise_on_error).run!

      block.call(result.value) if block_given?

      result.value
    end
    alias take all

    def all_settled(promises, auto_execute: false, &block)
      return [] if promises.empty?

      result = Settled.new(promises, type: :all_settled).run!

      block.call(result.value) if block_given?

      result.value
    end
  end
end
