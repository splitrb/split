# frozen_string_literal: true
require 'spec_helper'

describe Split::Persistence::CookieAdapter do
  let(:context) { double(cookies: CookiesMock.new) }
  subject { Split::Persistence::CookieAdapter.new(context) }

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
    it "should return an array of the session's stored keys" do
      subject['my_key'] = 'my_value'
      subject['my_second_key'] = 'my_second_value'
      expect(subject.keys).to match(%w(my_key my_second_key))
    end
  end

  it 'handles invalid JSON' do
    context.cookies[:split] = { value: '{"foo":2,', expires: Time.now }
    expect(subject['my_key']).to be_nil
    subject['my_key'] = 'my_value'
    expect(subject['my_key']).to eq('my_value')
  end
end
