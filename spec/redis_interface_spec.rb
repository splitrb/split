# frozen_string_literal: true

require "spec_helper"

describe Split::RedisInterface do
  let(:list_name) { "list_name" }
  let(:set_name) { "set_name" }
  let(:interface) { described_class.new }

  describe "#persist_list" do
    subject(:persist_list) do
      interface.persist_list(list_name, %w(a b c d))
    end

    specify do
      expect(persist_list).to eq %w(a b c d)
      expect(Split.redis.lindex(list_name, 0)).to eq "a"
      expect(Split.redis.lindex(list_name, 1)).to eq "b"
      expect(Split.redis.lindex(list_name, 2)).to eq "c"
      expect(Split.redis.lindex(list_name, 3)).to eq "d"
      expect(Split.redis.llen(list_name)).to eq 4
    end

    context "list is overwritten but not deleted" do
      specify do
        expect(persist_list).to eq %w(a b c d)
        interface.persist_list(list_name, ["z"])
        expect(Split.redis.lindex(list_name, 0)).to eq "z"
        expect(Split.redis.llen(list_name)).to eq 1
      end
    end
  end

  describe "#add_to_set" do
    subject(:add_to_set) do
      interface.add_to_set(set_name, "something")
    end

    specify do
      add_to_set
      expect(Split.redis.sismember(set_name, "something")).to be true
    end
  end
end
