# frozen_string_literal: true

require 'tempfile'

require 'inpi/rncs_server_error'

class Inpi
  class Document
    attr_reader :id

    def initialize(id)
      @id = id
    end

    def download
      response = Inpi::HTTP.get('/services/diffusion/document/get', query: { listeIdFichier: id })

      raise Inpi::RncsServerError, response unless response.is_a?(Net::HTTPSuccess)

      tmp_file = Tempfile.new(%w[inpi .zip])
      tmp_file.binmode
      tmp_file.write(response.body)
      tmp_file.flush
      tmp_file.rewind
      tmp_file
    end
  end
end
