require 'cdmtools'

module Cdmtools
  class ChildRecordGetter

    # initialized with a collection
    def initialize(coll, force)
      size = coll.compoundobjs.length
      pb = ProgressBar.create(:title => "Downloading #{size} child records for #{coll.alias}",
                              :starting_at => 0,
                              :total => size,
                              :format => '%t : |%b>>%i| %p%% %a')

      coll.compoundobjs.each{ |compoundptr|
        Cdmtools::LOG.debug("Getting children for compound object #{coll.alias}/#{compoundptr}...")
        parent_rec = JSON.parse(File.read("#{coll.migrecdir}/#{compoundptr}.json"))
        child_ptrs = parent_rec['migchildptrs']
        child_ptrs.each{ |ptr| RecordGetter.new(coll, ptr, force) }
        pb.increment
      }
      pb.finish
    end

  end
end #Cdmtools
