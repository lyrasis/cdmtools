# standard library
require 'csv'
require 'json'
require 'logger'
require 'net/http'
require 'yaml'

# external gems
require 'progressbar'
require 'pry'
require 'thor'

module Cdmtools
  autoload :CdmFieldGetter, 'cdmtools/cdm_field_getter'

  # given a collection, sends all the relevant ChildInfoMerger commands
  autoload :ChildInfoMergeHandler, 'cdmtools/child_info_merge_handler'

  # merges parent data into child record 
  autoload :ChildInfoMerger, 'cdmtools/child_info_merger'
  
  # uses migchildptrs field in parent record to call Cdmtools::RecordGetter for each child
  autoload :ChildRecordGetter, 'cdmtools/child_record_getter'

  # uses api call
  autoload :CollDataGetter, 'cdmtools/coll_data_getter'

  # if initialized without any coll aliases, produces array of all colls
  # if initialized with coll aliases, produces array of just those colls
  # uses local .json if present, otherwise calls API
  # to get array of colls, do: Cdmtools::CollDataParser.new.aliases
  autoload :CollDataParser, 'cdmtools/coll_data_parser'

  # collection object with many methods for running per-collection processes
  autoload :Collection, 'cdmtools/collection'

  # uses cdminspect to create _pointer.txt files listing coll pointers
  autoload :CollPointerGetter, 'cdmtools/coll_pointer_getter'

  autoload :CommandLine, 'cdmtools/command_line'

  
  # given collection object and pointer, looks for object info json for pointer
  # if found, tags record with local field indicating compoundness, compound object type,
  #  and child pointer list
  # if not found, tags record with local field indicating simpleness and object type
  autoload :CompoundObjInfoMerger, 'cdmtools/compound_obj_info_merger'

  autoload :ConfigReader, 'cdmtools/config_reader'

  # uses API call to grab DC field spec from CDM
  autoload :DcMappingGetter, 'cdmtools/dc_mapping_getter'
  
  # given collection object, runs through all migration records and adds `migfiletype`
  #  field to each
  autoload :MigrecFinalizer, 'cdmtools/migrec_finalizer'

  autoload :JsonCsvWriter, 'cdmtools/json_csv_writer'

  autoload :LOG, 'cdmtools/log'

  # given collection object and pointer, calls dmGetCompoundObjectInfo
  # if object is compound, will write the compound object info to JSON file
  autoload :ObjectInfoGetter, 'cdmtools/object_info_getter'

  autoload :ObjectHarvestHandler, 'cdmtools/object_harvest_handler'
  
  # given collection object and pointer, calls dmGetItemInfo, writes record to JSON
  autoload :RecordGetter, 'cdmtools/record_getter'

  autoload :Record, 'cdmtools/record'
  autoload :Migrecord, 'cdmtools/record'

  autoload :VERSION, 'cdmtools/version'

  # silly way to make Cdmtools::WRKDIR act like a global variable
  autoload :WRKDIR, 'cdmtools/wrk_dir'

end
