#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'time'
require 'yaml'

STAGES = [
  { name: "Hero",                     hours: 30 },
  { name: "Knight",                   hours: 16 },
  { name: "Lord/Lady",                hours: 18 },
  { name: "Baron/Baroness",           hours: 18 },
  { name: "Count/Countess",           hours: 24 },
  { name: "Duke/Duchess",             hours: 24 },
  { name: "Grand Duke/Grand Duchess", hours: 24 },
  { name: "Archduke/Archduchess",     hours: 24 },
].freeze

RANK_ALIASES = {
  "hero"          => 0,
  "knight"        => 1,
  "lord"          => 2, "lady"          => 2,
  "baron"         => 3, "baroness"      => 3,
  "count"         => 4, "countess"      => 4,
  "duke"          => 5, "duchess"       => 5,
  "grand duke"    => 6, "grand duchess" => 6,
  "archduke"      => 7, "archduchess"   => 7,
}.freeze

CONFIG_PATH = File.join(__dir__, ".toxic_spill.yml")

def parse_rank(str)
  RANK_ALIASES[str&.downcase&.strip]
end

def fmt_time(t)
  t.strftime("%a %b %e at %I:%M %p")
end

def red(str)   = "\e[31m#{str}\e[0m"
def green(str) = "\e[32m#{str}\e[0m"

def arrow(idx, d)
  case idx
  when 0                    then "⬇⬆"
  when STAGES.length - 1   then "⬆⬇"
  else d == 1               ? "⬆" : "⬇"
  end
end

def load_config
  return nil unless File.exist?(CONFIG_PATH)
  YAML.load_file(CONFIG_PATH)
rescue StandardError
  nil
end

def save_config(stage_idx, direction, stage_start)
  File.write(CONFIG_PATH, {
    "stage_idx"   => stage_idx,
    "direction"   => direction,
    "stage_start" => stage_start.iso8601
  }.to_yaml)
end

# Walk forward stage-by-stage from a stored reference until we reach the
# stage that contains the current moment.  direction is stored as the
# incoming direction (the one that brought pollution to stage_idx); this
# mirrors what the cycle loop in the original script uses.
def advance_to_now(stage_idx, direction, stage_start)
  t   = stage_start
  idx = stage_idx
  d   = direction
  now = Time.now

  while t + STAGES[idx][:hours] * 3600 <= now
    t  += STAGES[idx][:hours] * 3600
    d   = -d if idx == 0 || idx == STAGES.length - 1
    idx += d
  end

  { current_idx: idx, dir: d, next_transition: t + STAGES[idx][:hours] * 3600 }
end

def prompt_rank(prompt = nil, skippable: false)
  puts prompt if prompt
  STAGES.each_with_index { |s, i| puts "  #{i + 1}) #{s[:name]}" }
  hint = skippable ? "Enter number (1-#{STAGES.length}), or Enter to skip: " \
                   : "Enter number (1-#{STAGES.length}): "
  loop do
    print hint
    input = $stdin.gets&.strip
    return nil if skippable && (input.nil? || input.empty?)
    n = input.to_i
    return STAGES[n - 1][:name].split("/").first.strip.downcase if n >= 1 && n <= STAGES.length
    puts "  Please enter a number between 1 and #{STAGES.length}."
  end
end

def setup_reference
  puts "One-time setup — record a known reference point"
  puts "─" * 48
  puts "The script will calculate the current level from here automatically on future runs."
  puts

  ref_level = prompt_rank("Current pollution level?")
  ref_idx   = parse_rank(ref_level)
  puts

  puts "Pollution direction?"
  puts "  1) Rising ⬆"
  puts "  2) Falling ⬇"
  ref_dir = loop do
    print "Enter number (1-2): "
    case $stdin.gets&.strip
    when "1" then break 1
    when "2" then break -1
    else puts "  Please enter 1 or 2."
    end
  end
  puts

  puts "Next stage transition time? (e.g. 18:00 or 'May 6 04:00')"
  next_t = loop do
    print "> "
    v = $stdin.gets&.strip
    next puts "  Enter a time." if v.nil? || v.empty?
    begin
      t = Time.parse(v)
      t += 86400 if v.match?(/\A\d{1,2}:\d{2}\z/) && t < Time.now
      break t
    rescue ArgumentError
      puts "  Couldn't parse that — try '18:00' or 'May 6 04:00'"
    end
  end
  puts

  save_config(ref_idx, ref_dir, next_t - STAGES[ref_idx][:hours] * 3600)
  puts "Reference saved to #{CONFIG_PATH}"
  puts
end

def interactive_mode(reset_ref: false, preset_rank: nil)
  config = reset_ref ? nil : load_config

  if config.nil?
    setup_reference
    config = load_config
  end

  state = advance_to_now(config["stage_idx"], config["direction"],
                         Time.parse(config["stage_start"]))

  my_rank = if preset_rank
    preset_rank
  else
    puts "Your hunter rank? (optional — shows entry access when provided)"
    r = prompt_rank(skippable: true)
    puts
    r
  end

  dir_str = state[:dir] == 1 ? "rising" : "falling"
  {
    my_rank:         my_rank,
    current_level:   STAGES[state[:current_idx]][:name].split("/").first.strip.downcase,
    direction:       dir_str,
    next_transition: state[:next_transition].strftime("%b %-d %Y %H:%M")
  }
