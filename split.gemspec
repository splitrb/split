# -*- encoding: utf-8 -*-
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

  s.required_ruby_version = '>= 1.9.2'

  s.rubyforge_project = "split"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency 'redis',           '>= 2.1'
  s.add_dependency 'sinatra',         '>= 1.2.6'
  s.add_dependency 'simple-random',   '>= 0.9.3'

  s.add_development_dependency 'bundler',     '~> 1.10'
  s.add_development_dependency 'simplecov',   '~> 0.12'
  s.add_development_dependency 'rack-test',   '~> 0.6'
  s.add_development_dependency 'rake',        '~> 11.1'
  s.add_development_dependency 'rspec',       '~> 3.4'
  s.add_development_dependency 'pry',         '~> 0.10'
  s.add_development_dependency 'fakeredis',   '~> 0.6.0'
end
