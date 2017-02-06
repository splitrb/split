%w[session_adapter cookie_adapter redis_adapter].each do |f|
  require "split/persistence/#{f}"
end

module Split
  module Persistence
    ADAPTERS = {
      :redis => Split::Persistence::RedisAdapter
    }

    def self.adapter
      if persistence_config.is_a?(Symbol)
        adapter_class = ADAPTERS[persistence_config]
        raise Split::InvalidPersistenceAdapterError unless adapter_class
      else
        adapter_class = persistence_config
      end
      adapter_class
    end

    private

    def self.persistence_config
      Split.configuration.persistence
    end
  end
end
