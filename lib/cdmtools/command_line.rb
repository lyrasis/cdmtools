require 'cdmtools'

module Cdmtools
  
  class CommandLine < Thor
    map %w[--version -v] => :__version
    desc '--version, -v', 'print the version'
    def __version
      puts "CDMtools version #{Cdmtools::VERSION}, installed #{File.mtime(__FILE__)}"
    end

    map %w[--config -c] => :__config
    desc '--config, -c', 'print out your config settings'
    def __config
      puts "\nYour project working directory:"
      puts Cdmtools::CONFIG.wrk_dir
      puts "\nYour API base URL:"
      puts Cdmtools::CONFIG.api_base
      puts "\nYour cdminspect path:"
      puts Cdmtools::CONFIG.cdminspect
    end
    
    desc 'get_coll_data', 'get information about collections from API'
    long_desc <<-LONGDESC
    `exe/cdm get_coll_data` performs an API call to get collections data for the CDM instance.

    It creates `colls.csv` (tabular version) and `colls.json` (json version) in your base directory to persist this information. Re-running get_coll_data will overwrite these files.

    Finally, in your base directory, it creates a directory for each collection. The directory name is the collection alias without the prepended slash.
    LONGDESC
    def get_coll_data
      Cdmtools::CollDataGetter.new
    end

    desc 'get_dc_mappings', 'get DC fields from API'
    long_desc <<-LONGDESC
    `exe/cdm get_dc_mappings` performs an API call to get the Dublin Core fields established for this CONTENTdm instance.

    It creates `dc_mapping.csv` and `dc_mapping.json` to persist this information. Re-running this command will overwrite these files.
    LONGDESC
    def get_dc_mappings
      Cdmtools::DcMappingGetter.new  
    end

    desc 'get_field_data', 'get CDM metadata field definitions from API'
    long_desc <<-LONGDESC
    `exe/cdm get_field_data` performs an API call to get the CDM metadata field definitions for each collection.

    It creates `fields.csv` and `fields.json` to persist this information. Re-running this command will overwrite these files.

    This command requires the `colls.json` file created by `get_coll_data`, and will re-run that command if the file is not found.
    LONGDESC
    def get_field_data
      Cdmtools::CdmFieldGetter.new  
    end

    desc 'get_pointers', 'get CDM pointer lists for each collection'
    long_desc <<-LONGDESC
    `exe/cdm get_pointers` creates a listing of the top level object pointers for each collection, in a file named `_pointers.txt`

    It uses cdminspect to produce these lists, so you will see the cdminspect output as the script runs.

    Finally, the cdminspect header line is removed from each resulting file. 
    LONGDESC
    def get_pointers
      colls = Cdmtools::CollDataParser.new.colls
      colls.each{ |coll| coll.get_pointers }
    end

    desc 'get_top_records', 'get and process CDM records for top level objects in collections'
    long_desc <<-LONGDESC
    `exe/cdm get_top_records` performs a dmGetItemInfo API call to get the CDM metadata record for each top-level pointer known for the collection. The record is written into the _cdmrecords directory in the collection directory.

    Then, it performs a dmGetCompoundObjectInfo for each of the top-level pointers. If the object is a compound object, the JSON object data record is written to the _cdmobjectinfo directory in the collection directory. If the object is not a compound object, no object data file is written.

    Finally, it looks at each record in _cdmrecords, and the corresponding _cdmobjectinfo record if available. It writes a new version of the cdmrecord with added fields into _migrecords. The fields added are:

    - migobjlevel (which will be top for all these records)

    - migobjcategory (compound or simple)

    If the object is a compound record, the following fields are also added:

    - migcompobjtype (i.e. Document, Postcard, etc.)

    - migchildptrs (ordered array of pointers for child objects to be used for fetching the child records)

    - migchilddata (hash of child data for later merging into child records)
    LONGDESC
    def get_top_records
      colls = Cdmtools::CollDataParser.new.colls
      colls.each{ |coll| coll.get_top_records }
    end

    desc 'get_child_records', 'get and process CDM records for child objects in collections'
    long_desc <<-LONGDESC
    `exe/cdm get_child_records` runs per collection. It looks at each metadata record in the collection's `_migrecords` directory. A record with no `migchildptrs` field will be skipped. 

    If a record has a `migchildptrs` field, a dmGetItemInfo API call is performed to get the CDM metadata record for each child pointer listed for the object. This record is written into the _cdmrecords directory in the collection directory.

    After grabbing the child records, creates new `_migrecords` versions of them. The following fields are added: 

    - migobjlevel (child)

    - migobjcategory (the compound object type of the parent)

    - migparentptr (pointer of parent object)

    - migtitle (pagetitle value from parent object dmGetCompoundObjectInfo call, which is often better data than what is in the title field of the child object record) 

    - migfile (pagefile value from the parent object dmGetCompoundObjectInfo call, in case it is missing from child record
    LONGDESC
    def get_child_records
      colls = Cdmtools::CollDataParser.new.colls
      colls.each{ |coll| coll.get_child_records }
    end

    desc 'finalize_records', 'set `migfiletype` field and changes `{}` values to `\'\'` values in `_migrecords` directory for all records in all collections'
    long_desc <<-LONGDESC
    `exe/cdm finalize_records` runs per collection. It looks at each metadata record in the collection's `_migrecords` directory. It adds a `migfiletype` field consisting of the file suffix of the file given in the `find` field.

    It also:

      - removes empty fields

      - removes leading/trailing space from string fields

      - replaces `\n` with space

      - replaces multiple consecutive spaces with one space
    LONGDESC
    def finalize_records
      colls = Cdmtools::CollDataParser.new.colls
      colls.each{ |coll| coll.finalize_records }
    end

    desc 'process_field_values', 'populates a field value hash for each collection, which can be used in further analysis'
    long_desc <<-LONGDESC
    `exe/cdm process_field_values` runs per collection. In each collection_directory, it creates a file called `_values.json`. This file is a hash with the following structure:

     { fieldname => { unique_field_value => [array of pointers having this value] } }
    LONGDESC
    def process_field_values
      colls = Cdmtools::CollDataParser.new.colls
      colls.each{ |coll| coll.process_field_values }
    end

  end
end
