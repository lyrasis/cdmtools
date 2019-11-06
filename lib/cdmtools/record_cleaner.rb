require 'cdmtools'

module Cdmtools
  class RecordCleaner
    attr_reader :coll
    
    def initialize(coll)
      @coll = coll
      @coll.migrecs.each{ |recname|
        filename = "#{@coll.migrecdir}/#{recname}"
        rec = JSON.parse(File.read(filename))

        # convert empty hashes and arrays to empty strings
        get_empty_hash_or_array_fields(rec).each { |field|
          rec[field] = ''
        }

        # strip all string values
        rec.each{ |field, value| value.strip! if value.is_a?(String) }

        # delete empty fields
        get_empty_string_fields(rec).each { |field|
          rec.delete(field)
        }

        # delete \n in string values
        rec.each{ |field, value| value.gsub!(/\\n/, ' ') if value.is_a?(String) }

        # collapse spaces in string values
        rec.each{ |field, value| value.squeeze!(' ') if value.is_a?(String) }
        
        # write rec
        File.open(filename, 'w'){ |f|
          f.write(rec.to_json)
        }
      }
    end

    private

    def get_empty_hash_or_array_fields(rec)
      list = []
      rec.each{ |field, value| list << field if value == {} || value == [] }
      list
    end

    def get_empty_string_fields(rec)
      list = []
      rec.each{ |field, value| list << field if value == '' }
      list
    end
  end 
end #Cdmtools
