# frozen_string_literal: true

require 'test_helper'

class BCDD::Result
  class Context::TransitionsEnabledWithSourceSingletonNestedTest < Minitest::Test
    include BCDDResultTransitionAssertions

    module Division
      extend self, Context.mixin(config: { addon: { continue: true } })

      def call(num1, num2)
        BCDD::Result.transitions do
          validate_numbers(num1, num2)
            .and_then(:validate_nonzero, useless_arg: true)
            .and_then(:divide)
        end
      end

      private

      def validate_numbers(num1, num2)
        num1.is_a?(Numeric) or return Failure(:invalid_arg, message: 'num1 must be numeric')
        num2.is_a?(Numeric) or return Failure(:invalid_arg, message: 'num2 must be numeric')

        Continue(num1: num1, num2: num2)
      end

      def validate_nonzero(num2:, **)
        num2.zero? ? Failure(:division_by_zero, message: 'num2 cannot be zero') : Continue()
      end

      def divide(num1:, num2:, **)
        Success(:division_completed, number: num1 / num2)
      end
    end

    module SumDivisionsByTwo
      extend self, Context.mixin

      def call(*numbers)
        BCDD::Result.transitions do
          divisions = numbers.map { divide_by_two(_1) }

          if divisions.any?(&:failure?)
            Failure(:errors, messages: divisions.select(&:failure?).map { _1.value[:message] })
          else
            Success(:sum, number: divisions.sum { _1.value[:number] })
          end
        end
      end

      private

      def divide_by_two(num)
        Division.call(num, 2)
      end
    end

    test 'nested transitions tracking' do
      result1 = SumDivisionsByTwo.call('30', '20', '10')
      result2 = SumDivisionsByTwo.call(30, '20', '10')
      result3 = SumDivisionsByTwo.call(30, 20, '10')
      result4 = SumDivisionsByTwo.call(30, 20, 10)

      assert_transitions(result1, size: 4)
      assert_transitions(result2, size: 6)
      assert_transitions(result3, size: 8)
      assert_transitions(result4, size: 10)
    end

    test 'nested transitions tracking in different threads' do
      t1 = Thread.new { SumDivisionsByTwo.call('30', '20', '10') }
      t2 = Thread.new { SumDivisionsByTwo.call(30, '20', '10') }
      t3 = Thread.new { SumDivisionsByTwo.call(30, 20, '10') }
      t4 = Thread.new { SumDivisionsByTwo.call(30, 20, 10) }

      result1 = t1.value
      result2 = t2.value
      result3 = t3.value
      result4 = t4.value

      assert_transitions(result1, size: 4)
      assert_transitions(result2, size: 6)
      assert_transitions(result3, size: 8)
      assert_transitions(result4, size: 10)
    end

    test 'the standard error handling' do
      assert_raises(ZeroDivisionError) do
        BCDD::Result.transitions { 2 / 0 }
      end

      result1 = SumDivisionsByTwo.call(30, 20, '10')
      result2 = SumDivisionsByTwo.call(30, 20, 10)

      assert_transitions(result1, size: 8)
      assert_transitions(result2, size: 10)
    end

    test 'an exception error handling' do
      assert_raises(NotImplementedError) do
        BCDD::Result.transitions { raise NotImplementedError }
      end

      result1 = SumDivisionsByTwo.call(30, 20, 10)
      result2 = SumDivisionsByTwo.call(30, 20, '10')

      assert_transitions(result1, size: 10)
      assert_transitions(result2, size: 8)
    end

    test 'the tracking records (one level of nesting)' do
      result = SumDivisionsByTwo.call('30', '20', '10')

      last_transition = result.transitions[:records].last

      assert_equal(last_transition.dig(:current, :id), last_transition.dig(:root, :id))

      root = last_transition.fetch(:current)

      assert_hash_schema!({ id: Integer, name: nil, desc: nil }, root)

      {
        root: root,
        parent: root,
        current: { id: Integer, name: nil, desc: nil },
        result: { kind: :failure, type: :invalid_arg, value: { message: 'num1 must be numeric' } }
      }.then { |spec| assert_transition_record(result, 0, spec) }

      {
        root: root,
        parent: root,
        current: { id: Integer, name: nil, desc: nil },
        result: { kind: :failure, type: :invalid_arg, value: { message: 'num1 must be numeric' } }
      }.then { |spec| assert_transition_record(result, 1, spec) }

      {
        root: root,
        parent: root,
        current: { id: Integer, name: nil, desc: nil },
        result: { kind: :failure, type: :invalid_arg, value: { message: 'num1 must be numeric' } }
      }.then { |spec| assert_transition_record(result, 2, spec) }

      {
        root: root,
        parent: root,
        current: root,
        result: { kind: :failure, type: :errors, value: { messages: ['num1 must be numeric'] * 3 } }
      }.then { |spec| assert_transition_record(result, 3, spec) }

      # ---

      assert_equal(4, result.transitions[:records].map { _1.dig(:current, :id) }.uniq.size)

      assert_equal(4, result.transitions[:records].map { _1[:time] }.tap { assert_equal(_1.sort, _1) }.uniq.size)
    end

    test 'the tracking records (multiple level of nesting)' do
      result = SumDivisionsByTwo.call('30', 20, 0)

      last_transition = result.transitions[:records].last

      assert_equal(last_transition.dig(:current, :id), last_transition.dig(:root, :id))

      root = last_transition.fetch(:current)

      assert_hash_schema!({ id: Integer, name: nil, desc: nil }, root)

      # 1st division transition
      #
      {
        root: root,
        parent: root,
        current: { id: Integer, name: nil, desc: nil },
        result: { kind: :failure, type: :invalid_arg, value: { message: 'num1 must be numeric' } }
      }.then { |spec| assert_transition_record(result, 0, spec) }

      # 2nd division transitions
      #
      refute_equal(
        result.transitions[:records][0].dig(:current, :id),
        result.transitions[:records][1].dig(:current, :id)
      )

      {
        root: root,
        parent: root,
        current: { id: Integer, name: nil, desc: nil },
        result: { kind: :success, type: :continued, value: { num1: 20, num2: 2 } }
      }.then { |spec| assert_transition_record(result, 1, spec) }

      {
        root: root,
        parent: root,
        current: { id: Integer, name: nil, desc: nil },
        result: { kind: :success, type: :continued, value: {} },
        and_then: { type: :method, arg: { useless_arg: true }, source: Division, method_name: :validate_nonzero }
      }.then { |spec| assert_transition_record(result, 2, spec) }

      {
        root: root,
        parent: root,
        current: { id: Integer, name: nil, desc: nil },
        result: { kind: :success, type: :division_completed, value: { number: 10 } },
        and_then: { type: :method, arg: {}, source: Division, method_name: :divide }
      }.then { |spec| assert_transition_record(result, 3, spec) }

      # 3rd division transitions
      #
      refute_equal(
        result.transitions[:records][3].dig(:current, :id),
        result.transitions[:records][4].dig(:current, :id)
      )

      {
        root: root,
        parent: root,
        current: { id: Integer, name: nil, desc: nil },
        result: { kind: :success, type: :continued, value: { num1: 0, num2: 2 } }
      }.then { |spec| assert_transition_record(result, 4, spec) }

      {
        root: root,
        parent: root,
        current: { id: Integer, name: nil, desc: nil },
        result: { kind: :success, type: :continued, value: {} },
        and_then: { type: :method, arg: { useless_arg: true }, source: Division, method_name: :validate_nonzero }
      }.then { |spec| assert_transition_record(result, 5, spec) }

      {
        root: root,
        parent: root,
        current: { id: Integer, name: nil, desc: nil },
        result: { kind: :success, type: :division_completed, value: { number: 0 } },
        and_then: { type: :method, arg: {}, source: Division, method_name: :divide }
      }.then { |spec| assert_transition_record(result, 6, spec) }

      # Final result transition
      #
      {
        root: root,
        parent: root,
        current: root,
        result: { kind: :failure, type: :errors, value: { messages: ['num1 must be numeric'] } }
      }.then { |spec| assert_transition_record(result, 7, spec) }

      assert_equal(8, result.transitions[:records].size)

      assert_equal(4, result.transitions[:records].map { _1.dig(:current, :id) }.uniq.size)

      assert_equal(8, result.transitions[:records].map { _1[:time] }.tap { assert_equal(_1.sort, _1) }.uniq.size)
    end
  end
end
