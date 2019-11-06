require 'cdmtools'
require 'pp'

module Cdmtools
  class CompoundObjInfoMerger
    attr_reader :coll #collection object
    attr_reader :pointer #object pointer
    attr_reader :cdmrec #json cdm record
    attr_reader :objinfo #json cdm object info; nil if not compound
    attr_reader :level #top or child
    attr_reader :category #compound or simple
    attr_reader :cotype #compound object type (set on compound objects)
    attr_reader :migrecpath #json migration record
    attr_reader :childpointers #array of pointers to object's children
    attr_reader :childdata #hash of child data hashes { pointer => { pagefile = '', pagetitle = '' } }

    def initialize(coll, pointer)
      @coll = coll
      @pointer = pointer
      @migrecpath = "#{@coll.migrecdir}/#{@pointer}.json"
      @level = 'top'
      get_cdm_rec
      get_obj_info
      get_category
      return if @category.nil?

      if @category == 'compound'
        get_compound_object_type
        cd = get_child_data
        format_child_data(cd) if cd.length > 0
        @cdmrec['migcompobjtype'] = @cotype
      end

      @cdmrec['migobjcategory'] = @category
      @cdmrec['migobjlevel'] = @level

      write_mig_record
    end

    private

    # given array of CDM child object hashes, sets @childpointers and @childdata
    def format_child_data(cd)
      @childpointers = []
      @childdata = {}
      cd.each{ |c|
        @childpointers << c['pageptr']
        @childdata[c['pageptr']] = { 'title' => c['pagetitle'], 'file' => c['pagefile'] }
      }
      @cdmrec['migchildptrs'] = @childpointers
      @cdmrec['migchilddata'] = @childdata
    end
    
    def get_category
      if @cdmrec && @objinfo
        @category = 'compound'
      elsif @cdmrec && !@objinfo
        @category = 'simple'
      else
        Cdmtools::LOG.error("Cannot determine category for #{@coll.alias}/#{@pointer}. The CDM record is probably missing")
        @category = nil
      end
    end
    
    def get_cdm_rec
      if File::exist?("#{@coll.cdmrecdir}/#{@pointer}.json")
        @cdmrec = JSON.parse(File.read("#{@coll.cdmrecdir}/#{@pointer}.json"))
      else
        @cdmrec = nil
        Cdmtools::LOG.warn("No record for object #{@coll.alias}/#{@pointer}")
      end
    end

    # returns array of child data hashes as found in CDM data
    # accounts for the different structures CDM uses to represent children
    # simplifies and just returns a flat list of the child object hashes in order
    def get_child_data
      if ['Postcard', 'Document'].include?(@cotype)
        if @objinfo['page'].is_a?(Hash)
          pages = process_node_hash(@objinfo, [])
          return pages
        elsif @objinfo['page'].is_a?(Array)
          return @objinfo['page']
        end
      elsif @cotype == 'Monograph'
        pages = process_node_hash(@objinfo, [])
        return pages
      elsif @cotype == 'Document-PDF'
        if @cdmrec['cdmprintpdf'] == '1'
          Cdmtools::LOG.info("Not retrieving child data for #{@cotype} #{@coll.alias}/#{@pointer}")
        else
          Cdmtools::LOG.warn("#{@cotype} #{@coll.alias}/#{@pointer} not marked as cdmprintpdf. Check it out.")
        end
        return []
      end
    end

    def get_compound_object_type
      @cotype = @objinfo['type']
    end
    
    def get_obj_info
      if File::exist?("#{@coll.cdmobjectinfodir}/#{@pointer}.json")
        @objinfo = JSON.parse(File.read("#{@coll.cdmobjectinfodir}/#{@pointer}.json"))
      else
        @objinfo = nil
      end
    end

    def process_node_hash(hash, acc)
      hash.each do |key, value|
        if value.is_a?(Hash) && value.has_key?('pageptr')
          acc << value
        elsif key == 'page' && value.is_a?(Array)
          value.each { |element| acc << element }
        elsif value.is_a?(Array)
          value.each { |element| process_node_hash(element, acc) if element.is_a?(Hash) }
        elsif value.is_a?(Hash)
          process_node_hash(value, acc)
        end
      end
      return acc
    end
    
    def write_mig_record
      File.open(@migrecpath, 'w'){ |f|
        f.write(@cdmrec.to_json)
      }
      Cdmtools::LOG.info("Wrote altered migration record to: #{@migrecpath}")
    end

  end #CollDataGetter class
end #Cdmtools
