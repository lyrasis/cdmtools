require "cdmtools"

module Cdmtools
  module Helpers
    module_function

    def object_url(collection:, pointer:, filename:)
      "#{Cdmtools::CONFIG.util_base}/getfile/"\
        "collection/#{collection}/"\
        "id/#{pointer}/filename/#{filename}"
    end
  end
end
