module Repot
  module Resource
    extend ActiveSupport::Concern
    
    included do
      extend ActiveModel::Callbacks
      extend ActiveModel::Naming
      include ActiveModel::Conversion
      include ActiveModel::Dirty
      include ActiveModel::Validations
      include ActiveModel::Serialization
      
      define_model_callbacks :save, :destroy, :create, :update
      
      before_save do
        self.id = default_id if id.blank?
        send_to_associations(:save)
      end
      
      property :id, {
        :predicate => RDF::DC.identifier
      }
      
    end    

    class Property
        
      attr_accessor :name, :predicate, :datatype, :multiple, :default
    
      def initialize(name, opts = {})
        @name = name
        [ :predicate, :datatype, :multiple, :coercer, :default ].each do |x|
          instance_variable_set("@#{x}", opts.fetch(x, nil))
        end
      end
    
      def coerce(input)
        if multiple
          Array.wrap(input).map { |x| coercer.call(x) }
        else coercer.call(input) end
      end
    
      def coercion_method
        case datatype.to_s
        when RDF::XSD.integer.to_s  then :to_i
        when RDF::XSD.dateTime.to_s then :to_datetime
        else :to_s end
      end
          
      def coercer
        @coercer ||= lambda do |input|
          input.send(coercion_method) if input
        end
      end
    
      def context
        @context ||= Hash.new.tap do |o|
          o['@id']        = predicate.to_s
          o['@type']      = datatype.to_s if datatype
          o['@container'] = '@set' if multiple
        end
      end    
    end

    class PropertySet
    
      include Enumerable
      
      def initialize(*properties)
        @index = Hash.new
        properties.each {|prop| self << prop }
      end
    
      def each(&block); @index.values.each(&block); end      
      def <<(property); @index[property.name] = property; end
      def [](key); @index[key]; end
      def keys; @index.keys; end      
      
      def context
        @context ||= each_with_object({}) do |property, acc|
          acc[property.name.to_s] = property.context
        end
      end
    end


    module ClassMethods
      
      def types; @types ||= []; end 
      def base_uri; @base_uri; end
      def base_uri=(val); @base_uri = val; end

      def associations; @associations ||= []; end
      def property_set; @property_set ||= PropertySet.new; end
    
      def context; property_set.context; end
    
      def default_type
        @default_type ||= "info:repository/#{self.name.tableize.singularize}"
      end
      
      def build(input); input.is_a?(String) ? find(input) : new(input); end
      
      def define_nested_class(klass, &block)
        class_eval "class #{klass}; include Repot::Resource; end"        
        self.const_get(klass).tap do |o|
          o.class_eval(&block) if block_given?
        end
      end
      
      def has_many_nested(name, opts, &block)
        klass = define_nested_class(name.to_s.classify, &block)
        has_many name, opts.merge(:via => klass)      
      end
      
      def has_one_nested(name, opts, &block)
        klass = define_nested_class(name.to_s.classify, &block)
        has_one name, opts.merge(:via => klass)      
      end
      
      def has_one(name, opts = {})
        klass = opts.delete(:via)
        property(name, opts.merge({
          :datatype => '@id', 
          :coercer  => lambda {|x| klass.build(x) }
        }))
        self.associations << name
      end
      
      def has_many(name, opts = {})
        klass = opts.delete(:via)
        property(name, opts.merge({
          :datatype => '@id', 
          :multiple => true,
          :coercer  => lambda {|x| klass.build(x) }
        }))
        self.associations << name
      end
      
      def property(name, opts = {})
        define_attribute_method name
        define_accessor_methods name
        property_set << Property.new(name, opts)
      end
      
      def define_accessor_methods(name)   
        define_method(name) { get(name) }
        define_method("#{name}=") { |val| set(name, val) }
      end
      
      def from_json_ld(object)
        self.new(object).tap { |o| o.changed_attributes.clear }
      end
      
      def find(uri)
        query = Repot.repository.query(:subject => RDF::URI(uri))
        res = JSON.parse(query.dump(:jsonld, :context => self.context))
        self.from_json_ld(res)
      end
      
    end    
    
    def property_set; self.class.property_set; end
    
    def get(name); instance_variable_get(:"@#{name}"); end
    
    def set(name, val)
      val = property_set[name].coerce(val)
      send("#{name}_will_change!") unless val == get(name)
      instance_variable_set(:"@#{name}", val)
    end
    
    alias_method :[],   :get
    alias_method :[]=,  :set
        
    def initialize(opts = {})
      set_default_values
      opts.each do |k,v|
        send("#{k}=", v) if respond_to?("#{k}=")
      end
    end
    
    def set_default_values
      property_set.each do |prop|
        val = send(prop.default) if prop.default
        set(prop.name, val)
      end
    end
    
    def iterate_over_associations(&block)
      self.class.associations.each_with_object({}) do |name, acc|
        next unless val = send(name)
        acc[name.to_s] = if val.respond_to?(:to_ary) 
          val.map{|x| yield x }
        else yield val end
      end
    end
    
    def send_to_associations(meth)
      iterate_over_associations {|o| o.send(meth) }
    end
    
    def as_indexed_json
      attributes.merge(send_to_associations(:as_indexed_json))
    end
    
    def to_indexed_json; as_indexed_json.to_json; end
    
    def json_ld_header
      Hash.new.tap do |o|
        o['@context'] = self.class.context
        o['@id'] = self.uri
        o['@type'] = self.class.types.map(&:to_s) unless self.class.types.empty?
      end
    end
    
    def as_json_ld_lite
      attributes.merge(send_to_associations(:uri)).merge(json_ld_header)
    end
    
    def as_json_ld_full
      attributes.merge(send_to_associations(:as_json_ld_full)).merge(json_ld_header)
    end
    
    def as_rdf_lite; JSON::LD::API.toRdf(self.as_json_ld_lite); end   
    
    def as_rdf_full; JSON::LD::API.toRdf(self.as_json_ld_full); end 
        
    def attributes
      property_set.keys.each_with_object({}) do |key, acc|
        acc[key.to_s] = send(key)
      end
    end
    
    def default_id; SecureRandom.uuid; end
    
    def uri; RDF::URI("urn:uuid:#{id}").to_s unless id.nil?; end
    
    def persist
      @previously_changed = changes
      changed_attributes.clear
      Repot.repository.insert(as_rdf_lite)
    end    
    
    def destroy
      run_callbacks :destroy do
        Repot.repository.delete(as_rdf_lite)
        self
      end    
    end
    
    def save
      run_callbacks :save do
        persist if changed?
        self
      end
    end
    
  end
end
