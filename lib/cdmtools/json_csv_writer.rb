require 'cdmtools'

module Cdmtools
  class JsonCsvWriter

    def initialize(json, filepath)
      CSV.open(filepath, "wb") do |csv|
        csv << json[0].keys

        json.each { |hash| csv << hash.values }
      end    
    end 
  end #JsonCsvWriter
end #Cdmtools
