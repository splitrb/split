# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rubocop", require: false
gem "codeclimate-test-reporter"
gem "concurrent-ruby", "< 1.3.9"
# json 3.0 dropped the quirks_mode option that ActiveSupport 7.2.3.x still passes
gem "json", "< 3"

gem "rails", "~> #{ENV.fetch('RAILS_VERSION', '8.0')}"
