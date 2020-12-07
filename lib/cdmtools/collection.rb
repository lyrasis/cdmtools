
require 'cdmtools'

module Cdmtools
  class Collection
    attr_reader :alias #collection alias, sans slash
    attr_reader :name #collection name
    attr_reader :colldir #collection directory
    attr_reader :cdmrecdir #directory for CDM records for individual objects
    attr_reader :migrecdir #directory for object records modified with migration-specific data
    attr_reader :cleanrecdir #directory for transformed/cleaned migration records
    attr_reader :cdmobjectinfodir #directory for CDM compound object info
    attr_reader :packagedir #directory for Islandora ingest packages
    attr_reader :objdir #directory for object files
    attr_reader :pointerfile #path to file where pointer list will be written
    attr_reader :objs_by_category #hash of pointers organized under keys 'compound', 'compound pdf', and 'simple'
    attr_reader :simpleobjs #list of pointers to simple objects in the collection
    attr_reader :compoundobjs #list of pointers to compound objects (top level) in the collection
    attr_reader :childobjs #list of pointers to compound object children in the collection
    attr_reader :migrecs #array of migration record filenames

    # initialized with hash of collection data from API output
    def initialize(h)
      @alias = h['alias']
      if h.has_key?('name')
        @name = h['name']
      else
        @name = h['alias']
      end
      @colldir = "#{Cdmtools::WRKDIR}/#{@alias}"
      @pointerfile = "#{@colldir}/_pointers.txt"
      make_directories
    end

    def clean_records
      set_migrecs
      RecordCleaner.new(self)
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
    
    def finalize_migration_records
      set_migrecs
      if @migrecs.length == 0
        Cdmtools::LOG.error("No parent records in #{@migrecdir}. Cannot get finalize records")
        return
      else
        MigrecFinalizer.new(self)
      end
    end
    
    def get_top_records(force)
      self.get_pointers
      size = File.readlines(@pointerfile).size
      pb = ProgressBar.create(:title => "Downloading #{size} records for #{@alias}",
                              :starting_at => 0,
                              :total => size,
                              :format => '%t : |%b>>%i| %p%% %a')

      File.readlines(@pointerfile).each{ |pointer|
        pointer = pointer.chomp
        RecordGetter.new(self, pointer, force)
        ObjectInfoGetter.new(self, pointer, force)
        CompoundObjInfoMerger.new(self, pointer)
        pb.increment
      }
      pb.finish
    end

    def get_child_records(force)
      set_migrecs
      if @migrecs.length == 0
        Cdmtools::LOG.error("No parent records in #{@migrecdir}. Cannot get child records")
        return
      else
        create_objs_by_category
        size = @compoundobjs.length
        if  size > 0
          ChildRecordGetter.new(self, force)
          ChildInfoMergeHandler.new(self)
        else
          Cdmtools::LOG.debug("No compound objects in #{@alias}. No child records retrieved")
        end
      end
    end

    def get_thumbnails
      self.get_pointers
      tndir = "#{colldir}/thumbnails"
      Dir::mkdir(tndir) unless Dir::exist?(tndir)
      to_get = []
      File.readlines(@pointerfile).each{ |pointer| to_get << pointer.chomp }
      already_have = Dir.new(tndir).children
      already_have.map!{ |e| File.basename(e, ".*") } unless already_have.empty?
      to_really_get = to_get - already_have

      progress = ProgressBar.create(:title => "Getting thumbnails for #{@alias}...", :starting_at => 0, :total => to_really_get.length, :format => '%a %E %B %c %C %p%% %t')
      to_really_get.each{ |pointer|
        url = URI("#{Cdmtools::CONFIG.util_base}/getthumbnail/collection/#{@alias}/id/#{pointer}")
        response = Net::HTTP.get_response(url)
        if response.is_a?(Net::HTTPSuccess)
          File.open("#{tndir}/#{pointer}.jpg", 'wb'){ |f| f.write(response.body) }
        else
          Cdmtools::LOG.warn("Could not download thumbnail for #{@alias}/#{pointer}.:")
        end
        progress.increment
      }
      progress.finish
    end

    def harvest_objects
      create_objs_by_category
      Cdmtools::ObjectHarvestHandler.new(self)
    end

    def report_object_counts
      ct = Dir.new(@objdir).children.length
      puts "#{ct} -- #{@alias}"
    end

    def print_object_hash
      create_objs_by_category
      puts "\n\n#{@alias} - #{@name}"
      pp(@objs_by_category)
    end

    def report_error_records
      report_path = "#{Cdmtools::CONFIG.wrk_dir}/problem_records.csv"
      errs = get_error_records
      if errs.length > 0
        if File::exist?(report_path)
          # just write the data
          CSV.open(report_path, 'a'){ |csv|
            errs.each{ |err| csv << err }
          }
        else
          # write the headers, then write the data
          CSV.open(report_path, "wb"){ |csv|
            csv << ['collection', 'pointer', 'code', 'message', 'restrictionCode']
            errs.each{ |err| csv << err }
          }
        end
      end
    end

    def get_error_records
      err_recs = []
      Dir.new(@cdmrecdir).children.each{ |recfile|
        recpath = "#{@cdmrecdir}/#{recfile}"       
        rec = JSON.parse(File.read(recpath))
        if rec['message']          
          pointer = recfile.delete('.json')
          message = rec['message']
          code = rec['code'] ? rec['code'] : ''
          rc = rec['restrictionCode'] ? rec['restrictionCode'] : ''
          err_recs << [@alias, pointer, code, message, rc]
        end
      }
      return err_recs
    end
    
    def report_object_totals
      create_objs_by_category
      return { 'simple' => @simpleobjs.length,
              'children' => @childobjs.length
             }
    end
    
    def report_object_stats
      create_objs_by_category
      puts "\n\n#{@alias} - #{@name}"
      puts "SIMPLE OBJECTS"
      @objs_by_category.each{ |k, v|
        unless k == 'compound' || k == 'children'
          puts "  #{k}: #{v.length}" unless v.empty?
        end
      }
      all_cpd = []
      @objs_by_category['compound'].each{ |k, v|
        all_cpd << v
      }
      all_cpd.flatten!
      
      puts "COMPOUND OBJECTS" unless all_cpd.empty?
      
      @objs_by_category['compound'].each{ |k, v|
        unless v.empty?
          puts "  #{k}: #{v.length}"
          puts "    CHILD OBJECTS"
          @objs_by_category['children'][k].each{ |ft, ptrs|
            puts "      #{ft}: #{ptrs.length}"
          }
        end
      }
    end
    
    def report_object_filesize_mismatches
      create_objs_by_category
      to_check = []
      @objs_by_category.each{ |category, data|
        to_check << data unless ['external media', 'pdf', 'compound', 'children'].include?(category)
      }
      @objs_by_category['children'].each{ |category, byfiletypes|
        byfiletypes.each{ |filetype, pointers| to_check << pointers }
      }
      to_check.flatten.each{ |pointer|
        rec = get_migrec(pointer)
        fileext = rec['migfiletype']
        filesize = get_filesize(pointer)
        obj = "#{@objdir}/#{pointer}.#{fileext}"
        objsize = File.size(obj)
        puts "#{@alias}/#{pointer}.#{fileext} -- in rec: #{filesize} -- on disk: #{objsize}" if filesize != objsize
      }
    end
    
    def report_object_size
      create_objs_by_category
      size = 0
      @simpleobjs.each{ |pointer|
        rec = get_migrec(pointer)
        filetype = rec['migfiletype'].downcase
        size += get_filesize(pointer) unless filetype == 'pdf'
      }
      @childobjs.each{ |pointer|
        size += get_filesize(pointer)
      }
      return size
    end

    private

    def get_migrec(pointer)
      JSON.parse(File.read("#{@migrecdir}/#{pointer}.json"))
    end

    def get_filesize(pointer)
      rec = get_migrec(pointer)
      filesize = rec['cdmfilesize'] ? rec['cdmfilesize'].to_i : 0
      filesize
    end
    
    def create_objs_by_category
      return unless @objs_by_category.nil?
      
      @objs_by_category = {
        'external media' => [],
        'pdf' => [],
        'compound' => {
          'document-PDF' => [],
          'document' => [],
          'postcard' => [],
          'picture cube' => [],
          'other' => []
        },
        'children' => {
          'document-PDF' => {},
          'document' => {},
          'postcard' => {},
          'picture cube' => {},
          'other' => {}
        }
      }
      Dir.new(@migrecdir).children.each{ |recname|
        rec = JSON.parse(File.read("#{@migrecdir}/#{recname}"))
        pointer = rec['dmrecord']
        filetype = rec['migfiletype'] ? rec['migfiletype'].downcase : 'unknown'

        case rec['migobjlevel']
        when 'top'
          case rec['migobjcategory']
            when 'simple'
              if @objs_by_category.has_key?(filetype)
                @objs_by_category[filetype] << pointer
              else
                @objs_by_category[filetype] = [pointer]
              end
            when 'external media'
              @objs_by_category['external media'] << pointer
            when 'compound'
              case rec['migcompobjtype']
              when 'Document-PDF'
                  @objs_by_category['pdf'] << pointer if rec['cdmprintpdf'] == '1'
                  @objs_by_category['compound']['document-PDF'] << pointer if rec['cdmprintpdf'] == '0'
              when 'Document'
                @objs_by_category['compound']['document'] << pointer
              when 'Picture Cube'
                @objs_by_category['compound']['picture cube'] << pointer
              when 'Postcard'
                @objs_by_category['compound']['postcard'] << pointer
              else
                @objs_by_category['compound']['other'] << pointer
              end
            end
        when 'child'
          case rec['migobjcategory']
          when 'Document-PDF'
            if @objs_by_category['children']['document-PDF'].has_key?(filetype) 
              @objs_by_category['children']['document-PDF'][filetype] << pointer
            else
              @objs_by_category['children']['document-PDF'][filetype] = [pointer]
            end
          when 'Document'
            if @objs_by_category['children']['document'].has_key?(filetype) 
              @objs_by_category['children']['document'][filetype] << pointer
            else
              @objs_by_category['children']['document'][filetype] = [pointer]
            end
          when 'Picture Cube'
            if @objs_by_category['children']['picture cube'].has_key?(filetype) 
              @objs_by_category['children']['picture cube'][filetype] << pointer
            else
              @objs_by_category['children']['picture cube'][filetype] = [pointer]
            end
          when 'Postcard'
            if @objs_by_category['children']['postcard'].has_key?(filetype) 
              @objs_by_category['children']['postcard'][filetype] << pointer
            else
              @objs_by_category['children']['postcard'][filetype] = [pointer]
            end
          else
            if @objs_by_category['children']['other'].has_key?(filetype) 
              @objs_by_category['children']['other'][filetype] << pointer
            else
              @objs_by_category['children']['other'][filetype] = [pointer]
            end
          end
        end
      }
      set_simpleobjs
      set_compoundobjs
      set_childobjs
    end

    def set_compoundobjs
      pointers = []
      @objs_by_category['compound'].each{ |category, ptrarray|
        pointers << ptrarray
      }
      @compoundobjs = pointers.flatten
    end

    def set_childobjs
      pointers = []
      @objs_by_category['children'].each{ |category, filetypes|
        filetypes.each{ |filetype, ptrarray|
          pointers << ptrarray
        }
      }
      @childobjs = pointers.flatten
    end
    
    def set_simpleobjs
      pointers = []
      exclude = ['compound', 'children', 'external media']
      
      @objs_by_category.each{ |category, data|
        pointers << data unless exclude.include?(category)
      }
      @simpleobjs = pointers.flatten
    end
    
    def make_directories
      @cdmrecdir = "#{@colldir}/_cdmrecords"
      @cdmobjectinfodir = "#{@colldir}/_cdmobjectinfo"
      @cleanrecdir = "#{@colldir}/_cleanrecords"
      @migrecdir = "#{@colldir}/_migrecords"
      @objdir = "#{@colldir}/_objects"
      @packagedir = "#{@colldir}/_packages"
      
      [@cdmrecdir, @cdmobjectinfodir, @cleanrecdir, @migrecdir, @objdir, @packagedir].each{ |dirpath|
        Dir::mkdir(dirpath) unless Dir::exist?(dirpath)
      }
    end

    
  end 
end #Cdmtools
