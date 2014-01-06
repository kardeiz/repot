# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'repot/version'

Gem::Specification.new do |spec|
  spec.name          = "repot"
  spec.version       = Repot::VERSION
  spec.authors       = ["Jacob Brown"]
  spec.email         = ["j.h.brown@tcu.edu"]
  spec.description   = %q{
    A lightweight modeling system based on Virtus and RDF.rb
  }.strip
  spec.summary       = spec.description
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib'] #  'test' 
  
  spec.add_runtime_dependency     'rdf', '1.1.0.1' #     '~> 1.1'       #  '1.0.10.2' #  
  spec.add_runtime_dependency     'sparql' #,         '~> 1.1'
  spec.add_runtime_dependency     'sparql-client' #,  '~> 1.1'
  spec.add_runtime_dependency     'uuidtools'
  spec.add_runtime_dependency     'rdf-rdfxml'
  spec.add_runtime_dependency     'nokogiri'
  spec.add_runtime_dependency     'activemodel',    '~> 3.1'
  spec.add_runtime_dependency     'activesupport',  '~> 3.1'
  spec.add_runtime_dependency     'virtus',         '~> 1.0'
  spec.add_runtime_dependency     'carrierwave'
  spec.add_runtime_dependency     'json-ld' #, '1.0.8.1'
  spec.add_runtime_dependency     'mime-types'
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
end
