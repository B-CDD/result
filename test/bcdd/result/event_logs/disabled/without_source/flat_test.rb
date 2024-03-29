# frozen_string_literal: true

require 'test_helper'

class BCDD::Result::EventLogsDisabledWithoutSourceFlatTest < Minitest::Test
  include BCDDResultEventLogAssertions

  def setup
    BCDD::Result.config.feature.disable!(:event_logs)
  end

  def teardown
    BCDD::Result.config.feature.enable!(:event_logs)
  end

  module Division
    extend self

    def call(num1, num2)
      BCDD::Result.event_logs do
        validate_numbers(num1, num2)
          .and_then { |numbers| validate_nonzero(numbers) }
          .and_then { |numbers| divide(numbers) }
      end
    end

    private

    def validate_numbers(num1, num2)
      num1.is_a?(Numeric) or return BCDD::Result::Failure(:invalid_arg, 'num1 must be numeric')
      num2.is_a?(Numeric) or return BCDD::Result::Failure(:invalid_arg, 'num2 must be numeric')

      BCDD::Result::Success(:ok, [num1, num2])
    end

    def validate_nonzero(numbers)
      return BCDD::Result::Failure(:division_by_zero, 'num2 cannot be zero') if numbers.last.zero?

      BCDD::Result::Success(:ok, numbers)
    end

    def divide((num1, num2))
      BCDD::Result::Success(:ok, num1 / num2)
    end
  end

  test 'the tracking without nesting' do
    result1 = Division.call('4', 2)
    result2 = Division.call(4, '2')
    result3 = Division.call(4, 0)
    result4 = Division.call(4, 2)

    assert_empty_event_logs(result1)
    assert_empty_event_logs(result2)
    assert_empty_event_logs(result3)
    assert_empty_event_logs(result4)
  end

  test 'the tracking without nesting in different threads' do
    t1 = Thread.new { Division.call('4', 2) }
    t2 = Thread.new { Division.call(4, '2') }
    t3 = Thread.new { Division.call(4, 0) }
    t4 = Thread.new { Division.call(4, 2) }

    result1 = t1.value
    result2 = t2.value
    result3 = t3.value
    result4 = t4.value

    assert_empty_event_logs(result1)
    assert_empty_event_logs(result2)
    assert_empty_event_logs(result3)
    assert_empty_event_logs(result4)
  end

  test 'the standard error handling' do
    assert_raises(ZeroDivisionError) do
      BCDD::Result.event_logs { 2 / 0 }
    end

    result1 = Division.call(4, 0)
    result2 = Division.call(4, 2)

    assert_empty_event_logs(result1)
    assert_empty_event_logs(result2)
  end

  test 'an exception handling' do
    assert_raises(NotImplementedError) do
      BCDD::Result.event_logs { raise ::NotImplementedError }
    end

    result1 = Division.call(4, 2)
    result2 = Division.call(4, 0)

    assert_empty_event_logs(result1)
    assert_empty_event_logs(result2)
  end
end
