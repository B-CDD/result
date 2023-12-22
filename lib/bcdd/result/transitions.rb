# frozen_string_literal: true

require 'securerandom'

class BCDD::Result
  module Transitions
    class Tracking
      attr_accessor :started, :records, :root_id

      private :started=, :root_id, :root_id=, :records=

      def start!(id:)
        return if started

        self.started = true
        self.root_id = id
        self.records = []
      end

      def reset!
        self.started = nil
        self.root_id = nil
        self.records = []
      end

      def root_id?(id)
        root_id == id
      end

      def add(result)
        records << { root_id: root_id, data: result.data }
      end
    end

    def self.track(result)
      tracking.add(result) if tracking.started
    end

    def self.start(id:)
      tracking.start!(id: id)
    end

    def self.finish(id:, result:)
      result.is_a?(::BCDD::Result) or raise Error::UnexpectedOutcome.build(outcome: result, origin: :transitions)

      return unless tracking.root_id?(id)

      result.send(:transitions=, tracking.records)

      reset!
    end

    def self.reset!
      tracking.reset!
    end

    def self.tracking
      Thread.current[:bcdd_result_transitions_tracking] ||= Tracking.new
    end

    class << self
      private :tracking
    end
  end

  def self.transitions(id: SecureRandom.uuid)
    Transitions.start(id: id)

    result = yield

    Transitions.finish(id: id, result: result)

    result
  rescue ::Exception => e
    Transitions.reset!

    raise e
  end
end
