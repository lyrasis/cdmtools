require 'cdmtools'

module Cdmtools
  class CommandLine < Thor
    def initialize(*args)
      super(*args)
      # TODO: replace constant
      Cdmtools.const_set('CONFIG', Cdmtools::ConfigReader.new(config: options[:config]))
    end

    no_commands{
      def get_colls
        if options[:coll].nil? || options[:coll].empty?
          # initializing CollDataParser with empty array will return all colls if none are specified in config
          if Cdmtools::CONFIG.colls.length > 0
            coll_list = Cdmtools::CONFIG.colls
          else
            coll_list = []
          end
        else
          # or just work on the colls specified
          coll_list = options[:coll].split(',')
        end
        return Cdmtools::CollDataParser.new(coll_list).colls
      end
    }
    
    class_option :config, type: 'string', default: 'config/config.yaml', aliases: '-c'

    map %w[--version -v] => :__version
    desc '--version, -v', 'print the version'
    def __version
      puts "CDMtools version #{Cdmtools::VERSION}, installed #{File.mtime(__FILE__)}"
    end

    map %w[--settings -s] => :__settings
    desc '--settings, -s', 'print out your config settings'
    def __settings
      puts "\nYour project working directory:"
      puts Cdmtools::CONFIG.wrk_dir
      puts "\nYour API base URL:"
      puts Cdmtools::CONFIG.api_base
      puts "\nYour cdminspect path:"
      puts Cdmtools::CONFIG.cdminspect
      puts "\nYour specified collections:"
      CONFIG.colls.each{ |c| puts c }
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
    option :coll, :desc => 'comma-separated list of collection aliases to include in processing', :default => ''
    def get_field_data
      colls = get_colls
      Cdmtools::CdmFieldGetter.new(colls)
    end

    desc 'get_pointers', 'get CDM pointer lists for each collection'
    long_desc <<-LONGDESC
    `exe/cdm get_pointers` creates a listing of the top level object pointers for each collection, in a file named `_pointers.txt`

    It uses cdminspect to produce these lists, so you will see the cdminspect output as the script runs.

    Finally, the cdminspect header line is removed from each resulting file. 
    LONGDESC
    option :coll, :desc => 'comma-separated list of collection aliases to include in processing', :default => ''
    def get_pointers
      colls = get_colls
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
    option :coll, :desc => 'comma-separated list of collection aliases to include in processing', :default => ''
    option :force, :desc => 'boolean (true, false) - whether to force refresh of data', :default => 'false'
    def get_top_records
      colls = get_colls
      colls.each{ |coll| coll.get_top_records(options[:force]) }
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
    option :coll, :desc => 'comma-separated list of collection aliases to include in processing', :default => ''
    option :force, :desc => 'boolean (true, false) - whether to force refresh of data', :default => 'false'
    def get_child_records
      colls = get_colls
      colls.each{ |coll| coll.get_child_records(options[:force]) }
    end

    desc 'report_cdm_error_records', 'produce report of missing/error cdmrecords'
    long_desc <<-LONGDESC
    Runs per collection. It looks at each metadata record in the collection's `_cdmrecords` directory and reports back `code`, `message`, and `restrictionCode` field values if present.

CDM API does not return an HTTP error status if an actual record cannot be returned, so we end up with these stub records that must be detected and handled after the fact.

