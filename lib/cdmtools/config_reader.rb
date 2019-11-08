require 'cdmtools'

module Cdmtools
  class ConfigReader
    attr_reader :wrk_dir
    attr_reader :api_base
    attr_reader :cdminspect
    attr_reader :logfile
    attr_reader :sleeptime
    attr_reader :ignore_field_prefixes
    attr_reader :mv_delimiter
    attr_reader :not_multivalued
    attr_reader :replacements
    
    def initialize
      config = YAML.load_file('config/config.yaml')
      @wrk_dir = config['wrk_dir']
      @api_base = config['cdm_ws_url']
      @cdminspect = config['cdminspectpath']
      @logfile = config['logfile']
      @sleeptime = config['sleeptime']
      @ignore_field_prefixes = config['ignore_field_prefixes']
      @mv_delimiter = config['mv_delimiter']
      @not_multivalued = config['not_multivalued']
      @replacements = config['replacements']
    end
  end

  CONFIG = Cdmtools::ConfigReader.new
end
