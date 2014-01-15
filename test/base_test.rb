require 'test_helper'
require 'repot'
require 'tire'
# require 'video'

describe Repot do
 
  before do
    Repot.config.file_root = File.expand_path('..', __FILE__)    
   
#    class AssoTest
#      include Repot::Resource
#      
#      property :title, :predicate => RDF::DC.title
#    end
   
    class Tester
      include Repot::Resource      
      include Tire::Model::Search
      include Tire::Model::Callbacks
      
      before_save do
        self.slug = default_slug if slug.nil?
      end
      
      types << default_type
      
      property :title, :predicate => RDF::DC.title
      property :subjects, {
        :predicate => RDF::DC.subject, :multiple => true
      }
      property :date, :predicate => RDF::DC.date, :datatype => RDF::XSD.dateTime
      # has_many :asso_tests, :via => AssoTest, :predicate => 'info:repository/try'
      property :slug, :predicate => 'info:repository/slug'
      
      def default_slug(counter = nil, prop = title.parameterize)
        slug = counter ? "#{prop}-#{counter}" : prop
        pattern = [:s, RDF::URI('info:repository/slug'), slug]
        if Repot.sparql_client.ask.whether(pattern).true?
          default_slug(counter ? counter.next : '2')
        else slug end
      end

    end
    
    @tester = Tester.new(:subjects => ['1', '2'], :title => 'Test title', :date => '2012-12-15')
#    @tester2 = Tester.new(:title => 'Test title')
#    @tester3 = Tester.new(:title => 'Test title')
  end
 
  after do
    Tester.index.delete
  end
 
  it "type test" do
  
    @tester.save
    a = Tester.search(:query => @tester.slug, :fields => [:slug]).first
    puts a.to_hash
#    puts @tester.as_indexed_json
#    @tester.save
##    puts @tester.as_indexed_json
#    a = Tester.find @tester.uri
#    puts a.as_indexed_json
#    
#    puts a.attributes
    
#    @tester2.save
#    @tester3.save
#    
#    puts Tester.where(:title => 'Test title', :slug => 'test-title-2').first.attributes
    
    #puts Dir.pwd
    #@file.save
    #puts @file.as_indexed_json
    
    #r = VideoFile.find @file.uri
    #puts r.as_indexed_json
    #@file.save
#    @tester.save
#    puts @tester.attributes
##    puts @tester.as_indexed_json
##    query = Repot.repository.query(:subject => RDF::URI(@tester.uri))
##    #puts query.dump(:rdfxml)
##    res = JSON.parse(query.dump(:jsonld, :context => Tester.context))
##    res2 = Tester.iterate_over_properties(res) do |o, v|
##      v.find(o)
##    end
##    puts res2
#    r = Tester.find @tester.uri
#    puts "\n\n"
#    puts r.attributes
#    # puts @tester.as_rdf_full.dump(:rdfxml)
  end
 
end
