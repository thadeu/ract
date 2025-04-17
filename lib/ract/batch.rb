# frozen_string_literal: true # :rdoc

class Ract
  class Batch
    attr_reader :promises, :remaining

    def initialize(promises)
      @promises = promises.keep_if { |promise| promise.is_a?(Ract) }
      @queue = Thread::Queue.new
      @remaining = promises.size
    end

    def run!(&block)
      return if @promises.empty?

      create_threads
      process_results(&block)
    end

    def create_threads
      @promises.each_with_index do |promise, index|
        Thread.new do
          try_block!(promise)

          promise.then do |value|
            @queue << [:success, index, value]
          end&.rescue do |reason|
            @queue << [:error, index, reason]
          end
        rescue StandardError => e
          @queue << [:error, index, e]
        end
      end
    end

    def process_results(&block)
      while @remaining.positive?
        block.call(@queue.pop)
        @remaining -= 1
      end
    end

    def try_block!(promise)
      return unless promise.respond_to?(:execute_block)
      return unless promise.state == Ract::PENDING

      promise.execute_block
    end
  end
end
