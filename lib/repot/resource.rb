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
      include ActiveModel::AttributeMethods
      
      define_model_callbacks :save, :destroy, :create, :update
      
      before_create { self.id = default_id }
      
      before_save { send_to_associations :save }
      
      property :id, :predicate => RDF::DC.identifier
      
    end    

    class Property

      attr_reader :multiple, :default   
    
      def initialize(name, opts = {})
        @name = name
        [ :predicate, :datatype, :multiple, :coercer, :default, :via ].each do |x|
          instance_variable_set("@#{x}", opts[x])
        end
      end
    
      def coerce(input)
        Array.wrap(input).map do |x|
          @via ? @via.build(x) : coerce_literal(x)
        end.tap { |o| return o.first unless @multiple }
      end
    
      def coerce_literal(val)
        case val
        when RDF::Literal then val.object
        else literal_object(val).object end
      end     
    
      def literal_object(obj)
        RDF::Literal.new(obj).tap { |o| o.datatype = @datatype if @datatype }
      end
      
      def object(obj); @via ? obj.uri : literal_object(obj); end
      
      def rdf_statement(uri, obj)
        RDF::Statement.new(uri, predicate, object(obj))
      end
      
      def predicate; RDF::URI(@predicate); end
      
    end
    
    module ClassMethods
      
      def types; @types ||= []; end
      def type; types.first; end

      def associations; @associations ||= []; end
      def properties; @properties ||= HashWithIndifferentAccess.new; end
    
      def sparql; Repot.repository.client; end     
    
      def default_type
        @default_type ||= begin
          RDF::URI("info:repository/types/#{self.name.tableize.singularize}")
        end
      end
      
      def build(input)
        future do
          case input
          when self                 then input
          when String, RDF::URI     then find(input)
          when RDF::Enumerable      then build_from_rdf(input)
          when Hash                 then new(input)
          else new end
        end
      end
      
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
        property(name, opts)
        self.associations << name
      end
      
      def has_many(name, opts = {})
        property(name, opts.merge(:multiple => true))
        self.associations << name
      end
      
      def property(name, opts = {})
        define_attribute_method name
        define_accessor_methods name
        properties[name] = Property.new(name, opts)
      end
      
      def define_accessor_methods(name)   
        define_method(name) { get(name) }
        define_method("#{name}=") { |val| set(name, val) }
      end
      
      def build_from_rdf(sts)
        self.properties.each_with_object(self.new) do |(k,v), acc|
          vals = Array.wrap(sts[v.predicate]).map(&:object)
          acc.set(k, vals) unless vals.empty?
        end.tap { |o| o.changed_attributes.clear }
      end
      
      def find(uri)    
        sts = Repot.repository.query(:subject => RDF::URI(uri)).group_by(&:predicate)
        sts.empty? ? nil : build_from_rdf(sts)
      end
      
      def build_from_rdf_multiple(sts)
        sts.group_by(&:subject).values.map do |o| 
          build_from_rdf(o.group_by(&:predicate))
        end
      end
      
      def all
        raise "Cannot find all without type definition" unless self.type
        query = RDF::Query.new.tap do |o|
          o << [:subject, :predicate, :object]
          o << [:subject, RDF.type, self.type]
        end
        build_from_rdf_multiple(Repot.repository.query(query))
      end
      
      def where(hash = {})
        raise "Cannot find all without type definition" unless self.type
        query = hash.each_with_object(RDF::Query.new) do |(k,v), acc|
          acc << [:subject, RDF::URI(properties[k].predicate), v]
        end.tap do |o|
          o << [:subject, RDF.type, self.type]
          o << [:subject, :predicate, :object]
        end
        build_from_rdf_multiple(Repot.repository.query(query))      
      end
      
    end
    
    def get(name); instance_variable_get(:"@#{name}"); end
    
    def set(name, val)
      val = self.class.properties[name].coerce(val)
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
      self.class.properties.each do |k, v|
        val = send(v.default) if v.default
        set(k, val)
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

    def type_statements
      self.class.types.map { |type| RDF::Statement.new(uri, RDF.type, type) }
    end
    
    def as_rdf_lite
      self.class.properties.each_with_object(RDF::Graph.new) do |(k,v), acc|
        next unless vals = get(k)
        Array.wrap(vals).each do |val|
          acc << v.rdf_statement(uri, val)
        end
      end.tap { |o| type_statements.each{ |s| o << s } }
    end
        
    def attributes
      self.class.properties.keys.each_with_object({}) do |key, acc|
        acc[key.to_s] = send(key)
      end
    end
    
    def default_id; SecureRandom.uuid; end
    
    def uri
      id ? RDF::URI("urn:uuid:#{id}") : RDF::Node.new
    end

    def update
      run_callbacks(:update) do
        graph = changes.each_with_object(RDF::Graph.new) do |(k,v), acc|
          prop = self.class.properties[k.to_sym]
          Repot.repository.delete([uri, prop.predicate, nil])
          Array.wrap(v.last).each { |val| acc << prop.rdf_statement(uri, val) }
        end
        Repot.repository.insert(graph)
      end
    end
    
    def create
      run_callbacks(:create) do 
        Repot.repository.insert(as_rdf_lite)
      end
    end

    def persist
      persisted? ? update : create
      @previously_changed = changes
      changed_attributes.clear
    end    
    
    def persisted?; !! id; end
    
    def destroy
      run_callbacks :destroy do
        Repot.repository.delete([uri, nil, nil])
        Repot.repository.delete([nil, nil, uri])
        self
      end    
    end
    
    def save
      run_callbacks :save do
        persist if changed?
        self
      end
    end
    
    def inspect
      "<#{self.class}:#{self.object_id} @uri: #{uri}>"
    end
    
  end
end
