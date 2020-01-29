require 'cdmtools'

module Cdmtools
  class MigrecFinalizer
    attr_reader :coll
    
    def initialize(coll)
      @coll = coll
      @coll.migrecs.each{ |recname|
        filepath = "#{@coll.migrecdir}/#{recname}"
        Cdmtools::Migrecord.new(@coll, filepath).finalize
      }
    end

  end 
end #Cdmtools
