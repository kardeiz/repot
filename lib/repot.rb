require "repot/version"

require 'carrierwave'
require 'carrierwave/validations/active_model'
require 'carrierwave/processing/mime_types'

require 'active_support' # /core_ext
require 'active_model'

require 'virtus'
require 'rdf'
require 'json/ld'


module Repot

  autoload :Resource,     'repot/resource'
  autoload :File,         'repot/file'
  autoload :FileHandler,  'repot/file_handler'

  def self.configure(&block); yield self.config; end

  def self.config; @config ||= OpenStruct.new; end

  def self.repository
    @repository ||= (self.config.repository || RDF::Repository.new)
  end
  
end
