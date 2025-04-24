# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ract::Supervisor::Child do
  let(:promise) { Ract.new { "test result" } }
  let(:child) { Ract::Supervisor::Child.new(promise, restart_policy: Ract::Supervisor::PERMANENT, max_restarts: 3, max_seconds: 5) }
  let(:supervisor) { Ract.supervisor(auto_start: false) }

  describe '#initialize' do
    it 'creates a child with the given promise and restart policy' do
      expect(child.promise).to eq(promise)
      expect(child.restart_policy).to eq(Ract::Supervisor::PERMANENT)
      expect(child.restarts).to eq(0)
      expect(child.restart_times).to be_empty
    end

    it 'raises an error when trying to create a child with a non-Ract object' do
      expect { Ract::Supervisor::Child.new("not a promise", restart_policy: Ract::Supervisor::PERMANENT, max_restarts: 3, max_seconds: 5) }.to raise_error(ArgumentError)
    end
  end

  describe '#monitor' do
    it 'sets up callbacks for promise completion' do
      expect(promise).to receive(:then).and_return(promise)
      expect(promise).to receive(:rescue)

      child.monitor(supervisor)
    end

    it 'returns self for method chaining' do
      allow(promise).to receive(:then).and_return(promise)
      allow(promise).to receive(:rescue)

      expect(child.monitor(supervisor)).to eq(child)
    end
  end

  describe '#terminal?' do
    it 'returns true when promise is fulfilled' do
      allow(promise).to receive(:fulfilled?).and_return(true)

      expect(child.terminal?(3)).to be true
    end

    it 'returns true when promise is rejected and max restarts reached' do
      allow(promise).to receive(:fulfilled?).and_return(false)
      allow(promise).to receive(:rejected?).and_return(true)
      allow(promise).to receive(:waiting?).and_return(false)

      child.instance_variable_set(:@restarts, 3)

      expect(child.terminal?(3)).to be true
    end

    it 'returns true when promise is waiting' do
      allow(promise).to receive(:fulfilled?).and_return(false)
      allow(promise).to receive(:rejected?).and_return(false)
      allow(promise).to receive(:waiting?).and_return(true)

      expect(child.terminal?(3)).to be true
    end

    it 'returns false when promise is rejected but max restarts not reached' do
      allow(promise).to receive(:fulfilled?).and_return(false)
      allow(promise).to receive(:rejected?).and_return(true)
      allow(promise).to receive(:waiting?).and_return(false)

      child.instance_variable_set(:@restarts, 2)

      expect(child.terminal?(3)).to be false
    end
  end

  describe '#active?' do
    it 'returns false when promise is fulfilled' do
      allow(promise).to receive(:fulfilled?).and_return(true)
      allow(promise).to receive(:rejected?).and_return(false)

      expect(child.active?(3)).to be false
    end

    it 'returns false when promise is rejected and max restarts reached' do
      allow(promise).to receive(:fulfilled?).and_return(false)
      allow(promise).to receive(:rejected?).and_return(true)

      child.instance_variable_set(:@restarts, 3)

      expect(child.active?(3)).to be false
    end

    it 'returns true when promise is rejected but max restarts not reached' do
      allow(promise).to receive(:fulfilled?).and_return(false)
      allow(promise).to receive(:rejected?).and_return(true)

      child.instance_variable_set(:@restarts, 2)

      expect(child.active?(3)).to be true
    end
  end

  describe 'state delegation methods' do
    it 'delegates waiting? to promise' do
      expect(promise).to receive(:waiting?)
      child.waiting?
    end

    it 'delegates fulfilled? to promise' do
      expect(promise).to receive(:fulfilled?)
      child.fulfilled?
    end

    it 'delegates rejected? to promise' do
      expect(promise).to receive(:rejected?)
      child.rejected?
    end

    it 'delegates pending? to promise' do
      expect(promise).to receive(:pending?)
      child.pending?
    end

    it 'delegates state to promise' do
      expect(promise).to receive(:state)
      child.state
    end

    it 'delegates reject! to promise' do
      expect(promise).to receive(:reject!).with('reason')
      child.reject!('reason')
    end

    it 'delegates pending! to promise' do
      expect(promise).to receive(:pending!)
      child.pending!
    end

    it 'delegates execute_block to promise' do
      expect(promise).to receive(:execute_block)
      child.execute_block
    end
  end

  describe '#record_restart' do
    it 'adds a restart time to the restart_times array' do
      expect { child.record_restart }.to change { child.restart_times.size }.by(1)
    end

    it 'increments the restart counter' do
      expect { child.record_restart }.to change { child.restarts }.by(1)
    end

    it 'cleans up old restart records' do
      # Add an old restart time
      old_time = Time.now - 10 # 10 seconds ago, beyond the default 5 second window
      child.restart_times << old_time

      child.record_restart

      # Should have removed the old time and added a new one
      expect(child.restart_times).not_to include(old_time)
      expect(child.restart_times.size).to eq(1)
    end
  end

  describe '#should_restart?' do
    it 'returns false for TEMPORARY restart policy' do
      temp_child = Ract::Supervisor::Child.new(
        promise,
        restart_policy: Ract::Supervisor::TEMPORARY,
        max_restarts: 3,
        max_seconds: 5
      )

      expect(temp_child.should_restart?(StandardError.new)).to be false
    end

    it 'returns false for TRANSIENT restart policy' do
      transient_child = Ract::Supervisor::Child.new(
        promise,
        restart_policy: Ract::Supervisor::TRANSIENT,
        max_seconds: 5,
        max_restarts: 3
      )

      expect(transient_child.should_restart?(StandardError.new)).to be false
    end

    it 'returns false when max restarts is reached' do
      # Add restart times within the window
      now = Time.now
      3.times { child.restart_times << (now - 1) }

      expect(child.should_restart?(StandardError.new)).to be false
    end

    it 'returns true for PERMANENT restart policy when max restarts not reached' do
      expect(child.should_restart?(StandardError.new)).to be true
    end
  end

  describe '#restart' do
    it 'sets the promise to pending state' do
      expect(promise).to receive(:pending!)
      allow(promise).to receive(:execute_block) # Prevent actual execution

      child.restart(supervisor)
    end

    it 'monitors the child again' do
      expect(child).to receive(:monitor).with(supervisor)
      allow(promise).to receive(:execute_block) # Prevent actual execution

      child.restart(supervisor)
    end

    it 'executes the promise block in a new thread' do
      # Use a spy to verify the method was called without expecting specific count
      # since the implementation might call it multiple times
      allow(promise).to receive(:execute_block)

      child.restart(supervisor)

      sleep(0.1) # Give time for the thread to execute
      expect(promise).to have_received(:execute_block).at_least(:once)
    end
  end

  describe '#stats' do
    it 'returns statistics about the child' do
      allow(promise).to receive(:state).and_return(Ract::PENDING)

      stats = child.stats(1)

      expect(stats).to include(
        index: 1,
        state: Ract::PENDING,
        restart_policy: Ract::Supervisor::PERMANENT,
        restarts: 0
      )
    end
  end
end
