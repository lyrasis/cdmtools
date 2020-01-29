require 'cdmtools'

module Cdmtools
  class Record
    attr_reader :coll # Collection to which record belongs
    attr_reader :json # the record as a JSON-derived hash
    attr_reader :fields # array of fields present in record
    attr_reader :id

    # initialize with Cdmtools::Collection object and path to record file
    def initialize(coll, path)
      @coll = coll
      @path = path
      @json = JSON.parse(File.read(path))
      @fields = @json.keys
      @id = @json['dmrecord']
      self
    end

    def write_record
      File.open(@path, 'w'){ |f|
        f.write(@json.to_json)
      }
    end
  end #Record

  class Migrecord < Record
    def initialize(coll, path)
      super
    end

    def finalize
      set_filetype
      set_external_media
      set_islandora_content_model
      write_record
    end

    def set_islandora_content_model
      case @json['migobjlevel']
      when 'top'
        case @json['migobjcategory']
        when 'simple'
          icm = content_model(@json['migfiletype'].downcase)
        when 'external media'
          icm = 'sp_basic_image'
        when 'compound'
          case @json['migcompobjtype']
          when 'Document-PDF'
            if @json['cdmprintpdf'] == '1'
              icm = 'sp_pdf'
            end
          when 'Document'
            icm = 'bookCModel'
          when 'Postcard'
            icm = 'compoundCModel'
          when 'Picture Cube'
            icm = 'compoundCModel'
          end
        end
      
        if icm
          @json['islandora_content_model'] = icm
        else
          Cdmtools::LOG.warn("IS_CONTENT_MODEL: Cannot determine content model for #{@path}")
        end
      end
    end

    def content_model(file_ext)
      lookup = {
        'jp2' => 'sp_large_image_cmodel',
        'jpg' => 'sp_basic_image',
        'mov' => 'sp_videoCModel',
        'pdf' => 'sp_pdf',
        'tif' => 'sp_large_image_cmodel',
      }
      if lookup.has_key?(file_ext)
        return lookup[file_ext]
      else
        puts "Cannot determine Islandora content model for filetype: #{file_ext}"
      end
    end
    
    
    def set_filetype
      unless @json['migfiletype']
        rec_find = @json['find']
        if rec_find
          filetype = rec_find.sub(/.*?\./, '')
          @json['migfiletype'] = filetype
        else
          Cdmtools::LOG.error("Cannot determine file type for #{@path}")
        end
      end
    end

    def set_external_media
      if @json['migfiletype'] && @json['migfiletype'] == 'url'
        @json['migobjcategory'] = 'external media'
      end
    end

  end #Migrecord
  
end #Cdmtools