end

options   = {}
reset_ref = false

OptionParser.new do |opts|
  opts.banner = "Usage: toxic_spill.rb [options]"
  opts.separator ""
  opts.separator "Options:"
  opts.on("--my-rank RANK",         "Your hunter rank (optional; e.g. baron)") { |v| options[:my_rank] = v }
  opts.on("--current-level LEVEL",  "Current pollution level — skipped if a reference is saved") { |v| options[:current_level] = v }
  opts.on("--direction DIR",        "Pollution direction: rising or falling — skipped if a reference is saved") { |v| options[:direction] = v }
  opts.on("--next-transition TIME", "Time of next stage change (e.g. 18:00 or 'May 6 04:00') — skipped if a reference is saved") { |v| options[:next_transition] = v }
  opts.on("--reset",                "Forget saved reference and re-run setup") { reset_ref = true }
  opts.on("-h", "--help") { puts opts; exit }
  opts.separator ""
  opts.separator "Valid ranks (low to high):"
  opts.separator "  Hero, Knight, Lord/Lady, Baron/Baroness, Count/Countess,"
  opts.separator "  Duke/Duchess, Grand Duke/Grand Duchess, Archduke/Archduchess"
end.parse!

if reset_ref || !options.key?(:current_level)
  options = interactive_mode(reset_ref: reset_ref, preset_rank: options[:my_rank])
else
  %i[current_level direction next_transition].each do |k|
    abort "Error: --#{k.to_s.tr('_', '-')} is required" if options[k].nil?
  end
end

my_rank_idx = options[:my_rank] ? parse_rank(options[:my_rank]) : nil
abort "Error: Unknown rank '#{options[:my_rank]}'" if options[:my_rank] && my_rank_idx.nil?

current_idx = parse_rank(options[:current_level])
abort "Error: Unknown level '#{options[:current_level]}'" if current_idx.nil?

direction = options[:direction].downcase
abort "Error: --direction must be 'rising' or 'falling'" unless %w[rising falling].include?(direction)

dir = direction == "rising" ? 1 : -1

now    = Time.now
next_t = Time.parse(options[:next_transition])
if options[:next_transition].match?(/\A\d{1,2}:\d{2}\z/)
  next_t += 86400 if next_t < now
end

# ── Header ───────────────────────────────────────────────────────────────────
can_now   = my_rank_idx && my_rank_idx >= current_idx
dir_label = direction == "rising" ? "⬆ rising" : "⬇ falling"

next_entry_str = if my_rank_idx.nil?
  nil
elsif can_now
  "now"
else
  si, sd, st = current_idx, dir, next_t
  found = nil
  loop do
    si += sd
    if my_rank_idx >= si
      found = fmt_time(st)
      break
    end
    st += STAGES[si][:hours] * 3600
    sd  = -sd if si == 0 || si == STAGES.length - 1
    break if si == current_idx && sd == dir
  end
  found || "not this cycle"
end

puts "Toxic Spill — Entry Calculator"
puts "  Your rank       : #{STAGES[my_rank_idx][:name]}" if my_rank_idx
puts "  Current level   : #{STAGES[current_idx][:name]} (#{dir_label})"
puts "  Next transition : #{fmt_time(next_t)}"
puts "  Next entry      : #{next_entry_str}" if next_entry_str
puts

if my_rank_idx
  puts "  #{"Transition time".ljust(24)}  #{"Pollution level".ljust(30)}  Access"
  puts "  #{"-" * 24}  #{"-" * 30}  ------"
else
  puts "  #{"Transition time".ljust(24)}  Pollution level"
  puts "  #{"-" * 24}  #{"-" * 30}"
end

current_start  = next_t - STAGES[current_idx][:hours] * 3600
current_arrow  = arrow(current_idx, dir)
current_suffix = my_rank_idx ? "  #{can_now ? green("✓  enter") : red("✗  locked")}" : ""
puts "  #{fmt_time(current_start).ljust(24)}  #{(STAGES[current_idx][:name] + " " + current_arrow).ljust(30)}#{current_suffix}  ← now"

# ── Cycle ────────────────────────────────────────────────────────────────────
idx = current_idx
d   = dir
t   = next_t

loop do
  idx  += d
  stage = STAGES[idx]
  arr   = arrow(idx, d)

  row_suffix = my_rank_idx ? "  #{my_rank_idx >= idx ? green("✓  enter") : red("✗  locked")}" : ""
  puts "  #{fmt_time(t).ljust(24)}  #{(stage[:name] + " " + arr).ljust(30)}#{row_suffix}"

  t += stage[:hours] * 3600
  d  = -d if idx == 0 || idx == STAGES.length - 1

  break if idx == current_idx && d == dir
end
