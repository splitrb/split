# frozen_string_literal: true

require "redis-client"

module SplitRedisCallInstrumentation
  KEY = :split_redis_call_count

  def call(command, config)
    SplitRedisCallInstrumentation.increment
    super
  end

  def call_pipelined(commands, config)
    SplitRedisCallInstrumentation.increment
    super
  end

  class << self
    def count
      previous = Thread.current[KEY]
      Thread.current[KEY] = 0
      yield
      Thread.current[KEY]
    ensure
      Thread.current[KEY] = previous
    end

    def increment
      count = Thread.current[KEY]
      Thread.current[KEY] = count + 1 if count
    end
  end
end

RedisClient.register(SplitRedisCallInstrumentation)

RSpec::Matchers.define :make_redis_calls do |expected|
  supports_block_expectations

  match do |block|
    @actual = SplitRedisCallInstrumentation.count(&block)
    values_match?(expected, @actual)
  end

  failure_message do
    "expected block to make #{description_of(expected)} Redis roundtrip(s), but made #{@actual}"
  end

  failure_message_when_negated do
    "expected block not to make #{description_of(expected)} Redis roundtrip(s), but it did (#{@actual})"
  end

  description do
    "make #{description_of(expected)} Redis roundtrip(s)"
  end
end
