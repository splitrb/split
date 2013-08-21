require "spec_helper"

describe Split::Persistence::RedisAdapter do

  let(:context) { nil }

  subject { Split::Persistence::RedisAdapter.new(context) }

  describe "#[] and #[]=" do
    it "should set and return the value for given key" do
      subject["my_key"] = "my_value"
      subject["my_key"].should eq("my_value")
    end
  end

  describe "#delete" do
    it "should delete the given key" do
      subject["my_key"] = "my_value"
      subject.delete("my_key")
      subject["my_key"].should be_nil
    end
  end

  describe "#keys" do
    it "should return an array of the user's stored keys" do
      subject["my_key"] = "my_value"
      subject["my_second_key"] = "my_second_value"
      subject.keys.should =~ ["my_key", "my_second_key"]
    end
  end

end
