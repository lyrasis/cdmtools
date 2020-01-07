require 'cdmtools'

module Cdmtools
  class RecordGetter
    attr_reader :coll
    attr_reader :pointer
    attr_reader :rec
    attr_reader :filename
    
    # initialized with a collection object and pointer
    def initialize(coll, pointer, force)
      @coll = coll
      @pointer = pointer
      @filename = "#{@coll.cdmrecdir}/#{pointer}.json"
      if File::exist?(@filename) && force == 'false'
        Cdmtools::LOG.debug("Record exists at #{@filename}. Will not retrieve from API and overwrite.")
      else
        @rec = get_record
        write_record if @rec
      end
    end

    private

    def get_record
      api = Cdmtools::CONFIG.api_base
      url = URI("#{api}dmGetItemInfo/#{@coll.alias}/#{@pointer}/json")
      result = Net::HTTP.get_response(url)
      if result.is_a?(Net::HTTPSuccess)
        Cdmtools::LOG.debug("Retrieved record for #{@coll.alias}/#{@pointer} from API")
        return JSON.parse(result.body)
      else
        Cdmtools::LOG.warn("Could not retrieve record for #{@coll.alias}/#{@pointer} from API")
        return nil
      end
      sleep Cdmtools::CONFIG.sleeptime
    end

    def write_record
      File.open(@filename, 'w'){ |f|
        f.write(@rec.to_json)
      }
      Cdmtools::LOG.debug("Wrote record to #{@filename}")
    end
    
  end
end #Cdmtools
