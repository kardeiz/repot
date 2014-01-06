module Repot
  class FileHandler < CarrierWave::Uploader::Base
        
    include CarrierWave::MimeTypes
    
    storage :file
    process :set_content_type
    
    def root
      Repot.config.file_root || ::File.expand_path('../../..', __FILE__)
    end
    
    def store_dir
      ::File.join(root, 'files', model.id)
    end
    
    def cache_dir
      ::File.join(store_dir, 'cache')
    end
    
  end
end
