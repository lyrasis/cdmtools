require 'cdmtools'

module Cdmtools
  class ConfigReader
    attr_reader :wrk_dir
    attr_reader :api_base
    attr_reader :util_base
    attr_reader :cdminspect
    attr_reader :colls
    attr_reader :logfile
    attr_reader :sleeptime
    attr_reader :reporting_ignore_field_prefixes
    attr_reader :cleanup_ignore_field_prefixes
    attr_reader :mv_delimiter
    attr_reader :not_multivalued
    attr_reader :replacements

    def initialize(config: 'config/config.yaml')
      config = YAML.load_file(
        File.expand_path(ENV.fetch('CDMTOOLS_CFG', config))
      )
      @wrk_dir = config['wrk_dir']
      @api_base = config['cdm_ws_url']
      @util_base = config['utils_url']
      @cdminspect = config['cdminspectpath']
      @colls = config['collections']
      @logfile = config['logfile']
      @sleeptime = config['sleeptime']
      @reporting_ignore_field_prefixes = config['reporting_ignore_field_prefixes']
      @cleanup_ignore_field_prefixes = config['cleanup_ignore_field_prefixes']
      @mv_delimiter = config['mv_delimiter']
      @not_multivalued = config['not_multivalued']
      @replacements = config['replacements']
    end
  end
end
