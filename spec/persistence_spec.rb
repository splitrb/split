require "spec_helper"

describe Split::Persistence do

  subject { Split::Persistence }

  describe ".adapter" do
    context "when the persistence config is a symbol" do
      it "should return the appropriate adapter for the symbol" do
        Split.configuration.stub(:persistence).and_return(:redis)
        subject.adapter.should eq(Split::Persistence::RedisAdapter)
      end

      it "should return an adapter whose class is present in Split::Persistence::ADAPTERS" do
        Split.configuration.stub(:persistence).and_return(:redis)
        Split::Persistence::ADAPTERS.values.should include(subject.adapter)
      end

      it "should raise if the adapter cannot be found" do
        Split.configuration.stub(:persistence).and_return(:something_weird)
        expect { subject.adapter }.to raise_error
      end
    end
    context "when the persistence config is a class" do
      let(:custom_adapter_class) { MyCustomAdapterClass = Class.new }
      it "should return that class" do
        Split.configuration.stub(:persistence).and_return(custom_adapter_class)
        subject.adapter.should eq(MyCustomAdapterClass)
      end
    end
  end

end