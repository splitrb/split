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
  s.homepage    = "https://github.com/andrew/split"
  s.summary     = %q{Rack based split testing framework}

  s.rubyforge_project = "split"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency 'redis',           '>= 2.1'
  s.add_dependency 'redis-namespace', '>= 1.1.0'
  s.add_dependency 'sinatra',         '>= 1.2.6'
  s.add_dependency 'simple-random'
  s.add_dependency 'connection_pool'

  # Ruby 1.8 doesn't include JSON in the std lib
  if RUBY_VERSION < "1.9"
    s.add_dependency 'json',            '>= 1.7.7'
  end

  s.add_development_dependency 'rake'
  s.add_development_dependency 'bundler',     '~> 1.3'
  s.add_development_dependency 'rspec',       '~> 2.14'
  s.add_development_dependency 'rack-test',   '>= 0.5.7'
  s.add_development_dependency 'coveralls'
end
