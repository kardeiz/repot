class Video

  include Repot::Resource
  
  type default_type
  
  property :slug, String, :predicate => RDF::URI('info:repository/slug')      
  property :title, String, :predicate => RDF::DC.title
  
  def self.next_slug(slug)
    counter = slug.match(/\d+$/) {|m| m.to_s } || '0'
    pattern = [ :s, RDF::URI('info:repository/slug'), slug ]
    puts Repot.sparql_client.ask.whether(pattern).true?; slug
#    if Repot.sparql_client.ask.whether(pattern).true?
#      puts 'what'; puts counter
#      next_slug(slug + "-#{counter}")
#    else slug; puts 'what'; puts counter; end
  end
  
  before_save do
    self.slug = self.class.next_slug(self.title.parameterize)
  end

end
