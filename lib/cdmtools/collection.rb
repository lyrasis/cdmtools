require 'cdmtools'

module Cdmtools
  class Collection
    attr_reader :alias #collection alias, sans slash
    attr_reader :name #collection name
    attr_reader :colldir #collection directory
    attr_reader :cdmrecdir #directory for CDM records for individual objects
    attr_reader :migrecdir #directory for object records modified with migration-specific data
    attr_reader :cdmobjectinfodir #directory for CDM compound object info
    attr_reader :pointerfile #path to file where pointer list will be written
    attr_reader :objs_by_category #hash of pointers organized under keys 'compound', 'compound pdf', and 'simple'
    attr_reader :simpleobjs #list of pointers to simple objects in the collection
    attr_reader :migrecs #array of migration record filenames

    # initialized with hash of collection data from API output
    def initialize(h)
      @alias = h['alias']
      @name = h['name']
      @colldir = "#{Cdmtools::WRKDIR}/#{@alias}"
      @pointerfile = "#{@colldir}/_pointers.txt"
      make_directories
    end

    def get_pointers
      Cdmtools::CollPointerGetter.new(self)
    end

    def set_migrecs
      @migrecs = Dir.new(@migrecdir).children
      if @migrecs.length == 0
        Cdmtools::LOG.error("No records in #{@migrecdir}.")
        return
      else
        Cdmtools::LOG.info("Identified #{@migrecs.length} records for #{@alias}...")
      end
    end
    
    def finalize_records
      set_migrecs
      if @migrecs.length == 0
        Cdmtools::LOG.error("No parent records in #{@migrecdir}. Cannot get finalize records")
        return
      else
        FileTypeSetter.new(self)
        RecordCleaner.new(self)
      end
    end
    
    def get_top_records
      self.get_pointers
      File.readlines(@pointerfile).each{ |pointer|
        pointer = pointer.chomp
        RecordGetter.new(self, pointer)
        ObjectInfoGetter.new(self, pointer)
        CompoundObjInfoMerger.new(self, pointer)
      }
    end

    def get_child_records
      set_migrecs
      if @migrecs.length == 0
        Cdmtools::LOG.error("No parent records in #{@migrecdir}. Cannot get child records")
        return
      else
        create_objs_by_category
        if @objs_by_category['compound']['other'].length > 0
          ChildRecordGetter.new(self)
          ChildInfoMergeHandler.new(self)
        end
      end
    end

    def process_field_values
      set_migrecs
      if @migrecs.length == 0
        Cdmtools::LOG.error("No parent records in #{@migrecdir}. Cannot get process field values")
        return
      else
        Cdmtools::FieldTypeProcessor.new(self)
        Cdmtools::FieldValueProcessor.new(self)
      end
    end

    private
    
    def create_objs_by_category
      @objs_by_category = { 'simple' => [], 'compound' => { 'pdf' => [], 'other' => [] } }
      Dir.new(@migrecdir).children.each{ |recname|
        rec = JSON.parse(File.read("#{@migrecdir}/#{recname}"))
        pointer = rec['dmrecord']
        case rec['migobjcategory']
        when 'simple'
          @objs_by_category['simple'] << pointer
        when 'compound'
          if rec['migcompobjtype'] == 'Document-PDF'
            @objs_by_category['compound']['pdf'] << pointer
          else
            @objs_by_category['compound']['other'] << pointer
          end
        end
      }
    end
    
    def make_directories
      @cdmrecdir = "#{@colldir}/_cdmrecords"
      @cdmobjectinfodir = "#{@colldir}/_cdmobjectinfo"
      @migrecdir = "#{@colldir}/_migrecords"
      
      [@cdmrecdir, @cdmobjectinfodir, @migrecdir].each{ |dirpath|
        Dir::mkdir(dirpath) unless Dir::exist?(dirpath)
      }
    end
    
  end 
end #Cdmtools
