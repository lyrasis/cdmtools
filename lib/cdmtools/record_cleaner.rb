require 'cdmtools'
require 'pp'

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

        # delete \n and \t in string values
        rec.each{ |field, value| value.gsub!("\n", ' ') if value.is_a?(String) }
        rec.each{ |field, value| value.gsub!("\t", ' ') if value.is_a?(String) }

        subs = Cdmtools::CONFIG.replacements
        do_replacements(rec, subs) if subs.length > 0
      
        # collapse spaces in string values
        rec.each{ |field, value| value.squeeze!(' ') if value.is_a?(String) }
        
        # write rec
        File.open(filename, 'w'){ |f|
          f.write(rec.to_json)
        }
      }
    end

    private

    def do_replacements(rec, subs)
      subs.each{ |s|
        if s['colls'] == '' || s['colls'].include?(@coll.alias)
          rec.each{ |field, value|
            if s['fields'] == '' || s['fields'].include?(field)
              value.gsub!(s['find'], s['replace']) if s['type'] == 'plain'
              value.gsub!(/#{s['find']}/, s['replace']) if s['type'] == 'regexp'
            else
              next
            end
          }
        else
          next
        end
      }
    end
    
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
