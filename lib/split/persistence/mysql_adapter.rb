# frozen_string_literal: true
module Split
  module Persistence
    class MysqlAdapter
      DEFAULT_CONFIG = {:namespace => 'persistence'}.freeze

      attr_reader :account_id

      def initialize(context, acc_id = nil)
       # Split::Persistence.adapter.new(nil, 347381).test_create_or_update('exp123:1', 'control')
        if acc_id
          @account_id = acc_id
        elsif lookup_by = self.class.config[:lookup_by]
          if lookup_by.respond_to?(:call)
            key_frag = lookup_by.call(context)
          else
            key_frag = context.send(lookup_by)
          end
          @account_id = key_frag
        else
          raise "Please configure lookup_by"
        end
      end

      #--------------

      def test_get(property)
        search_for_record(property)
      end

      def test_create_or_update(property, value)
        record = Manage::ExperimentPersistence.where(
          experiment_id: experiment_id_parser(property),
          account_id: account_id,
          property: property
        ).first_or_initialize
        record.update!(value: value);
      end

      #-------------

      def [](property)
        search_for_record(property)
      end

      def []=(property, value)
        record = Manage::ExperimentPersistence.where(
          experiment_id: experiment_id_parser(property),
          account_id: account_id,
          property: property
        ).first_or_initialize
        record.update!(value: value);
      end

      def delete(field)
        record_to_delete = search_for_record(property)
        record_to_delete.destroy!
      end

      # --------

      def keys
        Split.redis.hkeys(redis_key)
      end

      def self.with_config(options={})
        self.config.merge!(options)
        self
      end

      def self.config
        @config ||= DEFAULT_CONFIG.dup
      end

      def self.reset_config!
        @config = DEFAULT_CONFIG.dup
      end

      def experiment_id_parser(property)
        property.split(":").first
      end

      def search_for_record(property)
        Manage::ExperimentPersistence.find_by(experiment_id: experiment_id_parser(property), property: property, account_id: account_id)
      end


    end
  end
end
