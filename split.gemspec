# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "split/version"

Gem::Specification.new do |s|
  s.name        = "split"
  s.version     = Split::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Andrew Nesbitt"]
  s.email       = ["andrewnez@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Rack based split testing framework}

  s.rubyforge_project = "split"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency(%q<redis>, ["~>  2.1"])
  s.add_dependency(%q<redis-namespace>, ["~>  1.0.3"])
  s.add_dependency(%q<sinatra>, ["~>  1.2.6"])

  # Development Dependencies
  s.add_development_dependency(%q<rspec>, ["~>  2.6"])
end
