# Repot

A small library for using RDF for persisting Ruby model objects. It's somewhat incomplete, since `RDF.rb` is not performative enough for my use case. However, for simple, metadata-based objects, this could be a nice persistence layer.

It does 90% of what [Spira](https://github.com/ruby-rdf/spira) does and more (e.g., file management via Carrierwave) in far fewer lines of code.

Use it like:

```ruby
class Video

include Repot::Resource
   
property :title, :predicate => RDF::DC.title
     
# Can have multiple values for a field
property :subjects, :predicate => RDF::DC.subject, :multiple => true

# Define associations (has_many or has_one)
has_one :interview, {
  :predicate => RDF::URI('info:repository/has-interview'), 
  :via => Interview
}

# Also provides "nested" pseudo-embedded-style associations for convenience
has_many_nested :locations, :predicate => RDF::DC.spatial do
  property :value, :predicate => RDF.value
  property :latitude, :predicate => 'info:repository/latitude', :datatype => RDF::XSD.float
  property :longitude, :predicate => 'info:repository/longitude', :datatype => RDF::XSD.float
end
```

It also plays nicely with Tire. 


