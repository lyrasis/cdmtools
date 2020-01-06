require 'cdmtools'

module Cdmtools
  class CdmFieldGetter
    attr_reader :fielddata # hash of field data. key = collalias, val = json for dmGetCollectionFieldInfo

    def initialize(colls)
      @fielddata = {}
      colls.each{ |coll| get_coll_fields(coll.alias, Cdmtools::CONFIG.api_base) }
      if @fielddata.length == 0
        Cdmtools::LOG.warn("No field data was retrieved. Will not write any files.")
      else
        write_json
        write_csv(colls.first.alias)
      end
    end

    private

    def get_coll_fields(collalias, api)
      url = URI("#{api}dmGetCollectionFieldInfo/#{collalias}/json")
      result = Net::HTTP.get_response(url)

      if result.is_a?(Net::HTTPSuccess)
        @fielddata[collalias] = JSON.parse(result.body)
        Cdmtools::LOG.info("CDM field info retrieved for #{collalias}")
      else
        Cdmtools::LOG.warn("No CDM field info retrieved for #{collalias}")
        puts "No CDM field info retrieved for #{collalias}"
      end
    end
    
    def write_csv(first_coll)
      filename = "#{Cdmtools::WRKDIR}/fields.csv"
      flat_fields = []
      @fielddata.each do | collalias, arr |
        if collalias == first_coll
          flat_fields.unshift(['coll alias', arr.first.keys].flatten)
        end
        
        arr.each do |hash|
          flat_fields << [collalias, hash.values].flatten
        end
      end

      CSV.open(filename, "wb") do |csv|
        flat_fields.each { |e| csv << e }
      end

      Cdmtools::LOG.info("Wrote field data to #{filename}")
    end
    
    def write_json
      filename = "#{Cdmtools::WRKDIR}/fields.json"
      File.open(filename, 'w'){ |f|
        f.write(@fielddata.to_json)
      }
      Cdmtools::LOG.info("Wrote field data to #{filename}")
    end

  end #CollDataGetter class
end #Cdmtools
