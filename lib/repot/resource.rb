module Repot
  module Resource
    extend ActiveSupport::Concern
    
    class AttributeWrapper
    
      def initialize(attribute)
        @attribute = attribute
      end
      
      def is_collection?
        Virtus::Attribute::Collection === @attribute
      end
      
      def is_association?
        klass <= Repot::Resource
      end
      
      def name; @attribute.name; end
      
      def predicate
        @attribute.options[:predicate].to_s
      end
      
      def klass
        @klass ||= if is_collection?
          @attribute.member_type.primitive
        else
          @attribute.type.primitive
        end
      end
      
      def datatype
        case
        when klass <= String      then RDF::XSD.string.to_s
        when klass <= Integer     then RDF::XSD.integer.to_s
        when klass <= DateTime    then RDF::XSD.dateTime.to_s
        when klass <= Repot::Resource then '@id'
        end
      end
      
      def container
        is_collection? ? {'@container' => '@set'} : {}
      end
    
      def context
        { '@id' => predicate, '@type' => datatype }.merge(container)
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

      attribute :id, String, :default => :default_id, :predicate => RDF::DC.identifier
      
    end

    module ClassMethods
    
      def type(setter = nil)
        setter ? types << setter : types.first
      end
      
      def types; @types ||= []; end 
      
      def base_uri(setter = nil)
        setter ? @base_uri = setter : (@base_uri ||= nil)
      end
    
      def default_type
        @default_type ||= "info:repository/#{self.name.tableize.singularize}"
      end
      
      def attribute(name, type = nil, options = {})
        assert_valid_name(name)
        Attribute.build(type, options.merge(:name => name)).tap do |o|
          attribute_set << o
          define_attribute_method name
          define_method "#{name}=" do |val|
            self.send("#{name}_will_change!") unless val == self.send(name)
            super(val)
          end if o.public_writer?
        end
        self
      end
            
      def public_attribute_set
        attribute_set.select(&:public_reader?)
      end
      
      def public_attribute_set_wrapped
        public_attribute_set.map{|x| AttributeWrapper.new(x) }
      end
      
      def context        
        public_attribute_set_wrapped.each_with_object({}) do |attribute, acc|
          acc[attribute.name.to_s] = attribute.context
        end
      end      
      
      def iterate_over_attribute_set(object, &block)
        public_attribute_set_wrapped.each_with_object({}) do |attribute, acc|
          val = object.__send__(attribute.name)
          acc[attribute.name] = if attribute.is_association? && !val.blank?
            if attribute.is_collection?
              val.map{|x| yield x, attribute }
            else yield val, attribute end
          else val end
        end
      end      
        
    end    
    
    def iterate_over_attributes(&block)
      self.class.iterate_over_attribute_set(self, &block)
    end
    
    def default_id
      RDF::URI("urn:uuid:#{SecureRandom.uuid}").to_s
    end
    
    def as_indexed_json
      iterate_over_attribute_set do |o, _|
        o.as_indexed_json
      end
    end
    
    def json_ld_header
      { 
        '@context' => self.class.context, '@id' => self.id
      }.merge(self.class.type ? { '@type' => self.class.types } : {})
    end
    
    def as_json_ld_lite
      iterate_over_attribute_set do |o, _|
        o.id
      end.stringify_keys.merge(json_ld_header)
    end
    
    def as_json_ld_full
      iterate_over_attribute_set do |o, _|
        o.as_json_ld_full
      end.stringify_keys.merge(json_ld_header)
    end
   
    def as_rdf_lite
      JSON::LD::API.toRdf(self.as_json_ld_lite)
    end   
    
    def as_rdf_full
      JSON::LD::API.toRdf(self.as_json_ld_full)
    end 
   
    
  end
end
