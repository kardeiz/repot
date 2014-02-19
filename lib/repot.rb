require "repot/version"

require 'carrierwave'
require 'carrierwave/validations/active_model'
require 'carrierwave/processing/mime_types'

require 'active_support/all'
require 'active_model'

require 'virtus'
require 'rdf'
require 'rdf/rdfxml'
require 'sparql/client'
require 'nokogiri'
require 'json/ld'
require 'uuidtools'
# require 'promise'
require 'future'

module Repot

  autoload :Resource,     'repot/resource'
  autoload :File,         'repot/file'

  def self.configure(&block); yield self.config; end

  def self.config; @config ||= OpenStruct.new; end

  def self.repository
    @repository ||= (self.config.repository || SPARQL::Client::Repository.new)
  end 
  
end
