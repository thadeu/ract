# frozen_string_literal: true

class Ract
  class Supervisor
    class Child
      extend Forwardable

      attr_reader :promise, :restart_policy, :restarts, :restart_times

      def_delegators :Ract, :logger

      # Initialize a new supervised child
      # @param promise [Ract] The promise to supervise
      # @param restart_policy [Symbol] When to restart the promise (:permanent, :temporary, :transient)
      # @param max_restarts [Integer] Maximum number of restarts allowed
      # @param max_seconds [Integer] Time window for max_restarts
      def initialize(promise, restart_policy:, max_restarts:, max_seconds:)
        raise ArgumentError, "Expected Ract promise, got #{promise.class}" unless promise.is_a?(Ract)

        @promise = promise
        @restart_policy = restart_policy
        @restarts = 0
        @restart_times = []
        @max_restarts = max_restarts
        @max_seconds = max_seconds
      end

      # Set up monitoring for this child
      # @param supervisor [Supervisor] The supervisor managing this child
      # @return [Child] self for method chaining
      def monitor(supervisor)
        @promise.then do |result|
          # When a child completes successfully, check overall status
          Thread.new do
            logger.info "Child completed successfully with result: #{result.inspect}"
            supervisor.check_children_status if supervisor.running?
          end
        end.rescue do |reason|
          # When a child fails, handle the failure
          Thread.new do
            logger.info "Child failed with reason: #{reason.inspect}"
            supervisor.handle_failure(self, reason) if supervisor.running?
          end
        end

        self
      end

      # Check if this child is in a terminal state
      # @return [Boolean] Whether the child is in a terminal state
      def terminal?(max_restarts)
        fulfilled? || (rejected? && @restarts >= max_restarts) || pending?
      end

      # Check if this child is active (not fulfilled and not at max restarts)
      # @return [Boolean] Whether the child is active
      def active?(max_restarts)
        !fulfilled? && !(rejected? && @restarts >= max_restarts)
      end

      # Set this child to idle state
      def idle!
        @promise.idle!
      end

      # Check if this child is idle
      # @return [Boolean] Whether the child is idle
      def idle?
        @promise.idle?
      end

      # Check if this child is fulfilled
      # @return [Boolean] Whether the child is fulfilled
      def fulfilled?
        @promise.fulfilled?
      end

      # Check if this child is rejected
      # @return [Boolean] Whether the child is rejected
      def rejected?
        @promise.rejected?
      end

      # Check if this child is pending
      # @return [Boolean] Whether the child is pending
      def pending?
        @promise.pending?
      end

      def pending!
        @promise.pending!
      end

      # Get the current state of this child
      # @return [Symbol] The current state
      def state
        @promise.state
      end

      # Reject this child
      # @param reason [Object] The reason for rejection
      def reject!(reason)
        @promise.reject!(reason)
      end

      # Execute the block associated with this child's promise
      def execute_block
        @promise.execute_block
      end

      # Record a restart event for this child
      def record_restart
        now = Time.now

        # Record restart time
        @restart_times << now

        # Clean up old restart records
        @restart_times.reject! { |time| time < now - @max_seconds }

        # Increment the restart counter
        @restarts += 1
      end

      # Check if this child should be restarted based on policy and limits
      # @param reason [Exception] The reason for the failure
      # @return [Boolean] Whether the child should be restarted
      def should_restart?(_reason)
        # Check restart policy
        case @restart_policy
        when Supervisor::TEMPORARY, Supervisor::TRANSIENT
          return false
        end

        # Check if we've exceeded the maximum restarts in the time window
        recent_restarts = @restart_times.count { |time| time > Time.now - @max_seconds }
        return false if recent_restarts >= @max_restarts

        true
      end

      # Restart this child
      # @param supervisor [Supervisor] The supervisor managing this child
      def restart(supervisor)
        idle!
        monitor(supervisor)

        # Execute the block again in a new thread
        # to avoid blocking and allow the supervisor to continue functioning
        Thread.new do
          execute_block
        rescue StandardError => e
          logger.error "Error executing restarted child: #{e.message}"

          # Handle failure in a separate thread to avoid deadlocks
          Thread.new do
            supervisor.handle_failure(self, e) if supervisor.running?
          end

          # Check children status after handling the failure
          Thread.new do
            sleep 0.05 # Give time for the failure to be handled
            supervisor.check_children_status if supervisor.running?
          end
        end
      end

      # Get statistics about this child
      # @param index [Integer] The index of this child in the supervisor's children array
      # @return [Hash] Statistics about this child
      def stats(index)
        {
          index: index,
          state: state,
          restart_policy: @restart_policy,
          restarts: @restarts
        }
      end
    end
  end
end