Writes csv of problem record data (`problem_cdm_records.csv`) to CDM working directory.
    LONGDESC
    option :coll, :desc => 'comma-separated list of collection aliases to include in processing', :default => ''
    def report_cdm_error_records
      report_path = "#{Cdmtools::CONFIG.wrk_dir}/problem_cdm_records.csv"
      File.delete(report_path) if File::exist?(report_path)
      colls = get_colls
      colls.each{ |coll| coll.report_cdm_error_records(report_path) }
    end

    desc 'delete_cdm_error_records', 'delete missing/error cdmrecords and migrecs, based on problem record report'
    long_desc <<-LONGDESC
    Runs on the problem_cdm_records.csv file created via the `report_error_records` command. If there is no problem_records.csv file in the working directory, it does nothing. Otherwise, it goes through that file and deletes the records listed in it from the _cdmrecords, _migrecords, and _cleanrecords directories. 
    LONGDESC
    def delete_cdm_error_records
      report_path = "#{Cdmtools::CONFIG.wrk_dir}/problem_cdm_records.csv"
      if File.file?(report_path)
        puts "Records deleted from cdm, mig, clean record directories:"
        CSV.read(report_path, headers: true).each do |err|
          colldir = "#{Cdmtools::CONFIG.wrk_dir}/#{err['collection']}"
          pointer = err['pointer']
          cdmrec = "#{colldir}/_cdmrecords/#{pointer}.json"
          migrec = "#{colldir}/_migrecords/#{pointer}.json"
          cleanrec = "#{colldir}/_cleanrecords/#{pointer}.json"
          [cdmrec, migrec, cleanrec].each{ |rec| File.delete(rec) if File.file?(rec) }
          puts "  #{err['collection']}/#{pointer}"
        end
      else
        puts 'No CDM error records to delete.'
      end
    end

    desc 'report_mig_error_records', 'produce report of error migrecords that will not be able to be migrated'
    long_desc <<-LONGDESC
    Runs per collection. It looks at each metadata record in the collection's `_migrecords` directory and reports back the collection, pointer, and any errors present.

    Errors might include records that could not be retrieved from CDM (if not caught with `report/delete_cdm_error_records`, or "top level" records that are pdfpages with no retrievable file.

Writes csv of problem record data (`problem_mig_records.csv`) to CDM working directory.
    LONGDESC
    option :coll, :desc => 'comma-separated list of collection aliases to include in processing', :default => ''
    def report_mig_error_records
      report_path = "#{Cdmtools::CONFIG.wrk_dir}/problem_mig_records.csv"
      File.delete(report_path) if File::exist?(report_path)
      colls = get_colls
      colls.each{ |coll| coll.report_mig_error_records(report_path) }
    end

    desc 'delete_mig_error_records', 'delete missing/error cdmrecords and migrecs, based on problem record report'
    long_desc <<-LONGDESC
    Runs on the problem_cdm_records.csv file created via the `report_error_records` command. If there is no problem_records.csv file in the working directory, it does nothing. Otherwise, it goes through that file and deletes the records listed in it from the _migrecords, and _cleanrecords directories.

    The original CDM records are not deleted, so that they may be examined locally. 
    LONGDESC
    def delete_mig_error_records
      report_path = "#{Cdmtools::CONFIG.wrk_dir}/problem_mig_records.csv"
      if File.file?(report_path)
        puts "Records deleted from mig, clean record directories:"
        CSV.read(report_path, headers: true).each do |err|
          colldir = "#{Cdmtools::CONFIG.wrk_dir}/#{err['collection']}"
          pointer = err['pointer']
          migrec = "#{colldir}/_migrecords/#{pointer}.json"
          cleanrec = "#{colldir}/_cleanrecords/#{pointer}.json"
          [migrec, cleanrec].each{ |rec| File.delete(rec) if File.file?(rec) }
          puts "  #{err['collection']}/#{pointer}"
        end
      else
        puts 'No mig error records to delete.'
      end
    end

        desc 'finalize_migration_records', 'set `migfiletype` field and changes `{}` values to `\'\'` values in `_migrecords` directory for all records in all collections'
    long_desc <<-LONGDESC
    `exe/cdm finalize_migration_records` runs per collection. It looks at each metadata record in the collection's `_migrecords` directory.

    It adds a `migfiletype` field consisting of the file suffix of the file given in the `find` field.

    If the `migfiletype` field value = 'url', then the `migobjcategory` value is changed to 'external media'
    LONGDESC
    option :coll, :desc => 'comma-separated list of collection aliases to include in processing', :default => ''
    def finalize_migration_records
      colls = get_colls
      colls.each{ |coll| coll.finalize_migration_records }
    end

    desc 'get_thumbnails', 'downloads thumbnails for specified collection(s) or all collections'
    long_desc <<-LONGDESC
    `exe/cdm get_thumbnails --coll abc` will download thumbnails for the collection with alias `abc`

    `exe/cdm get_thumbnails --coll abc,def,etc` will download thumbnails for the collections with aliases `abc`, `def`, and `etc`

    `exe/cdm get_thumbnails` will download thumbnails for all collections

    For each collection processed, a `thumbnails` directory with be created in the collection_directory. Thumbnails are saved with the CDM object/page pointer as the filename.
    LONGDESC
    option :coll, :desc => 'comma-separated list of collection aliases to include in processing', :default => ''
    def get_thumbnails
      colls = get_colls
      colls.each{ |coll| coll.get_thumbnails }
    end

    desc 'harvest_objects', 'downloads objects from CDM'
    long_desc <<-LONGDESC
    `exe/cdm harvest_objects` will download all objects for all collections

    For each collection processed, an `_objects` directory is created in the collection_directory. Objects are saved with the CDM object/page pointer/record_id as the filename.
    LONGDESC
    option :coll, :desc => 'comma-separated list of collection aliases to include in processing', :default => ''
    def harvest_objects
      colls = get_colls
      colls.each{ |coll| coll.harvest_objects }
    end

    desc 'report_object_stats', 'prints to screen the number of number and type of objects in each collection'
    long_desc <<-LONGDESC
    `exe/cdm report_object_stats` displays number and type of objects in each collection.
    LONGDESC
    option :coll, :desc => 'comma-separated list of collection aliases to include in processing', :default => ''
    def report_object_stats
      colls = get_colls
      colls.each{ |coll| coll.report_object_stats }
    end

    desc 'print_object_hash', 'prints to screen the object hash -- for debugging'
    option :coll, :desc => 'comma-separated list of collection aliases to include in processing', :default => ''
    def print_object_hash
      colls = get_colls
      colls.each{ |coll| coll.print_object_hash }
    end

    desc 'report_object_file_counts', 'prints to screen the number of object files harvested for each collection'
    long_desc <<-LONGDESC
    `exe/cdm report_object_file_counts` displays count of object files you've harvested for each collection.
    LONGDESC
    option :coll, :desc => 'comma-separated list of collection aliases to include in processing', :default => ''
    def report_object_file_counts
      colls = get_colls
      colls.each{ |coll| coll.report_object_counts }
    end

    desc 'report_object_count_totals', 'prints to screen the total number of objects for collections'
    long_desc <<-LONGDESC
    `exe/cdm report_object_count_totals` displays total count of objects for the collections specified.

    It gives the number of simple objects, the number of compound child objects, and the sum of both.
    LONGDESC
    option :coll, :desc => 'comma-separated list of collection aliases to include in processing', :default => ''
    def report_object_count_totals
      colls = get_colls
      simple = []
      child = []
      colls.each{ |coll|
        coll.report_object_totals.each{ |type, ct|
          simple << ct if type == 'simple'
          child << ct if type == 'children'
        }
      }

      simplect = simple.sum
      childct = child.sum

      puts "#{simplect} simple objects"
      puts "#{childct} compound child objects"
      puts "#{simplect + childct} total objects"

      puts "NOTES:"
      puts "If Document-PDF occurs with cdmprintpdf=1, this is counted as 1 simple object. The child pages are not counted."
      puts "If there are any metadata-only records, they are not counted."
    end

    desc 'report_object_filesize_mismatches', 'prints to screen the collection alias/pointers for harvested objects with filesize mismatches'
    long_desc <<-LONGDESC
    `exe/cdm report_object_filesize_mismatches` works for simple objects because the cdmfilesize field in the record generally matches the actual harvested filesize. 

    It does not work for Document-PDF files because the cdmfilesize field doesn't reflect the size of the printable PDF object we download.
    LONGDESC
    option :coll, :desc => 'comma-separated list of collection aliases to include in processing', :default => ''
    def report_object_filesize_mismatches
      colls = get_colls
      colls.each{ |coll| coll.report_object_filesize_mismatches }
    end

    desc 'report_cumulative_filesizes', 'prints the cumulative filesize of specified collection(s)'
    long_desc <<-LONGDESC
    `exe/cdm report_cumulative_filesizes` sums the cdmfilesize field from all records for non-pdf simple objects and all child objects.

    It does not work for Document-PDF files because the cdmfilesize field does not reflect the size of the printable PDF object we download.
      LONGDESC
    option :coll, :desc => 'comma-separated list of collection aliases to include in processing', :default => ''
    def report_cumulative_filesizes
      colls = get_colls
      sizes = []
      colls.each{ |coll| sizes << coll.report_object_size }
      puts "Cumulative object filesize: #{sizes.sum}"
      puts "NOTE: does not include cdmprintpdf documents treated as simple objects"
    end

    desc "harvest_files_from_csv", "harvest files listed in specified CSV file"
    long_desc <<~LONGDESC
      `exe/cdm harvest_files_from_csv` provides a way to harvest a list of files
      outside the structure of a typical cdm migration project.

      The specified CSV must have the following columns: collection, pointer,
      filename.
    LONGDESC
    option :csv, desc: "path to input CSV", required: true
    option :outdir, desc: "path to directory in which to save harvested files",
      required: true
    def harvest_files_from_csv
      csv = File.expand_path(options[:csv])
      if File.exist?(csv)
        begin
          csvdata = CSV.parse(File.open(csv), headers: true,
            header_converters: [:symbol])
        rescue
          puts "Could not parse CSV file"
          exit 0
        end
      else
        puts "CSV file does not exist at #{csv}"
        exit 0
      end

      outdir = File.expand_path(options[:outdir])
      unless Dir.exist?(outdir)
        begin
          FileUtils.mkdir_p(outdir)
        rescue
          puts "#{outdir} directory does not exist and could not be created"
          exit 0
        else
          puts "Created directory: #{outdir}"
        end
      end

      Cdmtools::CsvFileHarvester::Handler.new(
        data: csvdata, outdir: outdir
      ).call
    end
  end
end
