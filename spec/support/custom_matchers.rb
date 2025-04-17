# frozen_string_literal: true

RSpec::Matchers.define(:assert_nothing_raised) do
  describe { 'dont raised' }

  match do |block|
    block.call
    true
  rescue StandardError
    false
  end
end
