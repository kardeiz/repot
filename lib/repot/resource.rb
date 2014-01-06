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
        when klass <= Integer     then RDF::XSD.integer.to_s
        when klass <= DateTime    then RDF::XSD.dateTime.to_s
        when klass <= Repot::Resource then '@id'
        end
      end
    
      def context
        Hash.new.tap do |o| 
          o['@id']        = predicate
          o['@type']      = datatype if datatype
          o['@container'] = '@set' if is_collection?
        end
      end
    
    end
    

    included do
      extend ActiveModel::Callbacks
      extend ActiveModel::Naming
      include ActiveModel::Conversion
      include ActiveModel::Dirty
      include ActiveModel::Validations
      include Virtus.model
      
      define_model_callbacks :save, :destroy, :create, :update

      property :id, String, {
        :default => :default_id, :predicate => RDF::DC.identifier
      }
      
      before_save do
        iterate_over_attributes { |o, _| o.save }
      end
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
      
      def property(name, type = nil, options = {})
        assert_valid_name(name)
        define_attribute_method name
        Virtus::Attribute.build(type, options.merge(:name => name)).tap do |o|
          attribute_set << o
          define_method "#{name}=" do |val|
            send("#{name}_will_change!") unless val == send(name)
            super(val)
          end if o.public_writer?
        end
        self
      end
            
      def public_attribute_set
        attribute_set.select(&:public_reader?).map{|x| AttributeWrapper.new(x) }
      end
      
      def association_attribute_set
        public_attribute_set.select(&:is_association?)
      end
      
      def context        
        public_attribute_set.each_with_object({}) do |attribute, acc|
          acc[attribute.name.to_s] = attribute.context
        end
      end      
      
      def iterate_over_attribute_set(object, &block)
        association_attribute_set.each_with_object(object) do |attribute, acc|
          next unless (val = acc[attribute.name]) && !val.blank?
          acc[attribute.name] = if attribute.is_collection?
            val.map{|x| yield x, attribute }
          else yield val, attribute end
        end
      end      
      
      def from_jsonld(object)
        hash = iterate_over_attribute_set(object.symbolize_keys) do |o, v|
          v.klass.find(o)
        end
        self.new(hash).tap do |o|
          o.changed_attributes.clear
        end
      end
      
      def find(uri)
        query = Repot.repository.query(:subject => RDF::URI(uri))
        res = JSON.parse(query.dump(:jsonld, :context => self.context))
        self.from_jsonld(res)
      end
      
    end    
    
    def iterate_over_attributes(&block)
      self.class.iterate_over_attribute_set(attributes, &block)
    end
    
    def default_id
      SecureRandom.uuid
    end
    
    def uri
      RDF::URI("urn:uuid:#{id}").to_s
    end
    
    def as_indexed_json
      iterate_over_attributes do |o, _|
        o.as_indexed_json
      end
    end
    
    def json_ld_header
      { 
        '@context' => self.class.context, '@id' => self.uri
      }.merge(self.class.type ? { '@type' => self.class.types } : {})
    end
    
    def as_json_ld_lite
      iterate_over_attributes do |o, _|
        o.uri
      end.stringify_keys.merge(json_ld_header)
    end
    
    def as_json_ld_full
      iterate_over_attributes do |o, _|
        o.as_json_ld_full
      end.stringify_keys.merge(json_ld_header)
    end
   
    def as_rdf_lite
      JSON::LD::API.toRdf(self.as_json_ld_lite)
    end   
    
    def as_rdf_full
      JSON::LD::API.toRdf(self.as_json_ld_full)
    end 
   
    def save
      run_callbacks :save do
        self.tap do |o|
          if o.changed?
            @previously_changed = o.changes
            o.changed_attributes.clear
            Repot.repository << o.as_rdf_lite
          end
        end
      end
    end
    
  end
end
