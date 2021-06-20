# frozen_string_literal: true

class Inpi
  class RncsServerError < StandardError
    attr_reader :response

    def initialize(response)
      @response = response
      super
    end
  end
end
