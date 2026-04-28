#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates source locale YAML files for Lokalise compatibility.
#
# Lokalise's YAML parser rejects plain (unquoted) scalar values whose resolved
# string contains an HTML tag with a single-quoted attribute, e.g.:
#
#   key: Click <a href='url' target='_blank'>here</a>
#
# A line-by-line grep misses multi-line implicit-folded values where the
# offending HTML lives on a continuation line:
#
#   key: <p>Step one.</p>
#     <p>See <a href='https://example.com' target='_blank'>here</a>.</p>
#
# We use Ruby's built-in Psych YAML parser to inspect resolved scalar values
# and their style. Only plain (unquoted) scalars are flagged — double-quoted,
# single-quoted, and block scalars are accepted by Lokalise without issue.

require "psych"
require "find"

HTML_SQ_ATTR = /< [^>]* '/x

locale_paths = ENV.fetch("LOCALE_PATHS", "config/locales/en").split("\n").map(&:strip).reject(&:empty?)
dry_run      = ENV.fetch("DRY_RUN", "false").strip.downcase == "true"

violation_count = 0
violation_lines = []

locale_paths.each do |locale_path|
  unless Dir.exist?(locale_path)
    puts "WARNING: Directory '#{locale_path}' not found, skipping."
    next
  end

  puts "Scanning #{locale_path}..."

  files = []
  Find.find(locale_path) { |f| files << f if f.end_with?(".yml") }
  files.sort!

  files.each do |filepath|
    content = File.read(filepath, encoding: "utf-8")

    file_violations = []

    stream = Psych.parse_stream(content)
    stream.grep(Psych::Nodes::Scalar).each do |node|
      next unless node.style == Psych::Nodes::Scalar::PLAIN
      next unless HTML_SQ_ATTR.match?(node.value)

      line_num = node.start_line + 1
      preview  = node.value.gsub("\n", " ")[0, 120]
      file_violations << "    #{line_num}: #{preview}"
    end

    if file_violations.any?
      violation_lines << "  #{filepath}:"
      violation_lines.concat(file_violations)
      violation_count += file_violations.size
    end
  rescue Psych::SyntaxError => e
    warn "  WARNING: Could not parse #{filepath}: #{e.message}"
  end
end

if violation_count == 0
  puts "All locale files are Lokalise-compatible."
  exit 0
end

puts
puts "#{violation_count} Lokalise-incompatible value(s) found:"
puts
violation_lines.each { |line| puts line }
puts
puts "Plain unquoted YAML values containing HTML with single-quoted attributes"
puts "cause 400 errors when uploaded to Lokalise. Wrap the value in double quotes"
puts "or use a block scalar:"
puts
puts "  Bad:  key: Click <a href='url' target='_blank'>here</a>"
puts "  Good: key: \"Click <a href='url' target='_blank'>here</a>\""
puts "  Good: key: |-"
puts "          Click <a href='url' target='_blank'>here</a>"

if dry_run
  puts
  puts "(dry_run=true: not failing the workflow)"
  exit 0
end

exit 1
