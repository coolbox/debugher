# -*- encoding: utf-8 -*-
require File.expand_path('../lib/debugher/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Peter Roome"]
  gem.email         = ["pete@wearepandr.com"]
  gem.description   = %q{
                          A handy set of methods for getting various bits of information about a web page.
                          This is used by the Rakkit Debugger to output what information we can gather about various pages on an adhoc basis.
                          The library is also used by the Rakkit spider to process and index pages across the web.
                        }
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "debugher"
  gem.require_paths = ["lib"]
  gem.version       = Debugher::VERSION

  gem.add_dependency "sinatra"
  gem.add_dependency 'nokogiri'
  gem.add_dependency "addressable"
  gem.add_dependency 'robots'

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rack-test"
  gem.add_development_dependency "simplecov"
end