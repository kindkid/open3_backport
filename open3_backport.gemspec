# -*- encoding: utf-8 -*-
$:.unshift File.expand_path('../lib', __FILE__)
require 'open3_backport/version'

Gem::Specification.new do |gem|
  gem.authors       = ["Chris Johnson"]
  gem.email         = ["chris@kindkid.com"]
  gem.description   = "Backport of new Open3 methods from Ruby 1.9 to Ruby 1.8"
  gem.summary       = gem.description
  gem.homepage      = "https://github.com/kindkid/open3_backport"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "open3_backport"
  gem.require_paths = ["lib"]
  gem.version       = Open3Backport::VERSION
  gem.add_dependency "open4", "~> 1.3.0"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec", "~> 2.11.0"
end
