# frozen_string_literal: true
require "spec_helper"

describe Split::Persistence::DualAdapter do

  let(:context){ "some context" }

  let(:just_adapter){ Class.new }
  let(:selected_adapter_instance){ double }
  let(:selected_adapter){
    c = Class.new
    expect(c).to receive(:new){ selected_adapter_instance }
    c
  }
  let(:not_selected_adapter){
    c = Class.new
    expect(c).not_to receive(:new)
    c
  }

  shared_examples_for "forwarding calls" do
    it "#[]=" do
      expect(selected_adapter_instance).to receive(:[]=).with('my_key', 'my_value')
      expect_any_instance_of(not_selected_adapter).not_to receive(:[]=)
      subject["my_key"] = "my_value"
    end

    it "#[]" do
      expect(selected_adapter_instance).to receive(:[]).with('my_key'){'my_value'}
      expect_any_instance_of(not_selected_adapter).not_to receive(:[])
      expect(subject["my_key"]).to eq('my_value')
    end

    it "#delete" do
      expect(selected_adapter_instance).to receive(:delete).with('my_key'){'my_value'}
      expect_any_instance_of(not_selected_adapter).not_to receive(:delete)
      expect(subject.delete("my_key")).to eq('my_value')
    end

    it "#keys" do
      expect(selected_adapter_instance).to receive(:keys){'my_value'}
      expect_any_instance_of(not_selected_adapter).not_to receive(:keys)
      expect(subject.keys).to eq('my_value')
    end
  end

  context "when logged in" do
    subject {
      described_class.with_config(
        logged_in: lambda { |context| true },
        logged_in_adapter: selected_adapter,
        logged_out_adapter: not_selected_adapter
        ).new(context)
    }

    it_should_behave_like "forwarding calls"
  end

  context "when not logged in" do
    subject {
      described_class.with_config(
        logged_in: lambda { |context| false },
        logged_in_adapter: not_selected_adapter,
        logged_out_adapter: selected_adapter
        ).new(context)
    }

    it_should_behave_like "forwarding calls"
  end

  describe "when errors in config" do
    before{
      described_class.config.clear
    }
    let(:some_proc){ ->{} }
    it "when no logged in adapter" do
      expect{
        described_class.with_config(
          logged_in: some_proc,
          logged_out_adapter: just_adapter
          ).new(context)
      }.to raise_error(StandardError, /:logged_in_adapter/)
    end
    it "when no logged out adapter" do
      expect{
        described_class.with_config(
          logged_in: some_proc,
          logged_in_adapter: just_adapter
          ).new(context)
      }.to raise_error(StandardError, /:logged_out_adapter/)
    end
    it "when no logged in detector" do
      expect{
        described_class.with_config(
          logged_in_adapter: just_adapter,
          logged_out_adapter: just_adapter
          ).new(context)
      }.to raise_error(StandardError, /:logged_in$/)
    end
  end

end
