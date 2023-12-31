# frozen_string_literal: true

require 'test_helper'

class BCDD::Result::TransitionsDisabledWithSourceRecursionTest < Minitest::Test
  include BCDDResultTransitionAssertions

  def setup
    BCDD::Result.config.feature.disable!(:transitions)
  end

  def teardown
    BCDD::Result.config.feature.enable!(:transitions)
  end

  class Fibonacci
    include BCDD::Result.mixin

    def call(input)
      BCDD::Result.transitions do
        require_valid_number(input).and_then do |number|
          fibonacci = number <= 1 ? number : call(number - 1).value + call(number - 2).value

          Success(:fibonacci, fibonacci)
        end
      end
    end

    private

    def require_valid_number(input)
      input.is_a?(Numeric) or return Failure(:invalid_input, 'input must be numeric')

      input.negative? and return Failure(:invalid_number, 'number cannot be negative')

      Success(:positive_number, input)
    end
  end

  test 'transitions inside a recursion' do
    failure1 = Fibonacci.new.call('1')
    failure2 = Fibonacci.new.call(-1)

    fibonacci0 = Fibonacci.new.call(0)
    fibonacci1 = Fibonacci.new.call(1)
    fibonacci2 = Fibonacci.new.call(2)

    assert_empty_transitions(failure1)
    assert_empty_transitions(failure2)

    assert_empty_transitions(fibonacci0)
    assert_empty_transitions(fibonacci1)
    assert_empty_transitions(fibonacci2)
  end
end
