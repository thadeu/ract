# frozen_string_literal: true

class Ract
  # ThreadMonitor provides functionality to monitor and manage threads created by Ract
  class ThreadMonitor
    class << self
      # Store all active threads created by Ract
      def active_threads
        @active_threads ||= {}
      end

      # Register a new thread with the monitor
      # @param thread [Thread] The thread to register
      # @param metadata [Hash] Additional metadata about the thread
      # @return [Thread] The registered thread
      def register(thread, metadata = {})
        return thread unless thread.is_a?(Thread)

        # Auto cleanup dead threads if enabled
        cleanup_dead_threads if Ract.config.monitor_cleanup_dead

        thread_id = thread.object_id
        active_threads[thread_id] = {
          thread: thread,
          created_at: Time.now,
          metadata: metadata,
        }

        # Set up finalizer to clean up when thread is garbage collected
        ObjectSpace.define_finalizer(thread, proc { unregister(thread_id) })

        thread
      end

      # Unregister a thread from the monitor
      # @param thread_id [Integer] The object_id of the thread to unregister
      def unregister(thread_id)
        active_threads.delete(thread_id)
      end

      # Get statistics about all active threads
      # @return [Hash] Statistics about active threads
      def stats
        # Auto cleanup dead threads if enabled
        cleanup_dead_threads if Ract.config.monitor_cleanup_dead

        {
          total_count: active_threads.size,
          alive_count: active_threads.count { |_, data| data[:thread].alive? },
          dead_count: active_threads.count { |_, data| !data[:thread].alive? },
          threads: active_threads.transform_values do |data|
            {
              status: data[:thread].status,
              alive: data[:thread].alive?,
              created_at: data[:created_at],
              runtime: Time.now - data[:created_at],
              metadata: data[:metadata],
            }
          end,
        }
      end

      # Clean up dead threads from the monitor
      # @return [Integer] Number of threads cleaned up
      def cleanup_dead_threads
        before_count = active_threads.size
        active_threads.select! { |_, data| data[:thread].alive? }
        before_count - active_threads.size
      end

      # Kill all active threads
      # @return [Integer] Number of threads killed
      def kill_all
        count = 0
        active_threads.each_value do |data|
          if data[:thread].alive?
            data[:thread].kill
            count += 1
          end
        end
        active_threads.clear
        count
      end
    end
  end
end
