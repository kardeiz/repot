require 'test_helper'
require 'repot'
require 'video'

describe Repot do
 
  before do
    Repot.config.file_root = File.expand_path('..', __FILE__)    
    @video = Video.new(:title => 'This is your test object.')
    
#    class Book
#      include Repot::Resource
#      configure :base_uri => default_base_uri, :type => default_type
#      property :title, :type => String, :predicate => RDF::DC.title
#    end
#    
#    class FileObject
#      include Repot::File
#      configure :type => default_type, :base_uri => default_base_uri
#      before_save :set_info_attributes
#      property :checksum, {
#        :predicate => RDF::URI('info:repository/checksum'), :type => String
#      }
#      property :content_type, {
#        :predicate => RDF::URI('info:repository/content-type'), :type => String
#      }
#      def set_info_attributes
#        if file.present?
#          set_content_type; set_checksum
#        end
#      end      
#      def set_content_type
#        return unless self.content_type.blank?
#        self.content_type = file.file.content_type
#      end      
#      def set_checksum
#        return unless contents = file.file.read || self.checksum.blank?
#        self.checksum = Digest::MD5.hexdigest(contents)
#      end      
#    end
#    
#    @book = Book.new(:title => 'test')   
#    @file_object = FileObject.new 
  end
 
  it "type test" do
    @video.save
    @video2 = Video.new(:title => 'This is your test object.')
    puts @video.as_json_ld_lite
    puts @video2.as_json_ld_lite
  end
  
#  it "empty base uri" do
#    @tester.class.base_uri.must_be_nil
#  end
# 
#  it "must have default id" do
#    # @tester.default_id.must_match /^urn:uuid:/
#    #puts @tester.class.context
#  end
# 
#  it "must do as_indexed_json" do
#    # puts @tester.as_rdf_full.dump(:rdfxml)
#    @tester.save
#    puts @tester.as_rdf_lite.dump(:rdfxml)
#    puts Repot.repository.dump(:rdfxml)
#  end
 
  
 
#  it "must be defined" do
#    Repot::VERSION.wont_be_nil
#  end
#  
#  it "Book must be an instance of its class" do
#    @book.must_be_instance_of Book
#  end 
#  
#  it "must inherit from resource" do
#    Book.must_be(:<=, Repot::Resource)
#  end
#  
#  it "File must be instance of class" do
#    @file_object.file = File.open('test/test_file.txt')
#    @file_object.must_be_instance_of FileObject
#    @file_object.save
#    puts @file_object.as_indexed_json
#  end
  
end
