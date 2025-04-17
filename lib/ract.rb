# frozen_string_literal: true

require 'ract/version'
require 'ract/batch'
require 'ract/result'
require 'ract/settled'
require 'ract/async'
require 'ract/single_methods'
require 'ract/ract'

# A lightweight Promise implementation for Ruby
#
# == Usage
#
# You can use `Ract.new` or `Ract` to create a new promise
#
#   Ract.new { 1 }
#
#   Ract { 1 }
#
# You can use `async` to define an async method
#     class ComplexTask
#       async def self.execute(...)
#         new(...).execute
#       end
#
#       def initialize(...)
#       end
#
#       def execute
#       end
#
#       async def call
#         # your complex logic
#       end
#     end
#
# If you use with color async method, you must be use with suffix _async, for example:
# This will create another method with _async suffix, to encapsulate the logic in a Thread
#
#    ComplexTask.call_async
#
#    ComplexTask.execute_async
#
# You can use `ract` or `go` to define a method that returns a promise
#
#   def call
#     ract { 1 }
#   end
#
#   def call
#     go { 1 }
#   end
#
#   def call
#     Ract { 1 }
#   end
#
# == Multiple Racts
#
# You can use `Ract.take` to perform multiple promises together
#
#   tasks = [ Ract { 1 }, Ract.new { 2 } ]
#
# Running your tasks using .take
#
#   result = Ract.take(tasks)
#
# after that you will have an array with results
#
#   p result -> [1, 2]
#
class Ract
end
