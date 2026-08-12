# frozen_string_literal: true

require "spec_helper"

describe Split::Cache do
  let(:namespace) { :test_namespace }
  let(:key) { :test_key }
  let(:now) { 1606189017 }

  before { allow(Time).to receive(:now).and_return(now) }

  describe "clear" do
    before do
      Split.configuration.cache = true
      # Disable global invalidation check for this test
      allow(Split::CacheInvalidator).to receive(:check_and_clear_if_needed)
    end

    it "clears the cache" do
      # First fetch: yield calls Time.now (x1)
      # Second fetch: yield calls Time.now (x1)
      expect(Time).to receive(:now).and_return(now).exactly(2).times
      Split::Cache.fetch(namespace, key) { Time.now }
      Split::Cache.clear
      Split::Cache.fetch(namespace, key) { Time.now }
    end
  end

  describe "clear_key" do
    before do
      Split.configuration.cache = true
      # Disable global invalidation check for this test
      allow(Split::CacheInvalidator).to receive(:check_and_clear_if_needed)
    end

    it "clears the cache" do
      # fetch :key1 (miss): yield (x1)
      # fetch :key2 (miss): yield (x1)
      # clear_key(:key1): no Time.now (invalidate is no-op without interval)
      # fetch :key1 (miss again, cleared): yield (x1)
      # fetch :key2 (cache hit): 0
      # Total: 3
      expect(Time).to receive(:now).and_return(now).exactly(3).times
      Split::Cache.fetch(namespace, :key1) { Time.now }
      Split::Cache.fetch(namespace, :key2) { Time.now }
      Split::Cache.clear_key(:key1)

      Split::Cache.fetch(namespace, :key1) { Time.now }
      Split::Cache.fetch(namespace, :key2) { Time.now }
    end

    it "updates global timestamp in Redis when invalidation is enabled" do
      Split.configuration.cache = true
      Split.configuration.cache_global_ts_check_interval = 5
      current_time = Time.now.to_f

      expect(Split.redis).to receive(:set).with("split:cache:global_ts", current_time)
      allow(Time).to receive(:now).and_return(Time.at(current_time))

      Split::Cache.clear_key(:some_key)
    end
  end

  describe "fetch" do
    subject { Split::Cache.fetch(namespace, key) { Time.now } }

    context "when cache disabled" do
      before { Split.configuration.cache = false }

      it "returns the yield" do
        expect(subject).to eql(now)
      end

      it "yields every time" do
        expect(Time).to receive(:now).and_return(now).exactly(2).times
        Split::Cache.fetch(namespace, key) { Time.now }
        Split::Cache.fetch(namespace, key) { Time.now }
      end
    end

    context "when cache enabled" do
      before do
        Split.configuration.cache = true
        # Disable global invalidation check for this test
        allow(Split::CacheInvalidator).to receive(:check_and_clear_if_needed)
      end

      it "returns the yield" do
        expect(subject).to eql(now)
      end

      it "yields once" do
        # First fetch: yield calls Time.now (x1)
        # Second fetch: cache hit, no yield (0)
        expect(Time).to receive(:now).and_return(now).exactly(1).times
        Split::Cache.fetch(namespace, key) { Time.now }
        Split::Cache.fetch(namespace, key) { Time.now }
      end

      it "honors namespace" do
        expect(Split::Cache.fetch(:a, key) { :a }).to eql(:a)
        expect(Split::Cache.fetch(:b, key) { :b }).to eql(:b)

        expect(Split::Cache.fetch(:a, key) { :a }).to eql(:a)
        expect(Split::Cache.fetch(:b, key) { :b }).to eql(:b)
      end

      it "honors key" do
        expect(Split::Cache.fetch(namespace, :a) { :a }).to eql(:a)
        expect(Split::Cache.fetch(namespace, :b) { :b }).to eql(:b)

        expect(Split::Cache.fetch(namespace, :a) { :a }).to eql(:a)
        expect(Split::Cache.fetch(namespace, :b) { :b }).to eql(:b)
      end
    end
  end

  describe "global timestamp invalidation" do
    before do
      Split.configuration.cache = true
      Split.configuration.cache_global_ts_check_interval = 5
      Split::Cache.clear
      Split::CacheInvalidator.reset
    end

    it "clears cache when global timestamp is updated" do
      # Mock Redis to return initial timestamp
      allow(Split.redis).to receive(:get).with("split:cache:global_ts").and_return("1000.0")

      # First fetch - should cache the value
      result1 = Split::Cache.fetch(namespace, key) { "value1" }
      expect(result1).to eq("value1")

      # Simulate another process updating the global timestamp
      allow(Split.redis).to receive(:get).with("split:cache:global_ts").and_return("2000.0")

      # Move time forward to bypass check interval
      allow(Time).to receive(:now).and_return(Time.at(now + 10))

      # Second fetch - should get new value because cache was cleared
      result2 = Split::Cache.fetch(namespace, key) { "value2" }
      expect(result2).to eq("value2")
    end

    it "does not check Redis within check interval" do
      allow(Split.redis).to receive(:get).with("split:cache:global_ts").and_return("1000.0")

      # First fetch - checks Redis
      Split::Cache.fetch(namespace, key) { "value1" }

      # Move time forward by 3 seconds (within interval)
      allow(Time).to receive(:now).and_return(Time.at(now + 3))

      # Second fetch - should NOT check Redis
      expect(Split.redis).not_to receive(:get).with("split:cache:global_ts")
      Split::Cache.fetch(namespace, key) { "value1" }
    end

    context "when cache_global_ts_check_interval is not configured" do
      before do
        Split.configuration.cache_global_ts_check_interval = nil
        Split::Cache.clear
        Split::CacheInvalidator.reset
      end

      it "does not read or write the global timestamp in Redis" do
        expect(Split.redis).not_to receive(:get).with("split:cache:global_ts")
        expect(Split.redis).not_to receive(:set).with("split:cache:global_ts", anything)

        Split::Cache.fetch(namespace, key) { "value1" }
        Split::Cache.clear_key(:some_key)
        Split::Cache.fetch(namespace, key) { "value2" }
      end
    end
  end
end
