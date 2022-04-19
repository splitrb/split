# frozen_string_literal: true

require "spec_helper"

describe Split::Cache do
  let(:namespace) { :test_namespace }
  let(:key) { :test_key }
  let(:now) { 1606189017 }

  before { allow(Time).to receive(:now).and_return(now) }

  describe "clear" do
    before { Split.configuration.cache = true }

    it "clears the cache" do
      expect(Time).to receive(:now).and_return(now).exactly(2).times
      Split::Cache.fetch(namespace, key) { Time.now }
      Split::Cache.clear
      Split::Cache.fetch(namespace, key) { Time.now }
    end
  end

  describe "clear_key" do
    before { Split.configuration.cache = true }

    it "clears the cache" do
      expect(Time).to receive(:now).and_return(now).exactly(3).times
      Split::Cache.fetch(namespace, :key1) { Time.now }
      Split::Cache.fetch(namespace, :key2) { Time.now }
      Split::Cache.clear_key(:key1)

      Split::Cache.fetch(namespace, :key1) { Time.now }
      Split::Cache.fetch(namespace, :key2) { Time.now }
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
      before { Split.configuration.cache = true }

      it "returns the yield" do
        expect(subject).to eql(now)
      end

      it "yields once" do
        expect(Time).to receive(:now).and_return(now).once
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
end
