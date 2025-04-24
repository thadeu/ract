# frozen_string_literal: true

require 'forwardable'
require_relative 'supervisor/child'

class Ract
  class Supervisor
    extend Forwardable

    ONE_FOR_ONE = :one_for_one
    REST_FOR_ONE = :rest_for_one

    PERMANENT = :permanent # Always restart
    TEMPORARY = :temporary # Never restart
    TRANSIENT = :transient # Restart only if it terminated abnormal

    attr_reader :name, :children, :options, :running

    def_delegators :Ract, :logger

    # Initialize a new supervisor
    # @param options [Hash] Configuration options for the supervisor
    # @option options [Symbol] :strategy Supervision strategy (:one_for_one, :rest_for_one)
    # @option options [Integer] :max_restarts Maximum number of restarts allowed in :max_seconds
    # @option options [Integer] :max_seconds Time window for :max_restarts
    # @option options [Boolean] :auto_start Whether to start supervision automatically
    def initialize(options = {})
      @options = {
        strategy: options[:strategy] || Ract.config.supervisor_strategy || ONE_FOR_ONE,
        max_restarts: options[:max_restarts] || Ract.config.supervisor_max_restarts || 3,
        max_seconds: options[:max_seconds] || Ract.config.supervisor_max_seconds || 5,
        auto_start: options.fetch(:auto_start, false)
      }.merge(options)

      @name = options[:name] || 'Main'
      @children = []
      @mutex = Mutex.new
      @running = false

      start! if @options[:auto_start]
    end

    # Add a child promise to be supervised
    # @param promise [Ract] The promise to supervise
    # @param restart_policy [Symbol] When to restart the promise (:permanent, :temporary, :transient)
    # @return [ArgumentError] If the promise is not a Ract object
    # @return [Ract] The supervised promise
    def add_child(promise, restart_policy: PERMANENT)
      child = Child.new(
        promise,
        restart_policy: restart_policy,
        max_restarts: @options[:max_restarts],
        max_seconds: @options[:max_seconds]
      )

      @mutex.synchronize do
        @children << child
        child.monitor(self) if @running
      end

      promise
    end

    # Start the supervision process
    # @return [Boolean] Whether the supervisor was started
    def start!
      synchronize do
        return false if @running

        @running = true
        @children.each { |child| child.monitor(self) }
      end

      true
    end

    # Shutdown the supervisor
    # @return [Boolean] true if the supervisor was running and is now stopped
    def shutdown!
      synchronize do
        return false unless @running

        @running = false

        @children.each do |child|
          child.reject!('Supervisor shutdown') if child.idle? || child.pending?
        end

        return true
      end
    end

    # Get statistics about supervised promises
    # @return [Hash] Statistics about supervised promises
    def stats
      synchronize do
        {
          name: @name,
          running: @running,
          children_count: @children.size,
          strategy: @options[:strategy],
          max_restarts: @options[:max_restarts],
          max_seconds: @options[:max_seconds],
          children: @children.map.with_index { |child, index| child.stats(index) }
        }
      end
    end

    def running? = synchronize { @running }

    def synchronize(&) = @mutex.synchronize(&)

    # Check if all children have completed and set running to false if they have
    def check_children_status
      synchronize do
        return false unless @running

        states = @children.map { |c| [c.state, c.restarts] }
        logger.info "Checking children status: #{states.map { |s, r| "#{s}(#{r})" }.join(', ')}"

        all_terminal = @children.all? { |child| child.terminal?(@options[:max_restarts]) }

        # If all children are in terminal state or pending
        # Check if there are any children that haven't reached the restart limit
        if all_terminal && @children.none? { |child| child.active?(@options[:max_restarts]) }
          waiting_children = @children.select { |child| child.idle? || child.pending? }

          unless waiting_children.empty?
            waiting_children.each do |child|
              child.reject!('Supervisor stopping - no more active children')
            end
          end

          @running = false
          return true
        end

        return false
      end
    end

    # Handle a child failure according to the supervision strategy
    # @param failed_child [Child] The child that failed
    # @param reason [Exception] The reason for the failure
    def handle_failure(failed_child, reason)
      return unless @running

      if failed_child.should_restart?(reason)
        failed_child.record_restart
        failed_child.restart(self)
      else
        check_children_status
      end
    end
  end

  class << self
    # Create a new supervisor with the given options
    # @param options [Hash] Configuration options for the supervisor
    # @return [Supervisor] The created supervisor
    def supervisor(options = {})
      Supervisor.new(options)
    end
  end
end
