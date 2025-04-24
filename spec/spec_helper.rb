# frozen_string_literal: true

require 'support/simplecov_setup'
require 'pry'
require 'ract'
require 'logger'

Ract.configure do |config|
  config.logger.level = Logger::ERROR
end

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
