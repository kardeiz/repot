module Repot
  module Resource
    extend ActiveSupport::Concern

    module TypeMapper    
      def self.map(klass)
        case
        when klass <= String      then RDF::XSD.string.to_s
        when klass <= Integer     then RDF::XSD.integer.to_s
        when klass <= DateTime    then RDF::XSD.dateTime.to_s
        when klass <= Repot::Resource then '@id'
        end
      end    
    end

    included do
      extend ActiveModel::Callbacks
      extend ActiveModel::Naming
      include ActiveModel::Conversion
      include ActiveModel::Dirty
      include ActiveModel::Serializers::JSON
      include ActiveModel::Validations
      include Virtus.model
      
      define_model_callbacks :save, :destroy, :create, :update
      
      before_save do
        self.class.iterate_over_associations(hash_dup) { |o| o.save }
      end
      attribute :id, String, :default => :default_id
      
    end

    module ClassMethods
      
      def define_nested_class(klass, &block)
        class_eval "class #{klass}; include Repot::Resource; end"        
        self.const_get(klass).tap do |o|
          o.class_eval(&block) if block_given?
        end
      end
      
      def has_many_nested(name, opts, &block)
        klass = define_nested_class(name.to_s.classify, &block)
        has_many name, opts.merge(:type => klass)      
      end
      
      def has_one_nested(name, opts, &block)
        klass = define_nested_class(name.to_s.classify, &block)
        has_one name, opts.merge(:type => klass)      
      end
            
      def configure(options = {})
        @base_uri = options[:base_uri] if options[:base_uri]
        types.concat(Array(options[:type])) if options[:type]
      end
      
      def base_uri; @base_uri ||= nil; end
      def types; @types ||= []; end      
      def type; types.first; end
      
      def context        
        @context || properties.each_with_object({}) do |(k,v), acc|
          acc[k] = {
            '@id' => v[:predicate].to_s,
            '@type' => TypeMapper.map(v[:type])
          }.merge(v[:serialize] ? {'@container' => '@set'} : {})
        end
      end      
      
      def property(name, type, options = {})  
        define_attribute_method name
        attribute(name, type, options)
        define_method "#{name}=" do |val|
          self.send("#{name}_will_change!") unless val == self.send(name)
          super(val)
        end
      end
      
      def iterate_over_attributes(hash = {}, &block)
        attribute_set.each_with_object(hash) do |a, obj|
          next if obj[a.name].nil?
          if Virtus::Attribute::Collection === a && a.member_type.primitive <= Repot::Resource
        end
      end
    
      def iterate_over_associations(hash = {}, &block)
        self.associations.each_with_object(hash) do |(k,v), acc|
          next unless r = acc[k]
          acc[k] = v[:serialize] ? r.map{ |o| yield(o, v) } : yield(r, v)
        end
      end
    
      def from_jsonld(hash)
        _hash = iterate_over_associations(hash) do |o, v|
          v[:type].find(get_id_from_uri(o))
        end
        self.new(_hash).tap do |o|
          o.changed_attributes.clear
          o.id = get_id_from_uri(hash['@id'])
        end
      end
    
      def with_defaults
        configure :base_uri => default_base_uri, :type => default_type
      end
    
      def default_type
        @default_type ||= "info:repository/#{self.name.tableize.singularize}"
      end
    
      def default_base_uri
        @default_base_uri ||= "info:repository/#{self.name.tableize}"
      end
    
      def uri_for(id)
        self.base_uri ? (RDF::URI(self.base_uri) / id) : RDF::Node(id)
      end
    
      def get_id_from_uri(uri)
        uri.match(/[#\/]([^#\/]*)$/) { |m| m[1] }
      end
    
      def find(id)
        query = Repot.repository.query(:subject => uri_for(id))
        res = JSON.parse(query.dump(:jsonld, :context => self.context))
        self.from_jsonld(res)
      end
    
    end
    
    def hash_dup
      self.class.properties.keys.each_with_object({}) do |k, acc|
        acc[k] = read_attribute_for_serialization(k)
      end
    end
    
    def as_indexed_json
      self.class.iterate_over_associations(hash_dup) do |o, v|
        o.as_indexed_json
      end
    end
    
    def as_jsonld_full
      hash = hash_dup.merge(jsonld_header)
      self.class.iterate_over_associations(hash) do |o, v|
        o.as_jsonld_full
      end
    end
    
    def as_jsonld_lite
      hash = hash_dup.merge(jsonld_header)
      self.class.iterate_over_associations(hash) do |o, v|
        o.uri
      end
    end 
    
    def jsonld_header
      { 
        '@context' => self.class.context, '@id' => self.uri.to_s
      }.merge(self.class.type ? {'@type' => self.class.type} : {})
    end
    
    def to_rdf_lite
      JSON::LD::API.toRdf(self.as_jsonld_lite)
    end   
    
    def to_rdf_full
      JSON::LD::API.toRdf(self.as_jsonld_full)
    end 
    
    def save
      run_callbacks :save do
        self.tap do |o|
          if o.changed?
            @previously_changed = o.changes
            o.changed_attributes.clear
            Repot.repository << o.to_rdf_lite
          end
        end
      end
    end
    
    def uri; @uri ||= self.class.uri_for(id); end
    
    def default_id; RDF::Node.new.id; end
    
    def assign_attributes(hash = {})
      self.attributes.merge!(hash)
    end
    
  end
end
