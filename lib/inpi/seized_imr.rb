# frozen_string_literal: true

require 'nokogiri'
require 'stringio'
require 'tempfile'
require 'zip'

require 'inpi/rncs_server_error'

module NokogiriRefinements
  refine Nokogiri::XML::Node do
    def to_hash
      if text?
        text.presence
      elsif element?
        elements = children.map(&:to_hash).compact
        elements = if elements.size == 1
                     elements.first
                   else
                     elements.each_with_object({}) do |item, acc|
                       key = item.keys.first
                       value = item.values.first

                       acc[key] = if acc.key?(key)
                                    case acc[key]
                                    when Array
                                      acc[key] + [value]
                                    else
                                      [value]
                                    end
                                  else
                                    value
                                  end

                     end
                   end

        {
          name => elements
        }
      end
    end

    alias_method :to_h, :to_hash
  end

  refine Nokogiri::XML::Document do
    def to_hash
      root.to_hash
    end

    alias_method :to_h, :to_hash
  end
end

class Inpi
  class SeizedImr
    attr_reader :sirens

    using NokogiriRefinements

    def initialize(sirens)
      @sirens = sirens
    end

    def download
      sirens_list = case sirens
                    when Array
                      sirens.join(',')
                    else
                      sirens.to_s
                    end

      response = Inpi::HTTP.get('/services/diffusion/imrs-saisis/get', query: { listeSirens: sirens_list })

      raise Inpi::RncsServerError, response unless response.is_a?(Net::HTTPSuccess)

      tmp_file = Tempfile.new(%w[inpi .zip])
      tmp_file.binmode
      tmp_file.write(response.body)
      tmp_file.flush
      tmp_file.rewind
      tmp_file
    end

    def extract
      extract_response(download) do |zip_file, response|
        imrs = {}

        response[:listeSirens].each do |data|
          data.each do |siren, filenames|
            imrs[siren.to_s] ||= {}

            filenames.each do |filename|
              _, _, date, = File.basename(filename, '.zip').split('_')
              imr = extract_imr(zip_file.find_entry(filename))

              next unless imr

              imrs[siren.to_s][date] = imr
            end
          end
        end
        response[:listeSirensNonFournis].each { |siren| imrs[siren.to_s] ||= {} }

        imrs
      end
    end

    private

    def extract_response(io)
      Zip::File.open(io) do |zip_file|
        entry = zip_file.find_entry('Response.json').get_input_stream
        response = JSON(entry.read, symbolize_names: true)

        yield zip_file, response
      end
    end

    def extract_imr(response_entry)
      imr = {}

      Zip::File.open_buffer(response_entry.get_input_stream.read) do |zip_file|
        filename = "#{File.basename(response_entry.name, '.zip')}.xml"
        entry = zip_file.find_entry(filename)
        xml = Nokogiri::XML(entry.get_input_stream.read)
        imr = xml.to_h
      end

      imr
    end
  end
end
