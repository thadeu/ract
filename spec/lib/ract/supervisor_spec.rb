# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ract::Supervisor do
  let(:supervisor) { Ract.supervisor(auto_start: false) }
  let(:promise) { Ract.new }

  describe '#initialize' do
    it 'creates a supervisor with default options' do
      expect(supervisor.options[:strategy]).to eq(Ract::Supervisor::ONE_FOR_ONE)
      expect(supervisor.options[:max_restarts]).to eq(3)
      expect(supervisor.options[:max_seconds]).to eq(5)
      expect(supervisor.options[:auto_start]).to eq(false)
    end

    it 'creates a supervisor with custom options' do
      custom_supervisor = Ract.supervisor(
        strategy: Ract::Supervisor::ONE_FOR_ONE,
        max_restarts: 5,
        max_seconds: 10,
        auto_start: false,
        name: 'TestSupervisor'
      )

      expect(custom_supervisor.options[:strategy]).to eq(Ract::Supervisor::ONE_FOR_ONE)
      expect(custom_supervisor.options[:max_restarts]).to eq(5)
      expect(custom_supervisor.options[:max_seconds]).to eq(10)
      expect(custom_supervisor.options[:auto_start]).to eq(false)
      expect(custom_supervisor.name).to eq('TestSupervisor')
    end

    it 'auto-starts the supervisor when auto_start is true' do
      supervisor = Ract.supervisor(auto_start: true)
      expect(supervisor.running?).to be true
    end
  end

  describe '#add_child' do
    it 'adds a promise to the supervisor' do
      child = supervisor.add_child(promise)

      expect(supervisor.children.size).to eq(1)
      expect(child).to eq(promise)
    end

    it 'adds a promise with custom restart policy' do
      supervisor.add_child(promise, restart_policy: Ract::Supervisor::TEMPORARY)

      child = supervisor.children.first

      expect(child.restart_policy).to eq(Ract::Supervisor::TEMPORARY)
    end

    it 'raises an error when trying to supervise a non-Ract object' do
      expect { supervisor.add_child("not a promise") }.to raise_error(ArgumentError)
    end

    it 'monitors the child immediately if supervisor is running' do
      supervisor.start!
      expect_any_instance_of(Ract::Supervisor::Child).to receive(:monitor).once
      supervisor.add_child(Ract.new)
    end
  end

  describe '#start!' do
    it 'starts the supervision process' do
      expect(supervisor.running?).to be false

      supervisor.start!

      expect(supervisor.running?).to be true
    end

    it 'monitors all children when started' do
      supervisor.add_child(Ract.new)
      supervisor.add_child(Ract.new)

      supervisor.children.each do |child|
        expect(child).to receive(:monitor).once
      end

      supervisor.start!
    end

    it 'returns false if supervisor is already running' do
      supervisor.start!

      expect(supervisor.start!).to be false
    end
  end

  describe '#shutdown!' do
    before do
      supervisor.start!
    end

    it 'stops the supervision process' do
      expect(supervisor.running?).to be true

      supervisor.shutdown!

      expect(supervisor.running?).to be false
    end

    it 'rejects all idle promises' do
      promise1 = Ract.new
      promise2 = Ract.new

      supervisor.add_child(promise1)
      supervisor.add_child(promise2)

      supervisor.shutdown!

      expect(promise1.rejected?).to be true
      expect(promise2.rejected?).to be true
    end

    it 'returns false if supervisor is not running' do
      supervisor.shutdown!
      expect(supervisor.shutdown!).to be false
    end
  end

  describe '#stats' do
    before do
      supervisor.start!
      supervisor.add_child(promise)
    end

    it 'returns statistics about supervised promises' do
      stats = supervisor.stats

      expect(stats).to include(
        name: 'Main',
        running: true,
        children_count: 1,
        strategy: Ract::Supervisor::ONE_FOR_ONE,
        max_restarts: 3,
        max_seconds: 5
      )

      expect(stats[:children]).to be_an(Array)

      expect(stats[:children].first).to include(
        index: 0,
        state: Ract::IDLE,
        restart_policy: Ract::Supervisor::PERMANENT,
        restarts: 0
      )
    end
  end

  describe '#running?' do
    it 'returns false when supervisor is not started' do
      expect(supervisor.running?).to be false
    end

    it 'returns true when supervisor is started' do
      supervisor.start!
      expect(supervisor.running?).to be true
    end

    it 'returns false after shutdown' do
      supervisor.start!
      supervisor.shutdown!

      expect(supervisor.running?).to be false
    end
  end

  describe '#handle_failure' do
    let(:failing_promise) do
      Ract.new do
        raise "Test failure"
      end
    end

    before do
      supervisor.start!
      supervisor.add_child(failing_promise)
    end

    it 'restarts a child with PERMANENT policy' do
      # Ensure the promise is set to PERMANENT restart policy
      expect(supervisor.children.first.restart_policy).to eq(Ract::Supervisor::PERMANENT)

      # Trigger failure
      failing_promise.execute_block rescue nil

      sleep(0.1) # Give time for the restart to happen

      # The promise should have been restarted
      expect(supervisor.children.first.restarts).to eq(3)
    end

    it 'does not restart a child with TEMPORARY policy' do
      temp_promise = Ract.new { raise "Temporary failure" }

      supervisor.add_child(temp_promise, restart_policy: Ract::Supervisor::TEMPORARY)

      expect(temp_promise).not_to receive(:idle!)

      temp_promise.execute_block rescue nil

      sleep(0.1)
    end

    it 'stops restarting after max_restarts is reached' do
      limited_supervisor = Ract.supervisor(max_restarts: 2, auto_start: true)

      test_promise = Ract.new { raise "Always fails" }

      limited_supervisor.add_child(test_promise)

      3.times do
        test_promise.execute_block rescue nil
        sleep(0.1)
      end

      child = limited_supervisor.children.first

      expect(child.restarts).to be <= 3
    end
  end

  describe '#check_children_status' do
    it 'stops the supervisor when all children are in terminal state' do
      supervisor.start!

      promise1 = Ract.new { "Success" }
      promise2 = Ract.new { "Also success" }

      supervisor.add_child(promise1)
      supervisor.add_child(promise2)

      # Execute both promises to completion
      promise1.execute_block
      promise2.execute_block

      sleep(0.1) # Give time for the supervisor to check status

      expect(supervisor.running?).to be false
    end

    it 'keeps the supervisor running when some children are still active' do
      supervisor.start!
      promise1 = Ract.new { "Success" }
      promise2 = Ract.new

      supervisor.add_child(promise1)
      supervisor.add_child(promise2)

      promise1.execute_block

      sleep(0.1) # Give time for the supervisor to check status

      expect(supervisor.running?).to be true
    end
  end

  describe 'child management' do
    it 'adds a restart time to the child record' do
      supervisor.start!
      supervisor.add_child(promise)

      child = supervisor.children.first

      expect { child.record_restart }.to change { child.restart_times.size }.by(1)
    end

    it 'cleans up old restart records' do
      supervisor.start!
      supervisor.add_child(promise)
      child = supervisor.children.first

      # Add an old restart time
      old_time = Time.now - 10
      child.restart_times << old_time

      child.record_restart

      # Should have removed the old time and added a new one
      expect(child.restart_times).not_to include(old_time)
      expect(child.restart_times.size).to eq(1)
    end
  end

  describe 'integration tests' do
    it 'handles a mix of successful and failing promises' do
      supervisor = Ract.supervisor(max_restarts: 3, auto_start: true)

      success_promise = Ract.new { "Success" }

      fail_once_promise = Ract.new do
        @attempts ||= 0
        @attempts += 1

        raise "Failing once" if @attempts == 1

        "Success after failure"
      end

      always_fail_promise = Ract.new { raise "Always fails" }

      supervisor.add_child(success_promise)
      supervisor.add_child(fail_once_promise)
      supervisor.add_child(always_fail_promise, restart_policy: Ract::Supervisor::TEMPORARY)

      # Execute all promises
      success_promise.execute_block
      fail_once_promise.execute_block rescue nil
      always_fail_promise.execute_block rescue nil

      sleep(0.2) # Give time for supervisor to process

      # Check results
      expect(success_promise.fulfilled?).to be true
      expect(fail_once_promise.fulfilled?).to be true # Should have succeeded on retry
      expect(always_fail_promise.rejected?).to be true # Should stay rejected

      # Check restart counts
      stats = supervisor.stats

      expect(stats[:children][0][:restarts]).to eq(0) # success_promise
      expect(stats[:children][1][:restarts]).to eq(1) # fail_once_promise
      expect(stats[:children][2][:restarts]).to eq(0) # always_fail_promise (TEMPORARY)
    end
  end
end
