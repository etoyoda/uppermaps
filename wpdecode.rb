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
    @sdb = nil
  end

  def subset_flush
    return unless @sdb
    stnid = @sdb.values_at('001001', '001002').join
    @db[stnid] = @sdb
    @sdb = nil
  end

  def subset_ini
    subset_flush
    @sdb = { "001001" => "//", "001002" => "///" }
  end

  def subset_data desc, val
    case desc
    when /^(00100[12]|00[56]002|007001)$/ then
      @sdb[desc] = val
    end
  end

  def scanfp fp
    fp.each_line {|line|
      case line.chomp
      when /^DATASUBSET \d+ :/ then
        subset_ini
      when /^(0\d{5}) {R=(\d+)\.(\d+)}(?:{\S*})? / then
      when /^(0\d{5}) {R=(\d+)} / then
      when /^(0\d{5}) / then
        subset_data($1, $')
      end
    }
    subset_flush
  end

  def scanfile filename
    File.open(filename) {|fp| scanfp(fp) }
    self
  end

  def scanfiles args
    args.each {|arg| scanfile(arg) }
    self
  end

  def dump
    $stdout.write(JSON.pretty_generate(@db))
  end

end

WPDecode.new.scanfiles(ARGV).dump
