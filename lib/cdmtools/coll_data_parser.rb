require 'cdmtools'

module Cdmtools
  class CollDataParser
    attr_reader :colldata # the array of collection data hashes
    attr_reader :colls # array of coll aliases

    def initialize(coll_list)
      colljson = "#{Cdmtools::WRKDIR}/colls.json"
      Cdmtools::CollDataGetter.new unless File::exist?(colljson)
      if coll_list.empty?
        @colldata = JSON.parse(File.read(colljson))
      else
        @colldata = []
        coll_list.each{ |c| @colldata << { 'alias' => c } }
      end
      
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
