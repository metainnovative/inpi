# frozen_string_literal: true

require 'tempfile'

require 'inpi/document'
require 'inpi/rncs_server_error'

class Inpi
  class SeizedBalanceSheet
    attr_reader :data

    def initialize(data: nil)
      @data = data
    end

    def self.list(siren)
      response = Inpi::HTTP.get('/services/diffusion/bilans-saisis/find', json_response: true, query: { siren: siren })

      raise Inpi::RncsServerError, response unless response.is_a?(Net::HTTPSuccess)

      response.body_parsed.map do |data|
        new(data: data)
      end
    end

    def document
      @document ||= Inpi::Document.new(data[:id_fichier])
    end
  end
end
