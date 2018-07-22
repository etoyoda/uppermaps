#!/usr/bin/ruby

# reads output of Env Canada's bufr_decoder
# writes json

require 'json'

class WPDecode

  StdLevels = {
    925 => 800,
    # WMO Manual on Codes, Volume II, Reg. 2/32.1
    850 => 1500,
    700 => 3100,
    500 => 5800,
    400 => 7600,
    300 => 9500,
    250 => 10600,
    200 => 12300,
    150 => 14100,
    100 => 16600,
    70 => 18500,
    50 => 20500,
    30 => 24000,
    20 => 26500,
    10 => 31000
  }

  def initialize
    @db = {}
  end

  def run args
    args.each {|arg|
      File.open(arg) {|fp|
        
      }
    }
  end

end

WPDecode.new.run(ARGV)
