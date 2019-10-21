# -*- encoding: utf-8 -*-
# frozen_string_literal: true
$:.push File.expand_path("../lib", __FILE__)
require "split/version"

Gem::Specification.new do |s|
  s.name        = "split"
  s.version     = Split::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Andrew Nesbitt"]
  s.licenses    = ['MIT']
  s.email       = ["andrewnez@gmail.com"]
  s.homepage    = "https://github.com/splitrb/split"
  s.summary     = "Rack based split testing framework"

  s.metadata    = {
   "homepage_uri" => "https://github.com/splitrb/split",
   "changelog_uri" => "https://github.com/splitrb/split/blob/master/CHANGELOG.md",
   "source_code_uri" => "https://github.com/splitrb/split",
   "bug_tracker_uri" => "https://github.com/splitrb/split/issues",
   "wiki_uri" => "https://github.com/splitrb/split/wiki",
   "mailing_list_uri" => "https://groups.google.com/d/forum/split-ruby"
 }

  s.required_ruby_version = '>= 1.9.3'
  s.required_rubygems_version = '>= 2.0.0'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency 'redis',           '>= 2.1'
  s.add_dependency 'sinatra',         '>= 1.2.6'
  s.add_dependency 'simple-random',   '>= 0.9.3'

  s.add_development_dependency 'bundler',     '>= 1.17'
  s.add_development_dependency 'simplecov',   '~> 0.15'
  s.add_development_dependency 'rack-test',   '~> 0.6'
  s.add_development_dependency 'rake',        '~> 12'
  s.add_development_dependency 'rspec',       '~> 3.7'
  s.add_development_dependency 'pry',         '~> 0.10'
  s.add_development_dependency 'fakeredis',   '~> 0.7'
  s.add_development_dependency 'rails',       '>= 4.2'
end
