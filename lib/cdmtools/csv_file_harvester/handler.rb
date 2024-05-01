require "cdmtools"
require_relative "../file_harvester"

module Cdmtools
  module CsvFileHarvester
    class Handler
      # @param data [CSV::Table]
      # @param outdir [String]
      def initialize(data:, outdir:)
        @data = data
        @outdir = outdir
        @row_ct = data.length
        @progressbar = ProgressBar.create(
          title: "Harvesting files",
          starting_at: 0,
          total: row_ct,
          format: "%a %E %B %c %C %p%% %t"
        )
        @harvester = Cdmtools::FileHarvester.new(mode: :return_err)
        @reportpath = File.join(outdir, "_report.csv")
        @report = CSV.open(
          reportpath,
          "w",
          write_headers: true,
          headers: [data.headers, "status"].flatten
        )
        @errs = 0
      end

      def call
        data.each do |row|
          harvest_row(row)
          progressbar.increment
        end
        report.close
        puts summary
      end

      private

      attr_reader :data, :outdir, :row_ct, :progressbar, :harvester, :report,
        :reportpath, :errs

      def harvest_row(row)
        result = harvester.call(url: url(row), write_to: outpath(row))
        (result == :success) ? handle_success(row) : handle_failure(row, result)
      end

      def handle_success(row)
        row << {status: "success"}
        report << row
      end

      def handle_failure(row, result)
        message = ["failure", result[0], result[1].to_s].join(": ")
        row << {status: message}
        report << row
        @errs += 1
      end

      def summary
        if errs == 0
          "All #{row_ct} files harvested successfully"
        else
          successes = row_ct - errs
          "#{successes} files harvested successfully. #{errs} failures. "\
            "See #{reportpath} for details"
        end
      end

      def url(row)
        Cdmtools::Helpers.object_url(
          collection: row[:collection],
          pointer: row[:pointer],
          filename: row[:filename]
        )
      end

      def outpath(row) = File.join(outdir, row[:filename])
    end
  end
end
