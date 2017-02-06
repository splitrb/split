# frozen_string_literal: true
require 'spec_helper'

describe Split::Persistence::RedisAdapter do
  let(:context) { double(lookup: 'blah') }

  subject { Split::Persistence::RedisAdapter.new(context) }

  describe '#redis_key' do
    before { Split::Persistence::RedisAdapter.reset_config! }

    context 'default' do
      it 'should raise error with prompt to set lookup_by' do
        expect { Split::Persistence::RedisAdapter.new(context) }.to raise_error(RuntimeError)
      end
    end

    context 'config with key' do
      before { Split::Persistence::RedisAdapter.reset_config! }
      subject { Split::Persistence::RedisAdapter.new(context, 'manual') }

      it 'should be "persistence:manual"' do
        expect(subject.redis_key).to eq('persistence:manual')
      end
    end

    context 'config with lookup_by = proc { "block" }' do
      before { Split::Persistence::RedisAdapter.with_config(lookup_by: proc { 'block' }) }

      it 'should be "persistence:block"' do
        expect(subject.redis_key).to eq('persistence:block')
      end
    end

    context 'config with lookup_by = proc { |context| context.test }' do
      before { Split::Persistence::RedisAdapter.with_config(lookup_by: proc { 'block' }) }
      let(:context) { double(test: 'block') }

      it 'should be "persistence:block"' do
        expect(subject.redis_key).to eq('persistence:block')
      end
    end

    context 'config with lookup_by = "method_name"' do
      before { Split::Persistence::RedisAdapter.with_config(lookup_by: 'method_name') }
      let(:context) { double(method_name: 'val') }

      it 'should be "persistence:bar"' do
        expect(subject.redis_key).to eq('persistence:val')
      end
    end

    context 'config with namespace and lookup_by' do
      before { Split::Persistence::RedisAdapter.with_config(lookup_by: proc { 'frag' }, namespace: 'persistence') }

      it 'should be "persistence"' do
        expect(subject.redis_key).to eq('persistence:frag')
      end
    end
  end

  context 'functional tests' do
    before { Split::Persistence::RedisAdapter.with_config(lookup_by: 'lookup') }

    describe '#[] and #[]=' do
      it 'should set and return the value for given key' do
        subject['my_key'] = 'my_value'
        expect(subject['my_key']).to eq('my_value')
      end
    end

    describe 'multi_get' do
      it 'should return the values for given keys' do
        subject['key_one'] = 'ein'
        subject['key_two'] = 'zwei'
        subject['key_three'] = 'drei'
        expect(subject.multi_get('key_one', 'key_two', 'key_three')).to eq(%w(ein zwei drei))
      end
    end

    describe '#delete' do
      it 'should delete the given key' do
        subject['my_key'] = 'my_value'
        subject.delete('my_key')
        expect(subject['my_key']).to be_nil
      end
    end

    describe '#keys' do
      it "should return an array of the user's stored keys" do
        subject['my_key'] = 'my_value'
        subject['my_second_key'] = 'my_second_value'
        expect(subject.keys).to match(%w(my_key my_second_key))
      end
    end
  end
end
