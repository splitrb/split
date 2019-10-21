# frozen_string_literal: true

require 'spec_helper'

describe Split::Persistence::DualAdapter do
  let(:context) { 'some context' }

  let(:logged_in_adapter_instance) { double }
  let(:logged_in_adapter) do
    Class.new.tap { |c| allow(c).to receive(:new) { logged_in_adapter_instance } }
  end
  let(:logged_out_adapter_instance) { double }
  let(:logged_out_adapter) do
    Class.new.tap { |c| allow(c).to receive(:new) { logged_out_adapter_instance } }
  end

  context 'when fallback_to_logged_out_adapter is false' do
    context 'when logged in' do
      subject do
        described_class.with_config(
          logged_in: lambda { |context| true },
          logged_in_adapter: logged_in_adapter,
          logged_out_adapter: logged_out_adapter,
          fallback_to_logged_out_adapter: false
        ).new(context)
      end

      it '#[]=' do
        expect(logged_in_adapter_instance).to receive(:[]=).with('my_key', 'my_value')
        expect_any_instance_of(logged_out_adapter).not_to receive(:[]=)
        subject['my_key'] = 'my_value'
      end

      it '#[]' do
        expect(logged_in_adapter_instance).to receive(:[]).with('my_key') { 'my_value' }
        expect_any_instance_of(logged_out_adapter).not_to receive(:[])
        expect(subject['my_key']).to eq('my_value')
      end

      it '#delete' do
        expect(logged_in_adapter_instance).to receive(:delete).with('my_key') { 'my_value' }
        expect_any_instance_of(logged_out_adapter).not_to receive(:delete)
        expect(subject.delete('my_key')).to eq('my_value')
      end

      it '#keys' do
        expect(logged_in_adapter_instance).to receive(:keys) { ['my_value'] }
        expect_any_instance_of(logged_out_adapter).not_to receive(:keys)
        expect(subject.keys).to eq(['my_value'])
      end
    end

    context 'when logged out' do
      subject do
        described_class.with_config(
          logged_in: lambda { |context| false },
          logged_in_adapter: logged_in_adapter,
          logged_out_adapter: logged_out_adapter,
          fallback_to_logged_out_adapter: false
        ).new(context)
      end

      it '#[]=' do
        expect_any_instance_of(logged_in_adapter).not_to receive(:[]=)
        expect(logged_out_adapter_instance).to receive(:[]=).with('my_key', 'my_value')
        subject['my_key'] = 'my_value'
      end

      it '#[]' do
        expect_any_instance_of(logged_in_adapter).not_to receive(:[])
        expect(logged_out_adapter_instance).to receive(:[]).with('my_key') { 'my_value' }
        expect(subject['my_key']).to eq('my_value')
      end

      it '#delete' do
        expect_any_instance_of(logged_in_adapter).not_to receive(:delete)
        expect(logged_out_adapter_instance).to receive(:delete).with('my_key') { 'my_value' }
        expect(subject.delete('my_key')).to eq('my_value')
      end

      it '#keys' do
        expect_any_instance_of(logged_in_adapter).not_to receive(:keys)
        expect(logged_out_adapter_instance).to receive(:keys) { ['my_value', 'my_value2'] }
        expect(subject.keys).to eq(['my_value', 'my_value2'])
      end
    end
  end

  context 'when fallback_to_logged_out_adapter is true' do
    context 'when logged in' do
      subject do
        described_class.with_config(
          logged_in: lambda { |context| true },
          logged_in_adapter: logged_in_adapter,
          logged_out_adapter: logged_out_adapter,
          fallback_to_logged_out_adapter: true
        ).new(context)
      end

      it '#[]=' do
        expect(logged_in_adapter_instance).to receive(:[]=).with('my_key', 'my_value')
        expect(logged_out_adapter_instance).to receive(:[]=).with('my_key', 'my_value')
        expect(logged_out_adapter_instance).to receive(:[]).with('my_key') { nil }
        subject['my_key'] = 'my_value'
      end

      it '#[]' do
        expect(logged_in_adapter_instance).to receive(:[]).with('my_key') { 'my_value' }
        expect_any_instance_of(logged_out_adapter).not_to receive(:[])
        expect(subject['my_key']).to eq('my_value')
      end

      it '#delete' do
        expect(logged_in_adapter_instance).to receive(:delete).with('my_key') { 'my_value' }
        expect(logged_out_adapter_instance).to receive(:delete).with('my_key') { 'my_value' }
        expect(subject.delete('my_key')).to eq('my_value')
      end

      it '#keys' do
        expect(logged_in_adapter_instance).to receive(:keys) { ['my_value'] }
        expect(logged_out_adapter_instance).to receive(:keys) { ['my_value', 'my_value2'] }
        expect(subject.keys).to eq(['my_value', 'my_value2'])
      end
    end

    context 'when logged out' do
      subject do
        described_class.with_config(
          logged_in: lambda { |context| false },
          logged_in_adapter: logged_in_adapter,
          logged_out_adapter: logged_out_adapter,
          fallback_to_logged_out_adapter: true
        ).new(context)
      end

      it '#[]=' do
        expect_any_instance_of(logged_in_adapter).not_to receive(:[]=)
        expect(logged_out_adapter_instance).to receive(:[]=).with('my_key', 'my_value')
        expect(logged_out_adapter_instance).to receive(:[]).with('my_key') { nil }
        subject['my_key'] = 'my_value'
      end

      it '#[]' do
        expect_any_instance_of(logged_in_adapter).not_to receive(:[])
        expect(logged_out_adapter_instance).to receive(:[]).with('my_key') { 'my_value' }
        expect(subject['my_key']).to eq('my_value')
      end

      it '#delete' do
        expect(logged_in_adapter_instance).to receive(:delete).with('my_key') { 'my_value' }
        expect(logged_out_adapter_instance).to receive(:delete).with('my_key') { 'my_value' }
        expect(subject.delete('my_key')).to eq('my_value')
      end

      it '#keys' do
        expect(logged_in_adapter_instance).to receive(:keys) { ['my_value'] }
        expect(logged_out_adapter_instance).to receive(:keys) { ['my_value', 'my_value2'] }
        expect(subject.keys).to eq(['my_value', 'my_value2'])
      end
    end
  end

  describe 'when errors in config' do
    before { described_class.config.clear }
    let(:some_proc) { ->{} }

    it 'when no logged in adapter' do
      expect{
        described_class.with_config(
          logged_in: some_proc,
          logged_out_adapter: logged_out_adapter
        ).new(context)
      }.to raise_error(StandardError, /:logged_in_adapter/)
    end

    it 'when no logged out adapter' do
      expect{
        described_class.with_config(
          logged_in: some_proc,
          logged_in_adapter: logged_in_adapter
        ).new(context)
      }.to raise_error(StandardError, /:logged_out_adapter/)
    end

    it 'when no logged in detector' do
      expect{
        described_class.with_config(
          logged_in_adapter: logged_in_adapter,
          logged_out_adapter: logged_out_adapter
        ).new(context)
      }.to raise_error(StandardError, /:logged_in$/)
    end
  end
end
