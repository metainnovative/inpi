# frozen_string_literal: true

require 'singleton'

class Inpi
  class Configuration
    include Singleton

    attr_accessor :login
    attr_accessor :password
  end
end
