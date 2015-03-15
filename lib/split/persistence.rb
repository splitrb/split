%w[session_adapter cookie_adapter redis_adapter].each do |f|
  require "split/persistence/#{f}"
end

module Split
  module Persistence
    ADAPTERS = {
      :cookie => Split::Persistence::CookieAdapter,
      :session => Split::Persistence::SessionAdapter
    }.freeze

    def self.adapter
      if persistence_config.is_a?(Symbol)
        ADAPTERS.fetch(persistence_config) { raise Split::InvalidPersistenceAdapterError }
      else
        persistence_config
      end
    end

    def self.persistence_config
      Split.configuration.persistence
    end
    private_class_method :persistence_config
  end
end
