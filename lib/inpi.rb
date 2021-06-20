# frozen_string_literal: true

require 'inpi/act'
require 'inpi/balance_sheet'
require 'inpi/configuration'
require 'inpi/http'
require 'inpi/seized_balance_sheet'
require 'inpi/version'

class Inpi
  include Singleton

  def self.config
    Configuration.instance
  end

  def self.configure
    yield config
  end

  def self.balance_sheets(siren)
    BalanceSheet.list(siren)
  end

  def self.seized_balance_sheets(siren)
    SeizedBalanceSheet.list(siren)
  end

  def self.acts(siren)
    Act.list(siren)
  end
end
