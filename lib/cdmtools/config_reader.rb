require 'cdmtools'

module Cdmtools
  class ConfigReader
    attr_reader :wrk_dir
    attr_reader :api_base
    attr_reader :cdminspect
    attr_reader :logfile
    attr_reader :sleeptime
    attr_reader :ignore_field_prefixes
    
    def initialize
      config = YAML.load_file('config/config.yaml')
      @wrk_dir = config['wrk_dir']
      @api_base = config['cdm_ws_url']
      @cdminspect = config['cdminspectpath']
      @logfile = config['logfile']
      @sleeptime = config['sleeptime']
      @ignore_field_prefixes = config['ignore_field_prefixes']
    end
  end

  CONFIG = Cdmtools::ConfigReader.new
end
