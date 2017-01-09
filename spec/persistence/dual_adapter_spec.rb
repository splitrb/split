# frozen_string_literal: true
require 'spec_helper'

describe Split::Persistence::DualAdapter do
  let(:context) { 'some context' }

  let(:just_adapter) { Class.new }
  let(:selected_adapter_instance) { double }
  let(:selected_adapter) do
    c = Class.new
    expect(c).to receive(:new) { selected_adapter_instance }
    c
  end
  let(:not_selected_adapter) do
    c = Class.new
    expect(c).not_to receive(:new)
    c
  end

  shared_examples_for 'forwarding calls' do
    it '#[]=' do
      expect(selected_adapter_instance).to receive(:[]=).with('my_key', 'my_value')
      expect_any_instance_of(not_selected_adapter).not_to receive(:[]=)
      subject['my_key'] = 'my_value'
    end

    it '#[]' do
      expect(selected_adapter_instance).to receive(:[]).with('my_key') { 'my_value' }
      expect_any_instance_of(not_selected_adapter).not_to receive(:[])
      expect(subject['my_key']).to eq('my_value')
    end

    it 'multi_get' do
      expect(selected_adapter_instance).to receive(:multi_get).with('my_key') { ['my_value'] }
      expect_any_instance_of(not_selected_adapter).not_to receive(:multi_get)
      expect(subject.multi_get('my_key')).to eq(['my_value'])
    end

    it '#delete' do
      expect(selected_adapter_instance).to receive(:delete).with('my_key') { 'my_value' }
      expect_any_instance_of(not_selected_adapter).not_to receive(:delete)
      expect(subject.delete('my_key')).to eq('my_value')
    end

    it '#keys' do
      expect(selected_adapter_instance).to receive(:keys) { 'my_value' }
      expect_any_instance_of(not_selected_adapter).not_to receive(:keys)
      expect(subject.keys).to eq('my_value')
    end
  end

  context 'when logged in' do
    subject do
      described_class.with_config(
        logged_in: -> (_context) { true },
        logged_in_adapter: selected_adapter,
        logged_out_adapter: not_selected_adapter
      ).new(context)
    end

    it_should_behave_like 'forwarding calls'
  end

  context 'when not logged in' do
    subject do
      described_class.with_config(
        logged_in: -> (_context) { false },
        logged_in_adapter: not_selected_adapter,
        logged_out_adapter: selected_adapter
      ).new(context)
    end

    it_should_behave_like 'forwarding calls'
  end

  describe 'when errors in config' do
    before do
      described_class.config.clear
    end
    let(:some_proc) { -> {} }
    it 'when no logged in adapter' do
      expect do
        described_class.with_config(
          logged_in: some_proc,
          logged_out_adapter: just_adapter
        ).new(context)
      end.to raise_error(StandardError, /:logged_in_adapter/)
    end
    it 'when no logged out adapter' do
      expect do
        described_class.with_config(
          logged_in: some_proc,
          logged_in_adapter: just_adapter
        ).new(context)
      end.to raise_error(StandardError, /:logged_out_adapter/)
    end
    it 'when no logged in detector' do
      expect do
        described_class.with_config(
          logged_in_adapter: just_adapter,
          logged_out_adapter: just_adapter
        ).new(context)
      end.to raise_error(StandardError, /:logged_in$/)
    end
  end
end
