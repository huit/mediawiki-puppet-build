#!/usr/bin/ruby

require 'yaml'

# parse args to determine env var prefix
default_prefix = 'NEPHO_'
prefix = default_prefix
ARGV.each_with_index {|arg, i| arg =~ /^(-p|--prefix)$/ && prefix = ARGV[i + 1]}
prefix || prefix = default_prefix

# extract env vars matching prefix and put them in a hash
extracted = {}
ENV.select {|key, value| key =~ /^#{prefix}/}.each {|pair| extracted[pair[0]] = pair[1] unless pair[1].to_s.empty?}

# emit the hash
puts extracted.to_yaml
