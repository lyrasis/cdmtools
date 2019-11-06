require 'cdmtools'

module Cdmtools
  class CollDataParser
    attr_reader :colldata # the hash of collection data
    attr_reader :colls # array of coll aliases

    def initialize()
      colljson = "#{Cdmtools::WRKDIR}/colls.json"
      Cdmtools::CollDataGetter.new unless File::exist?(colljson)
      @colldata = JSON.parse(File.read(colljson))
      @colls = []
      @colldata.each{ |h| colls << Cdmtools::Collection.new(h) }
      return @colls
    end

    def aliases
      a = []
      @colls.each{ |coll| a << coll.alias }
      return a
    end

  end #CollDataGetter class
end #Cdmtools
