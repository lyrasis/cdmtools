require 'cdmtools'

module Cdmtools
  class ChildRecordGetter

    # initialized with a collection
    def initialize(coll)
      coll.objs_by_category['compound']['other'].each{ |compoundptr|
        Cdmtools::LOG.info("Getting children for compound object #{coll.alias}/#{compoundptr}...")
        parent_rec = JSON.parse(File.read("#{coll.migrecdir}/#{compoundptr}.json"))
        child_ptrs = parent_rec['migchildptrs']
        child_ptrs.each{ |ptr| RecordGetter.new(coll, ptr) }
      }
    end

  end
end #Cdmtools
