#!/usr/bin/ruby

# reads output of Env Canada's bufr_decoder
# writes json

require 'json'

class WPDecode

  STD_LEVELS = {
    # original
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
    subset = @sdb.select {|k,v| /^(lat|lon|hmsl)$/ === k }
    for iter in @sdb.keys.grep(/^R=/)
      rt = Time.gm(*@sdb[iter].values_at(*%w(rty rtm rtd rth rtn)))
      rt = rt.strftime('%Y-%m-%dT%H:%M:%SZ')
      subset[rt] = @sdb[iter].select {|k,v| /^R=/ === k }
    end
    stnid = @sdb.values_at('001001', '001002').join
    @db[stnid] = subset
    @sdb = nil
  end

  def subset_ini
    subset_flush
    @sdb = { "001001" => "//", "001002" => "///" }
  end

  def subset_data desc, val
    return if val == 'MSNG'
    case desc
    when /^00100[12]$/ then @sdb[desc] = val
    when '005002' then @sdb['lat'] = val.to_f
    when '006002' then @sdb['lon'] = val.to_f
    when '007001' then @sdb['hmsl'] = val.to_i
    end
  end

  def pulse_data iter, desc, val
    return if val == 'MSNG'
    @sdb[iter] = {} unless @sdb[iter]
    case desc
    when '004001' then @sdb[iter]['rty'] = val.to_i
    when '004002' then @sdb[iter]['rtm'] = val.to_i
    when '004003' then @sdb[iter]['rtd'] = val.to_i
    when '004004' then @sdb[iter]['rth'] = val.to_i
    when '004005' then @sdb[iter]['rtn'] = val.to_i
    end
  end

  def point_data iter, iter2, desc, val
    return if val == 'MSNG'
    unless @sdb[iter] then
      $stderr.puts "undated pulse skipped" if $DEBUG
    end
    @sdb[iter][iter2] = {} unless @sdb[iter][iter2]
    case desc
    when '011003' then @sdb[iter][iter2]['u'] = val.to_f
    when '011004' then @sdb[iter][iter2]['v'] = val.to_f
    when '011006' then @sdb[iter][iter2]['w'] = val.to_f
    when '021030' then @sdb[iter][iter2]['signal'] = val.to_f
    when '007006' then @sdb[iter][iter2]['hagl'] = val.to_i
    end
  end

  def scanfp fp
    fp.each_line {|line|
      case line.chomp
      when /^DATASUBSET \d+ :/ then
        subset_ini
      when /^031/ then :do_nothing
      when /^(0\d{5}) {((R=\d+)\.\d+)}(?:{\S*})? / then
        point_data($3, $2, $1, $')
      when /^(0\d{5}) {(R=\d+)} / then
        pulse_data($2, $1, $')
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
    $stdout.write(JSON.pretty_generate(@db)) if $DEBUG or $VERBOSE
    self
  end

  def find_reftime
    rtmax = nil
    @db.each {|stnid,stndata|
      stndata.each {|rt,pulse|
        next unless /^\d/ === rt
	if rtmax then
	  rtmax = rt if rt > rtmax
	else
	  rtmax = rt
	end
      }
    }
    rtmax
  end

  def find_gph ztarget
    r = {}
    z_allow = 200 + ztarget * 0.02
    @db.each {|stnid,stndata|
      hmsl = stndata['hmsl']
      found = nil
      stndata.each {|rt,pulse|
        next unless /^\d/ === rt
        pulse.each {|levid,levdata|
	  next unless levdata['u'] and levdata['v']
	  levhmsl = levdata['hagl'] + hmsl
	  zdiff = (levhmsl - ztarget).abs
	  next if zdiff > z_allow
	  if not found or zdiff < found['zdiff']
	    found = levdata.dup
	    found['hmsl'] = levhmsl
	    found['zdiff'] = zdiff
	    found['rt'] = rt
	    found['lat'] = stndata['lat']
	    found['lon'] = stndata['lon']
	    ff = sprintf('%0.1f', Math::hypot(found['u'], found['v']))
	    found['ff'] = ff.to_f
	    dd = (Math::atan2(-found['u'], -found['v']) / Math::PI * 180 + 0.5).floor
	    dd += 360 if dd <= 0
	    found['dd'] = dd
	  end
	}
      }
      r[stnid] = found if found
    }
    r
  end

  def stdlevels
    r = { 'reftime' => find_reftime }
    STD_LEVELS.each {|p,ztarget|
      buf = find_gph(ztarget)
      next if buf.empty?
      pname = "isobar.#{p}"
      r[pname] = { 'p' => p, 'z_target' => ztarget }
      r[pname]['data'] = buf
    }
    $stdout.write(JSON.pretty_generate(r))
    self
  end

end

WPDecode.new.scanfiles(ARGV).dump.stdlevels
