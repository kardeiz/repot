module Repot
  module File
    extend ActiveSupport::Concern
    
    included do
      include Resource
      
      mount_uploader :file, FileHandler, :mount_on => :file_name      
      property :file_name, {
        :predicate => RDF::URI('info:repository/file-name'), :type => String
      }
      def as_indexed_json
        super.merge('file_url' => self.file.url, 'file_path' => self.file.path)
      end 
      
    end
    
    module ClassMethods
      include CarrierWave::Mount

      def mount_uploader(column, uploader = nil, options = {}, &block)
        super        
        include CarrierWave::Validations::ActiveModel
        validates_integrity_of  column if uploader_option(column.to_sym, :validate_integrity)
        validates_processing_of column if uploader_option(column.to_sym, :validate_processing)

        after_save :"store_#{column}!"
        before_save :"write_#{column}_identifier"
        after_destroy :"remove_#{column}!"

        class_eval <<-RUBY, __FILE__, __LINE__+1
          
          def read_uploader(c); send(c); end          
          def write_uploader(c, id); send("\#{c}=", id); end 
          
          def _mounter(column)
            @_mounters ||= {}
            @_mounters[column] ||= CarrierWave::Mount::Mounter.new(self, column)
          end
          
          def #{column}=(new_file)
            send(:"#{column}_name_will_change!")
            _mounter(:#{column}).cache(new_file)
          end
          
          def remove_#{column}
            send(:"#{column}_name_will_change!")
            _mounter(:#{column}).remove
          end          
        RUBY
      end
    end
  end
end
