#!/usr/bin/env ruby

require 'JSON'

# File with base url and default headers
@params      = JSON.parse(File.read(File.join(File.dirname(__FILE__), "params.json")))

puts @params
puts @params['base_url']
