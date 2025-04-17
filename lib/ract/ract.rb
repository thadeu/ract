# frozen_string_literal: true

class Ract
  class Error < StandardError; end
  class Rejected < StandardError; end

  PENDING = :pending
  FULFILLED = :fulfilled
  REJECTED = :rejected

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

    if block_given? && auto_execute
      execute_block
    end
  end

  def execute_block
    return unless @block

    begin
      resolve(@block.call)
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
      return if @state != PENDING

      @state = REJECTED
      @reason = reason
      @condition&.broadcast
      execute_error_callbacks
    end
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

    if @state == REJECTED
      block.call(@reason)
    end

    self
  end
  alias catch rescue

  class << self
    include SingletonMethods
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

  def synchronize(&block)
    @mutex.synchronize(&block)
  end
end

Object.include Ract::Async
Module.extend Ract::Async
