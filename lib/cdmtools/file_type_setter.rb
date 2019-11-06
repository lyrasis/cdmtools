require 'cdmtools'

module Cdmtools
  class FileTypeSetter
    attr_reader :coll
    
    def initialize(coll)
      @coll = coll
      @coll.migrecs.each{ |recname|
        filename = "#{@coll.migrecdir}/#{recname}"
        rec = JSON.parse(File.read(filename))
        unless rec['migfiletype']
          rec_find = rec['find']
          if rec_find
            filetype = rec_find.sub(/.*?\./, '')
            rec['migfiletype'] = filetype

            File.open(filename, 'w'){ |f|
              f.write(rec.to_json)
            }
          else
            Cdmtools::LOG.error("Cannot determine file type for #{filename}")
            next
          end
        end
      }
    end

  end 
end #Cdmtools
