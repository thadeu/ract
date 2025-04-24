# frozen_string_literal: true

class Ract
  class Error < StandardError; end
  class Rejected < StandardError; end

  PENDING = :pending
  FULFILLED = :fulfilled
  REJECTED = :rejected
  WAITING = :waiting

  attr_reader :state, :value, :reason

  def initialize(value = nil, auto_execute: false, &block)
    @state = PENDING
    @value = value
    @reason = nil
    @mutex = Mutex.new
    @condition = ConditionVariable.new

    @callbacks = []
    @error_callbacks = []
    @block = block

    return unless block_given? && auto_execute

    execute_block
  end

  def execute_block(...)
    return unless @block

    begin
      resolve(@block.call(...))
    rescue StandardError => e
      reject(e)
    end
  end

  def fulfilled?
    @state == FULFILLED
  end

  def rejected?
    @state == REJECTED
  end

  def pending?
    @state == PENDING
  end

  def waiting?
    @state == WAITING
  end

  def await
    raise Rejected, @reason.to_s if @state == REJECTED

    resolve

    @value
  end

  def resolve(value = nil)
    synchronize do
      return if @state != PENDING

      @state = FULFILLED
      @value = value.nil? && @block ? @block.call : value
      @condition&.broadcast
      execute_callbacks
    end
  end

  def reject(reason = nil)
    synchronize do
      # Permitir rejeição quando o promise está em estado PENDING ou WAITING
      return self if @state != PENDING && @state != WAITING

      old_state = @state
      @state = REJECTED
      @reason = reason
      @condition&.broadcast

      Ract.logger.info "Rejecting promise from state #{old_state} to REJECTED"
      execute_error_callbacks
    end

    self
  end

  def reject!(reason)
    synchronize do
      @state = REJECTED
      @value = reason

      @error_callbacks.each do |callback|
        callback.call(reason)
      end
    end

    self
  end

  def then(&block)
    return self unless block_given?

    if @state == PENDING
      execute_block
      @callbacks << block
    end

    return self if @state == REJECTED

    begin
      block.call(@value)
    rescue StandardError => e
      @state = REJECTED
      @reason = e
      reject(e)
    end

    self
  end
  alias and_then then

  def rescue(&block)
    return self unless block_given?

    if @state == PENDING
      execute_block
      @error_callbacks << block
    end

    block.call(@reason) if @state == REJECTED

    self
  end
  alias catch rescue

  def pending!
    synchronize do
      @state = PENDING
      @reason = nil
      @value = nil
    end

    self
  end

  def waiting!
    synchronize do
      @state = WAITING
      # Mantemos reason e value para referência futura
    end

    self
  end

  class << self
    include ClassMethods
  end

  private

  def execute_callbacks
    callbacks = @callbacks.dup
    @callbacks.clear
    callbacks.each { |callback| callback.call(@value) }
  end

  def execute_error_callbacks
    callbacks = @error_callbacks.dup
    @error_callbacks.clear
    callbacks.each { |callback| callback.call(@reason) }
  end

  def synchronize(&)
    @mutex.synchronize(&)
  end
end

Object.include Ract::Async
Module.extend Ract::Async
