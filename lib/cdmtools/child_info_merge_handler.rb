require 'cdmtools'

module Cdmtools
  class ChildInfoMergeHandler

    def initialize(coll)
      size = coll.compoundobjs.length
      pb = ProgressBar.create(:title => "Merging migrec data into #{size} child records for #{coll.alias}",
                              :starting_at => 0,
                              :total => size,
                              :format => '%t : |%b>>%i| %p%% %a')
      coll.compoundobjs.each{ |compoundptr|
        Cdmtools::LOG.debug("Merging parent info into compound object children of #{coll.alias}/#{compoundptr}...")
        parent_rec = JSON.parse(File.read("#{coll.migrecdir}/#{compoundptr}.json"))
        child_ptrs = parent_rec['migchildptrs']
        child_ptrs.each{ |ptr| ChildInfoMerger.new(coll, compoundptr, ptr) }
        pb.increment
      }
      pb.finish
    end

  end #CollDataGetter class
end #Cdmtools
