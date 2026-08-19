#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates source locale YAML files for Lokalise compatibility.
#
# Runs two independent checks against every locale YAML file:
#
# 1. HTML with single-quoted attributes in a plain (unquoted) scalar value.
#
#    Lokalise's YAML parser rejects plain scalar values whose resolved string
#    contains an HTML tag with a single-quoted attribute, e.g.:
#
#      key: Click <a href='url' target='_blank'>here</a>
#
#    A line-by-line grep misses multi-line implicit-folded values where the
#    offending HTML lives on a continuation line:
#
#      key: <p>Step one.</p>
#        <p>See <a href='https://example.com' target='_blank'>here</a>.</p>
#
# 2. Non-string mapping keys.
#
#    YAML 1.1 (which Ruby's Psych parser implements) resolves certain plain
#    (unquoted) scalars to non-string types: true/false/yes/no/on/off (bool),
#    null/~ (nil), bare numbers, and dates. Used as a mapping key, e.g.:
#
#      max_hours:
#        true: "%{count} hour(s)"
#        false: Unlimited
#
#    the keys become literal TrueClass/FalseClass (etc.) objects rather than
#    the strings "true"/"false" — unlike every string key elsewhere in the
#    file. Lokalise's importer expects every translation key to be a string
#    and rejects the entire file with a bare 400 if it isn't, with no more
#    specific error reported. This shipped undetected in a Gusto repo for
#    9+ months before being tracked down (see gws-flows PR #4021) because
#    the CLI and the Lokalise API both return only a generic 400 Bad Request
#    with no indication of which file or key caused it.
#
# We use Ruby's built-in Psych YAML parser (rather than a line-by-line regex)
# to inspect resolved scalar values, their style, and their position in the
# document, since both failure modes can span multiple lines or hide inside
# otherwise-unremarkable-looking keys.

require "psych"
require "psych/scalar_scanner"
require "find"

HTML_SQ_ATTR = /< [^>]* '/x

# Walks a parsed Psych AST and yields every key node that appears in mapping
# (key position), recursing into mapping values and sequence items. Complex
# keys (`? ... : ...`) and merge keys (`<<: *anchor`) are skipped -- they're
# not used in this codebase's locale files and resolving them correctly would
# require full document context that isn't worth the complexity here.
def each_mapping_key_node(node, &block)
  case node
  when Psych::Nodes::Stream, Psych::Nodes::Document
    node.children.each { |child| each_mapping_key_node(child, &block) }
  when Psych::Nodes::Mapping
    node.children.each_slice(2) do |key_node, value_node|
      block.call(key_node)
      each_mapping_key_node(value_node, &block)
    end
  when Psych::Nodes::Sequence
    node.children.each { |child| each_mapping_key_node(child, &block) }
  end
end

def resolve_plain_scalar(scalar_scanner, value)
  scalar_scanner.tokenize(value)
rescue StandardError
  value
end

locale_paths = ENV.fetch("LOCALE_PATHS", "config/locales/en").split("\n").map(&:strip).reject(&:empty?)
dry_run      = ENV.fetch("DRY_RUN", "false").strip.downcase == "true"

scalar_scanner = Psych::ScalarScanner.new(Psych::ClassLoader.new)

html_violation_count = 0
key_violation_count  = 0
html_violation_lines = []
key_violation_lines  = []

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
    stream = Psych.parse_stream(content)

    file_html_violations = []
    stream.grep(Psych::Nodes::Scalar).each do |node|
      next unless node.style == Psych::Nodes::Scalar::PLAIN
      next unless HTML_SQ_ATTR.match?(node.value)

      line_num = node.start_line + 1
      preview  = node.value.gsub("\n", " ")[0, 120]
      file_html_violations << "    #{line_num}: #{preview}"
    end

    file_key_violations = []
    each_mapping_key_node(stream) do |key_node|
      next unless key_node.is_a?(Psych::Nodes::Scalar)
      next unless key_node.style == Psych::Nodes::Scalar::PLAIN

      resolved = resolve_plain_scalar(scalar_scanner, key_node.value)
      next if resolved.is_a?(String)

      line_num = key_node.start_line + 1
      file_key_violations << "    #{line_num}: #{key_node.value.inspect} (parses as #{resolved.inspect}, a #{resolved.class})"
    end

    if file_html_violations.any?
      html_violation_lines << "  #{filepath}:"
      html_violation_lines.concat(file_html_violations)
      html_violation_count += file_html_violations.size
    end

    if file_key_violations.any?
      key_violation_lines << "  #{filepath}:"
      key_violation_lines.concat(file_key_violations)
      key_violation_count += file_key_violations.size
    end
  rescue Psych::SyntaxError => e
    warn "  WARNING: Could not parse #{filepath}: #{e.message}"
  end
end

total_violation_count = html_violation_count + key_violation_count

if total_violation_count == 0
  puts "All locale files are Lokalise-compatible."
  exit 0
end

puts
puts "#{total_violation_count} Lokalise-incompatible value(s) found:"

if html_violation_count > 0
  puts
  puts "-- Plain HTML values with single-quoted attributes (#{html_violation_count}) --"
  puts
  html_violation_lines.each { |line| puts line }
  puts
  puts "Plain unquoted YAML values containing HTML with single-quoted attributes"
  puts "cause 400 errors when uploaded to Lokalise. Wrap the value in double quotes"
  puts "or use a block scalar:"
  puts
  puts "  Bad:  key: Click <a href='url' target='_blank'>here</a>"
  puts "  Good: key: \"Click <a href='url' target='_blank'>here</a>\""
  puts "  Good: key: |-"
  puts "          Click <a href='url' target='_blank'>here</a>"
end

if key_violation_count > 0
  puts
  puts "-- Non-string mapping keys (#{key_violation_count}) --"
  puts
  key_violation_lines.each { |line| puts line }
  puts
  puts "Unquoted true/false/yes/no/on/off/null/numeric/date keys parse as their"
  puts "literal type (boolean, nil, integer, etc.), not a string, unlike every"
  puts "other key in the file. Lokalise's importer expects string keys throughout"
  puts "and rejects the whole file with a bare 400 if it finds one that isn't."
  puts "Quote the key so it stays a string:"
  puts
  puts "  Bad:  max_hours:"
  puts "          true: \"%{count} hour(s)\""
  puts "          false: Unlimited"
  puts "  Good: max_hours:"
  puts "          \"true\": \"%{count} hour(s)\""
  puts "          \"false\": Unlimited"
end

if dry_run
  puts
  puts "(dry_run=true: not failing the workflow)"
  exit 0
end

exit 1
