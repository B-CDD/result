# frozen_string_literal: true

require 'test_helper'

class BCDD::Result
  class Context::CallableAndThenResultFromDifferentSourcesTest < Minitest::Test
    include BCDDResultTransitionAssertions

    # rubocop:disable Naming/MethodParameterName
    class Root
      include Context.mixin

      CallC = ->(b:, **) do
        BCDD::Result.transitions(name: 'CallC') do
          Context::Success(:c, c: b + 1)
        end
      end

      CallE = ->(d:, **) do
        BCDD::Result.transitions(name: 'CallE') do
          Context::Success(:e, e: d + 1)
        end
      end

      def call(a:)
        BCDD::Result.transitions(name: 'Root') do
          Given(a: a)
            .and_then(:call_b, b: 2)
            .and_then!(CallC)
            .and_then!(self, _call: :call_d)
            .and_then!(CallE, f: 5)
            .and_then!(self, _call: :call_g, h: 7)
            .and_expose(:everything, %i[a b c d e f g h])
        end
      end

      def call_b(b:, **)
        Success(:b, b: b)
      end

      def call_d(c:, **)
        Success(:d, d: c + 1)
      end

      def call_g(f:, **)
        Success(:g, g: f + 1)
      end
    end
    # rubocop:enable Naming/MethodParameterName

    test 'the data accumulation' do
      root_process = Root.new

      result = root_process.call(a: 1)

      assert(result.success?(:everything))

      assert_equal(
        { a: 1, b: 2, c: 3, d: 4, e: 5, f: 5, g: 6, h: 7 },
        result.value
      )

      assert_transitions(result, size: 7)

      root = { id: 0, name: 'Root', desc: nil }

      {
        root: root,
        parent: root,
        current: root,
        result: { kind: :success, type: :given, value: { a: 1 } }
      }.then { assert_transition_record(result, 0, _1) }

      {
        root: root,
        parent: root,
        current: root,
        result: { kind: :success, type: :b, value: { b: 2 } },
        and_then: { type: :method, arg: { b: 2 }, source: root_process, method_name: :call_b }
      }.then { assert_transition_record(result, 1, _1) }

      {
        root: root,
        parent: root,
        current: { id: 1, name: 'CallC', desc: nil },
        result: { kind: :success, type: :c, value: { c: 3 } }
      }.then { assert_transition_record(result, 2, _1) }

      {
        root: root,
        parent: root,
        current: root,
        result: { kind: :success, type: :d, value: { d: 4 } },
        and_then: { type: :method, arg: -> { _1.is_a?(Hash) && _1.empty? }, source: root_process, method_name: :call_d }
      }.then { assert_transition_record(result, 3, _1) }

      {
        root: root,
        parent: root,
        current: { id: 2, name: 'CallE', desc: nil },
        result: { kind: :success, type: :e, value: { e: 5 } }
      }.then { assert_transition_record(result, 4, _1) }

      {
        root: root,
        parent: root,
        current: root,
        result: { kind: :success, type: :g, value: { g: 6 } },
        and_then: { type: :method, arg: { h: 7 }, source: root_process, method_name: :call_g }
      }.then { assert_transition_record(result, 5, _1) }

      {
        root: root,
        parent: root,
        current: root,
        result: { kind: :success, type: :everything, value: { a: 1, b: 2, c: 3, d: 4, e: 5, f: 5, g: 6, h: 7 } }
      }.then { assert_transition_record(result, 6, _1) }
    end
  end
end
