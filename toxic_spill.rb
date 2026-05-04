#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'time'

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

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: toxic_spill.rb [options]"
  opts.separator ""
  opts.separator "Options:"
  opts.on("--my-rank RANK",         "Your hunter rank (e.g. baron)") { |v| options[:my_rank] = v }
  opts.on("--current-level LEVEL",  "Current pollution level (e.g. count)") { |v| options[:current_level] = v }
  opts.on("--direction DIR",        "Pollution direction: rising or falling") { |v| options[:direction] = v }
  opts.on("--next-transition TIME", "Time of next stage change, 24h local (e.g. 18:00 or 'May 6 04:00')") { |v| options[:next_transition] = v }
  opts.on("-h", "--help") { puts opts; exit }
  opts.separator ""
  opts.separator "Valid ranks (low to high):"
  opts.separator "  Hero, Knight, Lord/Lady, Baron/Baroness, Count/Countess,"
  opts.separator "  Duke/Duchess, Grand Duke/Grand Duchess, Archduke/Archduchess"
end.parse!

%i[my_rank current_level direction next_transition].each do |k|
  abort "Error: --#{k.to_s.tr('_', '-')} is required" if options[k].nil?
end

my_rank_idx = parse_rank(options[:my_rank])
abort "Error: Unknown rank '#{options[:my_rank]}'" if my_rank_idx.nil?

current_idx = parse_rank(options[:current_level])
abort "Error: Unknown level '#{options[:current_level]}'" if current_idx.nil?

direction = options[:direction].downcase
abort "Error: --direction must be 'rising' or 'falling'" unless %w[rising falling].include?(direction)

dir = direction == "rising" ? 1 : -1

now    = Time.now
next_t = Time.parse(options[:next_transition])
# For bare HH:MM input, Time.parse anchors to today; nudge forward if past.
# If the user included a date (e.g. "Wed 04:00"), the parse already lands on
# the right day and no adjustment is needed.
if options[:next_transition].match?(/\A\d{1,2}:\d{2}\z/)
  next_t += 86400 if next_t < now
end

# ── Header ───────────────────────────────────────────────────────────────────
can_now   = my_rank_idx >= current_idx
dir_label = direction == "rising" ? "⬆ rising" : "⬇ falling"

next_entry_str = if can_now
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
puts "  Your rank       : #{STAGES[my_rank_idx][:name]}"
puts "  Current level   : #{STAGES[current_idx][:name]} (#{dir_label})"
puts "  Next transition : #{fmt_time(next_t)}"
puts "  Next entry      : #{next_entry_str}"
puts
puts "  #{"Transition time".ljust(24)}  #{"Pollution level".ljust(30)}  Access"
puts "  #{"-" * 24}  #{"-" * 30}  ------"

current_start  = next_t - STAGES[current_idx][:hours] * 3600
current_arrow  = arrow(current_idx, dir)
current_access = can_now ? green("✓  enter") : red("✗  locked")
puts "  #{fmt_time(current_start).ljust(24)}  #{(STAGES[current_idx][:name] + " " + current_arrow).ljust(30)}  #{current_access}  ← now"

# ── Cycle ────────────────────────────────────────────────────────────────────
# Advance through stages in the current direction until we return to the
# starting (stage, direction) pair, completing one full pollution cycle.
idx = current_idx
d   = dir
t   = next_t

loop do
  idx  += d
  stage = STAGES[idx]
  arr = arrow(idx, d)

  access   = my_rank_idx >= idx ? green("✓  enter") : red("✗  locked")

  puts "  #{fmt_time(t).ljust(24)}  #{(stage[:name] + " " + arr).ljust(30)}  #{access}"

  t += stage[:hours] * 3600
  d  = -d if idx == 0 || idx == STAGES.length - 1

  break if idx == current_idx && d == dir
end
