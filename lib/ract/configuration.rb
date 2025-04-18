# frozen_string_literal: true # :rdoc:

class Ract
  class Configuration
    attr_accessor :isolation_level

    def initialize
      @isolation_level = :thread
    end
  end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end
  end
end
