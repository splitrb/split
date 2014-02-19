require 'spec_helper'
require 'split/counter'

describe Split::Counter do
  describe 'basic use' do
    it "should create a counter upon using it, if it does not exist" do
      Split::Counter.inc('co', 'exp1', 'alt1')
      Split::Counter.current_value('co', 'exp1', 'alt1').should eq("1")
    end

    it "should create a counter directly upon using it, if it does not exist" do
      Split::Counter.inc('co','exp1', 'alt1')
      Split::Counter.current_value('co', 'exp1', 'alt1').should eq("1")
      Split::Counter.exists?('co').should eq(true)
    end

    it "should be possible to delete a counter" do
      Split::Counter.inc('co','exp1', 'alt1')
      Split::Counter.exists?('co').should eq(true)
      Split::Counter.delete('co')
      Split::Counter.exists?('co').should eq(false)
    end

    it "should be possible to reset a counter" do
      Split::Counter.inc('co','exp1', 'alt1')
      Split::Counter.current_value('co', 'exp1', 'alt1').should eq("1")
      Split::Counter.reset('co', 'exp1', 'alt1')
      Split::Counter.inc('co','exp1', 'alt1')
      Split::Counter.current_value('co', 'exp1', 'alt1').should eq("1")
    end

    it "should be possible to get all experiments and hashs counter values" do
      Split::Counter.inc('co', 'exp1', 'alt1')
      Split::Counter.inc('co', 'exp1', 'alt2')
      Split::Counter.inc('co', 'exp1', 'alt2')
      Split::Counter.inc('co', 'exp2', 'alt1')
      # {"exp1"=>{"alt1"=>1, "alt2"=>2}, "exp2"=>{"alt1"=>1}}
      Split::Counter.all_values_hash('co').length.should eq(2)
      Split::Counter.all_values_hash('co')['exp1'].length.should eq(2)
      Split::Counter.all_values_hash('co')['exp2'].length.should eq(1)
    end

    it "should be possible to get a list of all counters" do
      Split::Counter.inc('co', 'exp1', 'alt1')
      Split::Counter.inc('co2','exp2', 'alt1')
      Split::Counter.all_counter_names.length.should eq(2)
    end
  end
end
