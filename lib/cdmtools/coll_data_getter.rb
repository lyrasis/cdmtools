require 'cdmtools'

module Cdmtools
  class CollDataGetter
    attr_reader :colldata # the hash of collection data

    def initialize
      @config_colls = get_config_colls
      api = Cdmtools::CONFIG.api_base
      url = URI("#{api}dmGetCollectionList/json")
      result = Net::HTTP.get_response(url)
      if result.is_a?(Net::HTTPSuccess)
        @colldata = JSON.parse(result.body)
        Cdmtools::LOG.info('Retrieved coll data from API.')
      else
        Cdmtools::LOG.warn('Could not retrieve coll data from API.')
        puts 'Could not retrieve coll data from API.'
        exit
      end

      clean_aliases
      keep_config_colls
      write_csv
      write_json
      make_coll_directories
    end

    private

    def get_config_colls
      Cdmtools::CONFIG.colls.nil? ? [] : Cdmtools::CONFIG.colls
    end
    
    def keep_config_colls
      return @colldata if @config_colls.empty?
      return @colldata if @colldata.length == @config_colls.length
      keeping = @colldata.select{ |h| @config_colls.include?(h['alias']) }
      @colldata = keeping
    end
    
    def clean_aliases
      @colldata.each{ |h| h['alias'] = h['alias'].sub('/', '') }
    end
    
    def make_coll_directories
      @colldata.each{ |h|
        dirpath = "#{Cdmtools::WRKDIR}/#{h['alias']}"
        Dir::mkdir(dirpath) unless Dir::exist?(dirpath)
      }
    end
    
    def write_csv
      filename = "#{Cdmtools::WRKDIR}/colls.csv"
      Cdmtools::JsonCsvWriter.new(@colldata, filename)
      Cdmtools::LOG.info("Wrote coll data to #{filename}")
    end
    
    def write_json
      filename = "#{Cdmtools::WRKDIR}/colls.json"
      File.open(filename, 'w'){ |f|
        f.write(@colldata.to_json)
      }
      Cdmtools::LOG.info("Wrote coll data to #{filename}")
    end

  end #CollDataGetter class
end #Cdmtools
