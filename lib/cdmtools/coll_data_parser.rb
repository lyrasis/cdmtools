require 'cdmtools'

module Cdmtools
  class CollDataParser
    attr_reader :colldata # the array of collection data hashes
    attr_reader :colls # array of collection objects

    
    def initialize(coll_list)
      colljson = "#{Cdmtools::WRKDIR}/colls.json"
      # Use CDM API call to get collections data if we haven't already
      Cdmtools::CollDataGetter.new unless File::exist?(colljson)
      if coll_list.empty?
        # if we haven't specified individual collections, we want them all
        @colldata = JSON.parse(File.read(colljson))
      else
        # otherwise, we create a stubby fake coll data hash with just the aliases
        #  we're dealing with now
        @colldata = []
        coll_list.each{ |c| @colldata << { 'alias' => c } }
      end

      # create a new collection object for each coll hash we've gathered
      @colls = []
      @colldata.each{ |h| @colls << Cdmtools::Collection.new(h) }
    end

    # returns an array of the collection aliases
    def aliases
      a = []
      @colls.each{ |coll| a << coll.alias }
      return a
    end

  end #CollDataGetter class
end #Cdmtools
