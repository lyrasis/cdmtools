require 'cdmtools'

module Cdmtools
  class DcMappingGetter
    attr_reader :dcdata # the hash of collection data

    def initialize()
      get_dc_data      
    end

    private

    def get_dc_data
      api = Cdmtools::CONFIG.api_base
      url = URI("#{api}dmGetDublinCoreFieldInfo/json")
      result = Net::HTTP.get_response(url)
      if result.is_a?(Net::HTTPSuccess)
        @dcdata = JSON.parse(result.body)
        write_csv
        write_json
      else
        Cdmtools::LOG.warn("Could not retrieve DC mapping data from API.")
      end
    end

    def write_csv
      csvfile = "#{Cdmtools::WRKDIR}/dc_mapping.csv"
      Cdmtools::JsonCsvWriter.new(@dcdata, csvfile)
      Cdmtools::LOG.info("Wrote DC field data to #{csvfile}")
    end

    def write_json
      jsonfile = "#{Cdmtools::WRKDIR}/dc_mapping.json"
      File.open(jsonfile, 'w'){ |f|
        f.write(@dcdata.to_json)
      }
      Cdmtools::LOG.info("Wrote DC field data to #{jsonfile}")
    end
    
  end #DcMappingGetter class
end #Cdmtools
