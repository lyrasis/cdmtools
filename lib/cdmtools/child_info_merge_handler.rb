require 'cdmtools'

module Cdmtools
  class ChildInfoMergeHandler

    def initialize(coll)
      coll.objs_by_category['compound']['other'].each{ |compoundptr|
        Cdmtools::LOG.info("Getting children for compound object #{coll.alias}/#{compoundptr}...")
        parent_rec = JSON.parse(File.read("#{coll.migrecdir}/#{compoundptr}.json"))
        child_ptrs = parent_rec['migchildptrs']
        child_ptrs.each{ |ptr| ChildInfoMerger.new(coll, compoundptr, ptr) }
      }
    end

  end #CollDataGetter class
end #Cdmtools
