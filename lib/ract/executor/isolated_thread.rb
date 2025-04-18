# frozen_string_literal: true # :rdoc

class Ract
  class Executor
    class IsolatedThread < IsolatedAbstract
      attr_reader :promises, :remaining

      def initialize(promises)
        @promises = promises.keep_if { |promise| promise.is_a?(Ract) }
        @queue = Thread::Queue.new
        @remaining = promises.size
      end

      def run(&block)
        return if @promises.empty?

        enqueue
        dequeue(&block)
      end

      def enqueue
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

      def dequeue(&block)
        while @remaining.positive?
          block.call(@queue.pop)
          @remaining -= 1
        end
      end

      def try_block!(arr)
        return unless arr.respond_to?(:execute_block)
        return unless arr.state == Ract::PENDING

        arr.execute_block
      end
    end
  end
end
