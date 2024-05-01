module Cdmtools
  class FileHarvester
    # @param mode [:log, :return_err]
    def initialize(mode: :log)
      @mode = mode
    end

    # @param url [String] to send to utils API
    # @param write_to [String] path to directory
    def call(url:, write_to:)
      response = Net::HTTP.get_response(URI(url))
      result = if response.is_a?(Net::HTTPSuccess)
        handle_good_response(response, url, write_to)
      else
        handle_bad_response(response, url)
      end
      sleep(1)
      result
    end

    private

    attr_reader :mode

    def handle_good_response(response, url, write_to)
      written = write_result(response, url, write_to)
      return :success if written == :success
      return if mode == :log

      written
    end

    def handle_bad_response(response, url)
      message = "Could not harvest file: #{url}"
      case mode
      when :log
        Cdmtools::LOG.error(message)
        :error
      when :return_err
        err = "#{response.code} #{response.message}"
        [message, err]
      end
    end

    def write_result(response, url, write_to)
      File.binwrite(write_to, response.body)
    rescue => err
      handle_write_error(url, err)
    else
      :success
    end

    def handle_write_error(url, err)
      message = "Could not write harvested file: #{url}"
      case mode
      when :log
        Cdmtools::LOG.error(message)
        :error
      when :return_err
        [message, err]
      end
    end
  end
end
