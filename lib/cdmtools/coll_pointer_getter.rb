require 'cdmtools'

module Cdmtools
  class CollPointerGetter
    attr_reader :coll

    # initialized with a Cdmtools::Collection object
    def initialize(coll)
      @coll = coll
      pointerfile = "#{@coll.colldir}/_pointers.txt"
      if File::exists?(pointerfile)
        Cdmtools::LOG.info("Pointer file already exists for collection: #{@coll.alias}. Not pulling new list.")
      else
        write_pointers(pointerfile)
      end
      clean_pointers(pointerfile)
    end

    private

    #uses cdminspect to write pointer list
    def write_pointers(pointerfile)
      cdmi = Cdmtools::CONFIG.cdminspect
      api = Cdmtools::CONFIG.api_base

      Cdmtools::LOG.info("Starting to get pointers for collection: #{@coll.alias}")
      system "cd #{cdmi} ; php cdminspect --inspect=pointers --cdm_url=#{api} --output_file=#{pointerfile} --alias=#{@coll.alias}"
      Cdmtools::LOG.info("Finished getting pointers for collection: #{@coll.alias}")
    end

    def clean_pointers(pointerfile)
      keeplines = []
      File.readlines(pointerfile).each{ |ln|
        if ln['cdminspect']
          next
        else
          keeplines << ln
          end
      }

      File.open(pointerfile, 'w'){ |f|
        keeplines.each{ |ln| f.write(ln) }
      }
    end
    
  end
end #Cdmtools
