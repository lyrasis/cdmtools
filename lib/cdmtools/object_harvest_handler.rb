require "cdmtools"
require_relative "file_harvester"
require_relative "helpers"

module Cdmtools
  class ObjectHarvestHandler
    attr_reader :coll
    attr_reader :simpleobjs
    attr_reader :compoundobjs

    # initialized with a collection object and pointer
    def initialize(coll)
      @coll = coll
      @simpleobjs = get_simpleobjs
      @compoundobjs = get_compoundobjs

      unless @simpleobjs.empty?
        Cdmtools::SimpleObjectHarvestHandler.new(@coll,
          @simpleobjs)
      end
      unless @compoundobjs.empty?
        Cdmtools::CompoundObjectHarvestHandler.new(@coll,
          @compoundobjs)
      end
    end

    private

    def get_simpleobjs
      h = {}
      @coll.objs_by_category.each { |filetype, pointers|
        unless ["external media", "compound", "children"].include?(filetype)
          h[filetype] = pointers unless pointers.empty?
        end
      }
      h
    end

    def get_compoundobjs
      h = {}
      @coll.objs_by_category["children"].each { |objtype, filetypehash|
        h[objtype] = filetypehash unless filetypehash.empty?
      }
      h
    end
  end # class ObjectHarvestHandler

  class AnyObjectHarvestHandler
    attr_reader :objhash
    attr_reader :collalias
    attr_reader :filepathbase
    attr_reader :recpathbase

    def initialize(coll, objhash)
      @objhash = objhash
      @collalias = coll.alias
      @filepathbase = coll.objdir
      @recpathbase = coll.migrecdir
    end
  end

  class SimpleObjectHarvestHandler < AnyObjectHarvestHandler
    def initialize(coll, objhash)
      super
      unless @objhash.empty?
        len = get_obj_ct
        pb = ProgressBar.create(title: "Harvesting simple objects for #{@collalias}",
          starting_at: 0,
          total: len,
          format: "%a %E %B %c %C %p%% %t")
        @objhash.each { |filetype, pointers|
          pointers.each { |pointer|
            Cdmtools::ObjectHarvester.new(@filepathbase, @recpathbase,
              @collalias, pointer, filetype)
            pb.increment
          }
        }
        pb.finish
      end
    end

    private

    def get_obj_ct
      objs = @objhash.values.flatten
      objs.length
    end
  end

  class CompoundObjectHarvestHandler < AnyObjectHarvestHandler
    def initialize(coll, objhash)
      super
      unless @objhash.empty?
        len = get_obj_ct
        pb = ProgressBar.create(title: "Harvesting compound object children for #{@collalias}",
          starting_at: 0,
          total: len,
          format: "%a %E %B %c %C %p%% %t")
        @objhash.each { |cat, byfiletype|
          byfiletype.each { |filetype, pointers|
            pointers.each { |pointer|
              Cdmtools::ObjectHarvester.new(@filepathbase, @recpathbase,
                @collalias, pointer, filetype)
              pb.increment
            }
          }
        }
        pb.finish
      end
    end

    private

    def get_obj_ct
      objs = []
      @objhash.each { |cat, byfiletype|
        byfiletype.each { |filetype, pointers|
          pointers.each { |pointer| objs << pointer }
        }
      }
      objs.length
    end
  end

  class ObjectHarvester
    attr_reader :pointer
    attr_reader :filename
    attr_reader :path
    attr_reader :coll
    attr_reader :url

    def initialize(objdir, recdir, coll, pointer, filetype)
      @pointer = pointer
      @filename = "#{@pointer}.#{filetype}"
      @path = "#{objdir}/#{@filename}"
      @coll = coll
      @url = Cdmtools::Helpers.object_url(
        collection: @coll,
        pointer: @pointer,
        filename: @filename
      )

      if filetype == "pdf" && File.exist?(@path)
        Cdmtools::LOG.debug("OBJHARVEST: #{@coll}/#{@filename} exists. Skipped harvest without comparing size.")
        nil
      elsif File.exist?(@path)
        fsr = JSON.parse(File.read("#{recdir}/#{pointer}.json"))["cdmfilesize"].to_i
        fs = File.size(@path).to_i
        if fsr == fs
          #          puts "#{@path.inspect} filesize same: rec: #{fsr.inspect}, file: #{fs.inspect}"
          Cdmtools::LOG.debug("OBJHARVEST: #{@coll}/#{@filename} exists with identical filesize. Skipped harvest.")
          nil
        else
          #          puts "#{@path.inspect} filesize diff: rec: #{fsr.inspect}, file: #{fs.inspect}"
          Cdmtools::FileHarvester.new.call(url: @url, write_to: @path)
        end
      elsif !File.exist?(@path)
        #        puts "#{@path.inspect} file doesn't exist"
        Cdmtools::FileHarvester.new.call(url: @url, write_to: @path)
      end
    end
  end
end # Cdmtools
