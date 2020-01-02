require 'cdmtools'

module Cdmtools
  class ObjectHarvestHandler
    attr_reader :coll
    attr_reader :type
    attr_reader :simple
    attr_reader :pdfdoc
    attr_reader :compound
    
    # initialized with a collection object and pointer
    def initialize(coll, type)
      @coll = coll
      @type = type
      if @type == 'simple' || @type == ''
          simple = @coll.objs_by_category['simple']
        unless simple.empty?
          progress = ProgressBar.create(:title => "Harvesting simple objects for #{@coll.alias}...", :starting_at => 0, :total => simple.length, :format => '%a %E %B %c %C %p%% %t')
          simple.each{ |ptr|
            Cdmtools::SimpleObjectHarvester.new(@coll.migrecdir, @coll.objdir, @coll.alias, ptr)
            progress.increment
          }
          progress.finish
        else
          puts "No simple objects for #{@coll.alias}."
        end
      end

      if @type == 'pdfdoc' || @type == ''
        pdf = @coll.objs_by_category['compound']['pdf']
        unless pdf.empty?
          progress = ProgressBar.create(:title => "Harvesting Document-PDF objects for #{@coll.alias}...", :starting_at => 0, :total => pdf.length, :format => '%a %E %B %c %C %p%% %t')
          pdf.each{ |ptr|
            Cdmtools::PDFObjectHarvester.new(@coll.migrecdir, @coll.objdir, @coll.alias, ptr)
            progress.increment
          }
          progress.finish
        else
          puts "No PDF objects for #{@coll.alias}"
        end
      end

    end

    private
  end

  class FileHarvester
    def initialize(url, path, filesize = '0')
      if File.exist?(path) && File.size(path).to_s == filesize
        Cdmtools::LOG.debug("#{path} exists. Skipping harvest.")
        elsif File.exist?(path) && filesize == '0'
          Cdmtools::LOG.debug("#{path} exists and we don't know expected filesize. Skipping harvest.")
      else        
        response = Net::HTTP.get_response(URI(url))
        if response.is_a?(Net::HTTPSuccess)
          File.open(path, 'wb'){ |f| f.write(response.body) }
          unless filesize == '0' #we don't have that info from the record
            Cdmtools::LOG.warn("Filesize mismatch: record says #{filesize}. #{path} is #{File.size(path)}")
          end
          sleep(1)
        else
          Cdmtools::LOG.error("Could not harvest file: #{url}")
        end
      end
    end
  end

  class ObjectHarvester
    attr_reader :rec
    attr_reader :pointer

    def initialize(recdir, objdir, coll, pointer)
      @rec = JSON.parse(File.read("#{recdir}/#{pointer}.json"))
      @pointer = pointer
    end
  end

  class PDFObjectHarvester < ObjectHarvester
    attr_reader :name
    attr_reader :path
    attr_reader :url

    def initialize(recdir, objdir, coll, pointer)
      super
      @name = "#{pointer}.pdf"
      @path = "#{objdir}/#{@name}"
      @url = "#{Cdmtools::CONFIG.util_base}/getfile/collection/#{coll}/id/#{@pointer}/filename/#{@name}"
      Cdmtools::FileHarvester.new(@url, @path)
    end
  end
  

  class SimpleObjectHarvester < ObjectHarvester
    attr_reader :name
    attr_reader :path
    attr_reader :url

    def initialize(recdir, objdir, coll, pointer)
      super
      @name = get_filename
      @path = "#{objdir}/#{@name}"
      @url = "#{Cdmtools::CONFIG.util_base}/getfile/collection/#{coll}/id/#{@pointer}/filename/#{@name}"
      Cdmtools::FileHarvester.new(@url, @path, @rec['cdmfilesize'])
    end

    private

    def get_filename
      return "#{@pointer}.#{@rec['migfiletype'].downcase}"
    end
    
  end
  
end #Cdmtools
