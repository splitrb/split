require "spec_helper"

describe Split::Persistence::RedisAdapter do

  let(:context) { nil }

  subject { Split::Persistence::RedisAdapter.new(context) }

  describe '#redis_key' do
    before { Split::Persistence::RedisAdapter.reset_config! }

    context 'default' do
      it 'should be "persistence"' do
        subject.redis_key.should == 'persistence'
      end
    end

    context 'config with namespace' do
      before { Split::Persistence::RedisAdapter.with_config(:namespace => 'namer') }

      it 'should be "namer"' do
        subject.redis_key.should == 'namer'
      end
    end

    context 'config with lookup_by = "method_name"' do
      before { Split::Persistence::RedisAdapter.with_config(:lookup_by => 'method_name') }
      let(:context) { double(:method_name => 'val') }

      it 'should be "persistence:bar"' do
        subject.redis_key.should == 'persistence:val'
      end
    end

    context 'config with lookup_by = proc { "block" }' do
      before { Split::Persistence::RedisAdapter.with_config(:lookup_by => proc{'block'}) }

      it 'should be "persistence:block"' do
        subject.redis_key.should == 'persistence:block'
      end
    end
  end

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
