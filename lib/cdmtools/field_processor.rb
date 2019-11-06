require 'cdmtools'
require 'pp'

module Cdmtools
  class FieldProcessor
    attr_reader :coll
    attr_reader :all_fields
    attr_reader :keeper_fields
    
    def initialize(coll)
      @coll = coll
      @valuehash = {}
      set_fields
    end

    private

    def set_fields
      @all_fields = []
      @coll.migrecs.each{ |recname|
        rec = JSON.parse(File.read("#{@coll.migrecdir}/#{recname}"))
        @all_fields << rec.keys
      }
      @all_fields.flatten!.uniq!

      @keeper_fields = @all_fields.clone
      Cdmtools::CONFIG.ignore_field_prefixes.each{ |prefix|
        @keeper_fields.reject!{ |e| e.start_with?(prefix) }
      }
    end

    def write_data_human(array, filename)
      CSV.open("#{@coll.colldir}/#{filename}", 'w'){ |csv|
        array.each { |row| csv << row }
      }
      end
  end

  class FieldTypeProcessor < FieldProcessor
    attr_reader :typehash

    def initialize(coll)
      super
      @typehash = {}
      build_fieldtype_hash
      #      report_fieldtype_hash
#      puts "See #{@coll.colldir}/_fieldtypes.pretty.json for details on field types."
#      write_data_human(@typehash, '_fieldtypes.pretty.json')
    end
    
    def build_fieldtype_hash
      @coll.migrecs.each{ |recname|
        rec = JSON.parse(File.read("#{@coll.migrecdir}/#{recname}"))
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

    def initialize(coll)
      super
      @valuehash = {}
      build_fieldvalue_hash
      report_fieldvalue_hash
      puts "See #{@coll.colldir}/_fieldvalues.pretty.json for details on field values."
      write_data_human(make_human_writable, '_fieldvalues.csv')
    end
    
    def build_fieldvalue_hash
      @coll.migrecs.each{ |recname|
        rec = JSON.parse(File.read("#{@coll.migrecdir}/#{recname}"))
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

    def make_human_writable
      rows = []
      rows << %w[coll field value occurrences pointers]
      @valuehash.keys.sort.each{ |field|
        @valuehash[field].keys.sort.each{ |field_val|
          rows << [@coll.alias, field, field_val, @valuehash[field][field_val].length, @valuehash[field][field_val].join(';')]
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
