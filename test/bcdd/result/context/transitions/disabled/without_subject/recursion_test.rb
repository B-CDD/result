# frozen_string_literal: true

require 'test_helper'

class BCDD::Result
  class Context::TransitionsDisabledWithoutSubjectInstanceRecursionTest < Minitest::Test
    def setup
      BCDD::Result.config.feature.disable!(:transitions)
    end

    def teardown
      BCDD::Result.config.feature.enable!(:transitions)
    end

    module Fibonacci
      extend self

      def call(input)
        BCDD::Result.transitions do
          require_valid_number(input).and_then do |output|
            number = output.fetch(:number)

            fibonacci = number <= 1 ? number : call(number - 1).value[:number] + call(number - 2).value[:number]

            Context::Success(:fibonacci, number: fibonacci)
          end
        end
      end

      private

      def require_valid_number(input)
        input.is_a?(Numeric) or return Context::Failure(:invalid_input, message: 'input must be numeric')

        input.negative? and return Context::Failure(:negative_number, message: 'number cannot be negative')

        Context::Success(:positive_number, number: input)
      end
    end

    test 'transitions inside a recursion' do
      failure1 = Fibonacci.call('1')
      failure2 = Fibonacci.call(-1)

      fibonacci0 = Fibonacci.call(0)
      fibonacci1 = Fibonacci.call(1)
      fibonacci2 = Fibonacci.call(2)

      assert_equal(0, failure1.transitions.size)
      assert_equal(0, failure2.transitions.size)

      assert_equal(0, fibonacci0.transitions.size)
      assert_equal(0, fibonacci1.transitions.size)
      assert_equal(0, fibonacci2.transitions.size)
    end
  end
end
