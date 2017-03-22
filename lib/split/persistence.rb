# frozen_string_literal: true

module Split
  module Persistence
    require 'split/persistence/cookie_adapter'
    require 'split/persistence/dual_adapter'
    require 'split/persistence/redis_adapter'
    require 'split/persistence/session_adapter'

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
