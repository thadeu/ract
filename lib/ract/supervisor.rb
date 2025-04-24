# frozen_string_literal: true

require 'forwardable'

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
        auto_start: options.fetch(:auto_start, false),
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
    # @param restart_block [Proc] The block to execute when restarting the promise
    # @return [ArgumentError] If the promise is not a Ract object
    # @return [Ract] The supervised promise
    def add_child(promise, restart_policy: PERMANENT)
      raise ArgumentError, "Expected Ract promise, got #{promise.class}" unless promise.is_a?(Ract)

      @mutex.synchronize do
        @children << {
          promise: promise,
          restart_policy: restart_policy,
          # restart_block: block_given? ? Ract.new(&promise) : Ract.new{ },
          restarts: 0,
          restart_times: [],
        }

        monitor_child(@children.last) if @running
      end

      promise
    end

    # Start the supervision process
    # @return [Boolean] Whether the supervisor was started
    def start!
      synchronize do
        return false if @running

        @running = true
        @children.each { |child| monitor_child(child) }
      end

      true
    end

    # Shutdown the supervisor
    # @return [Boolean] true if the supervisor was running and is now stopped
    def shutdown!
      synchronize do
        return false unless @running

        logger.info "Shutting down supervisor #{@name}"
        @running = false

        # Cancel all pending or waiting children
        @children.each do |child|
          if child[:promise].pending? || child[:promise].waiting?
            logger.info "Canceling child in state #{child[:promise].state} during shutdown"
            child[:promise].reject('Supervisor shutdown')
          end
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
          children: @children.map.with_index do |child, index|
            {
              index: index,
              state: child[:promise].state,
              restart_policy: child[:restart_policy],
              restarts: child[:restarts],
            }
          end,
        }
      end
    end

    def running? = synchronize { @running }

    private

    def synchronize(&) = @mutex.synchronize(&)

    # Monitor a child promise and handle failures
    # @param child [Hash] The child to monitor
    def monitor_child(child)
      return unless @running

      # Set up error callback to handle failures
      child[:promise].then do |result|
        # Quando um child é concluído com sucesso, verificar o status geral
        Thread.new do
          logger.info "Child completed successfully with result: #{result.inspect}"
          check_children_status if @running
        end
      end.rescue do |reason|
        # Quando um child falha, tratar a falha
        Thread.new do
          logger.info "Child failed with reason: #{reason.inspect}"
          handle_failure(child, reason) if @running
        end
      end
    end

    # Check if all children have completed and set running to false if they have
    def check_children_status
      synchronize do
        # Verificar se o supervisor já foi encerrado
        return false unless @running

        # Imprimir o estado atual de todos os children para depuração
        states = @children.map { |c| [c[:promise].state, c[:restarts]] }
        logger.info "Checking children status: #{states.map { |s, r| "#{s}(#{r})" }.join(', ')}"

        # Verificar se todos os children estão em estado terminal ou não podem mais progredir
        all_terminal = @children.all? do |child|
          child[:promise].fulfilled? ||
            (child[:promise].rejected? && child[:restarts] >= @options[:max_restarts]) ||
            child[:promise].waiting?
        end

        # Se todos os children estão em estado terminal ou waiting
        if all_terminal
          # Verificar se há algum child que ainda não atingiu o limite de restarts
          active_children = @children.reject do |child|
            child[:promise].fulfilled? ||
              (child[:promise].rejected? && child[:restarts] >= @options[:max_restarts])
          end

          if active_children.empty?
            # Se não há mais children ativos, rejeitar os que estão em waiting
            waiting_children = @children.select { |child| child[:promise].waiting? }

            unless waiting_children.empty?
              logger.info "Found #{waiting_children.size} children in waiting state, rejecting them before stopping"
              waiting_children.each do |child|
                child[:promise].reject!('Supervisor stopping - no more active children')
              end
            end

            logger.info 'All children are in terminal state or have reached max restarts, stopping supervision'
            @running = false
            return true
          end
        end

        # No special strategy handling needed in check_children_status

        # Se chegamos até aqui, o supervisor deve continuar em execução
        return false
      end
    end

    # Handle a child failure according to the supervision strategy
    # @param failed_child [Hash] The child that failed
    # @param reason [Exception] The reason for the failure
    def handle_failure(failed_child, reason)
      # Use a non-blocking approach to avoid deadlocks with promise callbacks
      return unless @running

      # Check if the child can be restarted
      if should_restart?(failed_child, reason)
        # Record the restart attempt
        record_restart(failed_child)

        # Always use ONE_FOR_ONE strategy (simple restart of just the failed child)
        restart_child(failed_child)
      else
        logger.info 'Child cannot be restarted, checking if supervisor should stop'
        check_children_status
      end
    end

    # Determine if a child should be restarted based on policy and limits
    # @param child [Hash] The child to check
    # @param reason [Exception] The reason for the failure
    # @return [Boolean] Whether the child should be restarted
    def should_restart?(child, _reason)
      # Check restart policy
      case child[:restart_policy]
      when TEMPORARY, TRANSIENT
        return false
      end

      if restart_times_by_child?(child)
        check_children_status
        return false
      end

      true
    end

    def restart_times_by_child?(child)
      count = synchronize { restart_times_by_child(child) }
      count >= @options[:max_restarts]
    end

    # Restart a child promise
    # @param child [Hash] The child to restart
    def restart_child(child)
      # Verificar se já atingimos o limite máximo de reinicializações
      logger.info "Cannot restart child: already at maximum restarts (#{child[:restarts]}/#{@options[:max_restarts]})"

      # Increment the restart counter before attempting restart
      child[:restarts] += 1

      logger.info "Restarting child (attempt #{child[:restarts]}/#{@options[:max_restarts]})"

      # Garantir que o promise esteja no estado pendente
      # mesmo que já tenha sido definido como pendente anteriormente
      child[:promise].pending!

      # Set up monitoring for the new promise
      monitor_child(child)

      # Executar o bloco de código novamente em uma nova thread
      # para evitar bloqueios e permitir que o supervisor continue funcionando
      Thread.new do
        # Executar o bloco de código novamente
        child[:promise].execute_block
      rescue StandardError => e
        logger.error "Error executing restarted child: #{e.message}"
        # Handle failure in a separate thread to avoid deadlocks
        Thread.new do
          handle_failure(child, e) if @running
        end

        # Check children status after handling the failure
        Thread.new do
          sleep 0.1 # Give time for the failure to be handled
          check_children_status if @running
        end
      end
    end

    # Record a restart event for a specific child
    # @param child [Hash] The child that was restarted
    def record_restart(child)
      now = Time.now

      # Record restart time for this specific child
      child[:restart_times] << now

      # Clean up old restart records for this child
      child[:restart_times].reject! { |time| time < now - @options[:max_seconds] }
    end

    def restart_times_by_child(child)
      child[:restart_times].count { |time| time > Time.now - @options[:max_seconds] }
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
