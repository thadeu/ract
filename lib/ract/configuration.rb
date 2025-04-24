# frozen_string_literal: true

# frozen_string_literal: true # :rdoc:

require 'logger'

class Ract
  class Configuration
    attr_accessor :logger, :isolation_level, :monitor_enabled, :monitor_cleanup_dead, :supervisor_strategy,
                  :supervisor_max_restarts, :supervisor_max_seconds

    def initialize
      @logger = Logger.new($stdout)
      @logger.level = Logger::DEBUG
      @isolation_level = :thread
      @monitor_enabled = false
      @monitor_cleanup_dead = false
      @supervisor_strategy = nil
      @supervisor_max_restarts = 3
      @supervisor_max_seconds = 5
    end
  end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    def logger(...) = config.logger(...)
  end
end
