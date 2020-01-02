require 'cdmtools'
require 'pp'

module Cdmtools
  class FieldProcessor
    attr_reader :coll
    attr_reader :rectype
    attr_reader :recdir
    attr_reader :all_fields
    attr_reader :keeper_fields
    
    def initialize(coll, rectype)
      @coll = coll
      @rectype = rectype
      @recdir = determine_dir
      @valuehash = {}
      set_fields
    end

    private

    def determine_dir
      case @rectype
      when 'orig'
        return @coll.cdmrecdir
      when 'mig'
        return @coll.migrecdir
      when 'clean'
        return @coll.cleanrecdir
      end
    end
    
    def set_fields
      @all_fields = []
      Dir.new(@recdir).children.each{ |recname|
        rec = JSON.parse(File.read("#{@recdir}/#{recname}"))
        @all_fields << rec.keys
      }
      @all_fields.flatten!.uniq!

      @keeper_fields = @all_fields.clone
      Cdmtools::CONFIG.reporting_ignore_field_prefixes.each{ |prefix|
        @keeper_fields.reject!{ |e| e.start_with?(prefix) }
      }
    end

    def write_csv(array, filename)
      CSV.open("#{@coll.colldir}/#{filename}", 'w'){ |csv|
        array.each { |row| csv << row }
      }
      end
  end

  class FieldTypeProcessor < FieldProcessor
    attr_reader :typehash

    def initialize(coll, rectype)
      super
      @typehash = {}
      build_fieldtype_hash
      #      report_fieldtype_hash
#      puts "See #{@coll.colldir}/_fieldtypes.pretty.json for details on field types."
#      write_csv(@typehash, '_fieldtypes.pretty.json')
    end
    
    def build_fieldtype_hash
      @coll.migrecs.each{ |recname|
        rec = JSON.parse(File.read("#{@recdir}/#{recname}"))
        recid = rec['dmrecord']
        rec.each{ |fieldname, value|
          if @keeper_fields.include?(fieldname)
            type = value.class.to_s
            if @typehash.has_key?(type)
              @typehash[type] << "#{@coll.alias}/#{recid}/#{fieldname}"
            else
              @typehash[type] = ["#{@coll.alias}/#{recid}/#{fieldname}"]
            end
          end
        }
      }
    end

    def report_fieldtype_hash
      puts "\n\nCOLLECTION: #{@coll.alias}"
      @typehash.each{ |type, array|
        puts "#{type}: #{array.length}"
      }
    end
    
  end

  class FieldValueProcessor < FieldProcessor
    attr_reader :valuehash

    def initialize(coll, rectype)
      super
      @valuehash = {}
      build_fieldvalue_hash
      report_fieldvalue_hash
      puts "See #{@coll.colldir}/_fieldvalues.pretty.json for details on field values."
      write_csv(format_for_csv, "_fieldvalues_#{@rectype}.csv")
    end
    
    def build_fieldvalue_hash
      Dir.new(@recdir).children.each{ |recname|
        rec = JSON.parse(File.read("#{@recdir}/#{recname}"))
        recid = rec['dmrecord']
        rec.each{ |fieldname, value|
          if @keeper_fields.include?(fieldname)
            set_fieldname(fieldname)
            set_value(fieldname, value)
            @valuehash[fieldname][value] << recid
          end
        }
      }
    end

    def report_fieldvalue_hash
      puts "\n\nCOLLECTION: #{@coll.alias}"
      @valuehash.each{ |fieldname, h|
        puts "#{fieldname}: #{h.length} unique values"
      }
    end

    def format_for_csv
      rows = []
      @valuehash.keys.sort.each{ |field|
        @valuehash[field].keys.each{ |field_val|
          @valuehash[field][field_val].each{ |pointer|
            rows << [@coll.alias, field, field_val, "#{@coll.alias}/#{pointer}"]
          }
        }
      }
      rows
    end
    
    def set_fieldname(fieldname)
      @valuehash[fieldname] = {} unless @valuehash.has_key?(fieldname)
    end

    def set_value(fieldname, value)
      @valuehash[fieldname][value] = [] unless @valuehash[fieldname].has_key?(value)
    end
    
  end
end #Cdmtools
