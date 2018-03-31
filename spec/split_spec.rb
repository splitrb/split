# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Split do

  around(:each) do |ex|
    old_env, old_redis = [ENV.delete('REDIS_URL'), Split.redis]
    ex.run
    ENV['REDIS_URL'] = old_env
    Split.redis = old_redis
  end

  describe '#redis=' do
    it 'accepts a url string' do
      Split.redis = 'redis://localhost:6379'
      expect(Split.redis).to be_a(Redis)

      client = Split.redis.connection
      expect(client[:host]).to eq("localhost")
      expect(client[:port]).to eq(6379)
    end

    it 'accepts an options hash' do
      Split.redis = {host: 'localhost', port: 6379, db: 12}
      expect(Split.redis).to be_a(Redis)

      client = Split.redis.connection
      expect(client[:host]).to eq("localhost")
      expect(client[:port]).to eq(6379)
      expect(client[:db]).to eq(12)
    end

    it 'accepts a valid Redis instance' do
      other_redis = Redis.new(url: "redis://localhost:6379")
      Split.redis = other_redis
      expect(Split.redis).to eq(other_redis)
    end

    it 'raises an ArgumentError when server cannot be determined' do
      expect { Split.redis = Object.new }.to raise_error(ArgumentError)
    end
  end
end
