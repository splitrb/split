require "spec_helper"

describe Split::Persistence::SessionAdapter do

  let(:context) { double(:session => {}) }
  subject { Split::Persistence::SessionAdapter.new(context) }

  describe "#[] and #[]=" do
    it "should set and return the value for given key" do
      subject["my_key"] = "my_value"
      expect(subject["my_key"]).to eq("my_value")
    end
  end

  describe "#delete" do
    it "should delete the given key" do
      subject["my_key"] = "my_value"
      subject.delete("my_key")
      expect(subject["my_key"]).to be_nil
    end
  end

  describe "#keys" do
    it "should return an array of the session's stored keys" do
      subject["my_key"] = "my_value"
      subject["my_second_key"] = "my_second_value"
      expect(subject.keys).to match(["my_key", "my_second_key"])
    end
  end

end
