#!/usr/bin/env ruby

require 'bundler/setup'
require 'json'
require 'ract'

class SimpleLogger
  def self.info(message)
    puts "[INFO] #{message}"
  end

  def self.warn(message)
    puts "[WARN] #{message}"
  end

  def self.error(message)
    puts "[ERROR] #{message}"
  end
end

Ract.configure do |config|
  config.logger = SimpleLogger
  config.monitor_enabled = true
  config.supervisor_strategy = Ract::Supervisor::ONE_FOR_ONE
  config.supervisor_max_restarts = 4
  config.supervisor_max_seconds = 10
end

puts "\n"
Ract.logger.info "Creating a supervisor..."

# Create a supervisor
supervisor = Ract.supervisor(
  name: 'AWS Request',
  strategy: Ract::Supervisor::REST_FOR_ONE
)

# Define a function that will sometimes fail
def sometimes_fail(id, fail_rate = 0.5)
  Ract.logger.info "Task #{id}: Starting work..."
  sleep(rand * 0.5)  # Simulate some work (shorter duration for the example)

  if rand < fail_rate
    Ract.logger.info "Task #{id}: Failed!"
    raise "Task #{id} failed randomly"
  else
    Ract.logger.info "Task #{id}: Completed successfully"
    "Result from task #{id}"
  end
end

Ract.logger.info "Creating supervised (#{supervisor.name}) promises...\n\n"

promises = []

father = Ract { sometimes_fail("Father", rand(0.6..0.8)) }
child1 = Ract { sometimes_fail("Child 1", rand(0.6..0.8)) }

promises << father
promises << child1

supervisor.add_child(father, restart_policy: Ract::Supervisor::PERMANENT)
supervisor.add_child(child1, restart_policy: Ract::Supervisor::PERMANENT)

supervisor.start!

# Ract.take(promises, raise_on_error: false)

loop do
  sleep 1
  puts "Supervisor status: #{supervisor.running?}"
  break if !supervisor.running?
end

# puts "\nFinal supervisor stats:"
puts JSON.pretty_generate(supervisor.stats)

# Check the results of each promise
puts "\nFinal promise states:"

promises.each_with_index do |promise, i|
  puts "Promise #{i}: State=#{promise.state}, " +
       (promise.fulfilled? ? "Value=#{promise.value.inspect}" : "Reason=#{promise.reason.inspect}")
end

# Check thread monitor stats
puts "\nThread monitor stats:"
puts Ract::ThreadMonitor.stats.inspect

# Wait a moment to allow any remaining threads to finish
puts "\nWaiting for any remaining threads to finish..."
