# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "multivariate/version"

Gem::Specification.new do |s|
  s.name        = "multivariate"
  s.version     = Multivariate::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Andrew Nesbitt"]
  s.email       = ["andrewnez@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Rack based multivariate testing framework}

  s.rubyforge_project = "multivariate"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency(%q<redis>, ["~>  2.1"])
  s.add_dependency(%q<redis-namespace>, ["~>  0.10.0"])
  s.add_development_dependency(%q<rspec>, ["~>  2.6"])
end
