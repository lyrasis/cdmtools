require 'cdmtools'

module Cdmtools
  class ChildInfoMerger
    attr_reader :coll #collection object
    attr_reader :pointer #object pointer
    attr_reader :parentpointer #pointer to parent object
    attr_reader :cdmrec #json cdm record
    attr_reader :parentrec
    attr_reader :level #top or child
    attr_reader :category #the compound object type of parent
    attr_reader :migrecpath #json migration record

    def initialize(coll, parentpointer, pointer)
      @coll = coll
      @pointer = pointer
      @parentpointer = parentpointer
      @migrecpath = "#{@coll.migrecdir}/#{@pointer}.json"
      @level = 'child'
      get_cdm_rec
      get_parent_rec
      get_category

      @cdmrec['migobjcategory'] = @category
      @cdmrec['migobjlevel'] = @level
      @cdmrec['migparentptr'] = @parentpointer
      @cdmrec['migtitle'] = @parentrec['migchilddata'][pointer]['title']
      @cdmrec['migfile'] = @parentrec['migchilddata'][pointer]['file']
      
      write_mig_record
    end

    private

    def get_category
      @category = @parentrec['migcompobjtype']
    end
    
    def get_cdm_rec
      if File::exist?("#{@coll.cdmrecdir}/#{@pointer}.json")
        @cdmrec = JSON.parse(File.read("#{@coll.cdmrecdir}/#{@pointer}.json"))
      else
        @cdmrec = nil
        Cdmtools::LOG.warn("No record for object #{@coll.alias}/#{@pointer}")
      end
    end

    def get_parent_rec
      if File::exist?("#{@coll.migrecdir}/#{@parentpointer}.json")
        @parentrec = JSON.parse(File.read("#{@coll.migrecdir}/#{@parentpointer}.json"))
      else
        @objinfo = nil
      end
    end
    
    def write_mig_record
      File.open(@migrecpath, 'w'){ |f|
        f.write(@cdmrec.to_json)
      }
      Cdmtools::LOG.debug("Wrote altered migration record to: #{@migrecpath}")
    end

  end #CollDataGetter class
end #Cdmtools
