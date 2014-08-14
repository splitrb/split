require "spec_helper"

describe Split::Persistence do

  subject { Split::Persistence }

  describe ".adapter" do
    context "when the persistence config is a symbol" do
      it "should return the appropriate adapter for the symbol" do
        expect(Split.configuration).to receive(:persistence).twice.and_return(:cookie)
        expect(subject.adapter).to eq(Split::Persistence::CookieAdapter)
      end

      it "should return an adapter whose class is present in Split::Persistence::ADAPTERS" do
        expect(Split.configuration).to receive(:persistence).twice.and_return(:cookie)
        expect(Split::Persistence::ADAPTERS.values).to include(subject.adapter)
      end

      it "should raise if the adapter cannot be found" do
        expect(Split.configuration).to receive(:persistence).twice.and_return(:something_weird)
        expect { subject.adapter }.to raise_error
      end
    end
    context "when the persistence config is a class" do
      let(:custom_adapter_class) { MyCustomAdapterClass = Class.new }
      it "should return that class" do
        expect(Split.configuration).to receive(:persistence).twice.and_return(custom_adapter_class)
        expect(subject.adapter).to eq(MyCustomAdapterClass)
      end
    end
  end

end
