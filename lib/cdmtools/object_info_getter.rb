require 'cdmtools'

module Cdmtools
  class ObjectInfoGetter
    attr_reader :coll
    attr_reader :pointer
    attr_reader :objinfo
    attr_reader :filename
    
    # initialized with a collection object and pointer
    def initialize(coll, pointer)
      @coll = coll
      @pointer = pointer
      @filename = "#{@coll.cdmobjectinfodir}/#{pointer}.json"
      if File::exist?(@filename)
        Cdmtools::LOG.info("Object info exists at #{@filename}. Will not retrieve from API and overwrite.")
      else
        @objinfo = get_object_info
        write_object_info if @objinfo
      end
    end

    private

    def get_object_info
      api = Cdmtools::CONFIG.api_base
      url = URI("#{api}dmGetCompoundObjectInfo/#{@coll.alias}/#{@pointer}/json")
      result = Net::HTTP.get_response(url)
      if result.is_a?(Net::HTTPSuccess)
        oi = JSON.parse(result.body)
        if oi['message'] && oi['message']['is not compound']
          Cdmtools::LOG.info("#{@coll.alias}/#{@pointer} is a simple object")
          return nil
        else
          Cdmtools::LOG.info("Retrieved object info from API for #{@coll.alias}/#{@pointer}")
          return oi
        end
      else
        Cdmtools::LOG.warn("Could not retrieve object info for #{@coll.alias}/#{@pointer} from API")
        return nil
      end
      sleep Cdmtools::CONFIG.sleeptime
    end

    def write_object_info
      File.open(@filename, 'w'){ |f|
        f.write(@objinfo.to_json)
      }
      Cdmtools::LOG.info("Wrote object info to #{@filename}")
    end
    
  end
end #Cdmtools
