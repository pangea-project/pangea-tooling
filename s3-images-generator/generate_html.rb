#!/usr/bin/env ruby

require 'aws-sdk-v1'
require 'date'
require 'json'
require 'nokogiri'
require 'optparse'

# Describes an ISO image.
class Image
  attr_reader :uri
  attr_reader :timestamp
  attr_reader :architecture

  def initialize(object_key)
    @timestamp = nil
    @architecture = nil

    @uri = "http://pangea-data.s3.amazonaws.com/#{object_key}"
    file_name = object_key.split('/').last
    @timestamp = DateTime.parse(file_name.split('-')[-2])
    %w(amd64 i386).each do |architecture|
      @architecture = architecture if file_name.include?(architecture)
    end
    return if @architecture
    raise "Could not determine architecture of #{object_key}"
  end
end

def get_object_hash(objects)
  object_hash = {}
  objects.each do |object|
    if object.key.end_with?('.iso')
      image = Image.new(object.key)
      date = image.timestamp.to_date
      object_hash[date] ||= []
      object_hash[date] << image

      ## Set the right acl
      object.acl = :public_read
    end
  end
  object_hash
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options] BASEPATHINBUCKET"

  opts.on('-o=FILE', 'Output file path') do |o|
    options[:output_path] = o
  end
end.parse!
abort OptionParser::MissingArgument.new(%w(-o)) if options[:output_path].nil?

unless ARGV[0]
  puts "What do you think you're trying to pull mister!"
  puts 'Need path relative to bucket root as argument....'
  exit
end

if File.exist?("#{ENV['HOME']}/.config/aws.json")
  puts 'Parsing aws.json config'
  data = File.read("#{ENV['HOME']}/.config/aws.json")
  config = JSON.parse(data, symbolize_names: true)
  AWS.config(config)
end

s3 = AWS::S3.new

bucket = s3.buckets['pangea-data']

prefix = ARGV[0] + '/images'
prefix += '/' + ARGV[1] unless ARGV[1].nil?
ci_object_collection = bucket.objects.with_prefix(prefix)

index_html = "#{File.expand_path(File.dirname(__FILE__))}/index.html"
abort 'What?! No index.html?! Boo!' unless File.exist?(index_html)

@page = Nokogiri::HTML(open(index_html))
table_element = @page.at_css 'tbody'

object_hash = get_object_hash(ci_object_collection)
object_hash.keys.sort.reverse_each do |datetime|
  table_entry = Nokogiri::XML::Node.new 'tr', @page
  table_entry.parent = table_element

  table_entry_key = Nokogiri::XML::Node.new 'td', @page
  table_entry_key.content = datetime
  table_entry_key.parent = table_entry

  direct_link_value = Nokogiri::XML::Node.new 'td', @page
  direct_link_value.parent = table_entry

  torrent_link_value = Nokogiri::XML::Node.new 'td', @page
  torrent_link_value.parent = table_entry

  # TODO: what if there are multiple images per day?
  # For now at least sort them...
  object_hash[datetime].sort_by!(&:timestamp)

  # Iterate images and add approrpriate arch entries.
  object_hash[datetime].each do |image|
    direct_link = Nokogiri::XML::Node.new('a', @page)
    direct_link['href'] = image.uri
    direct_link.content = "[#{image.architecture}]"
    direct_link.parent = direct_link_value

    torrent_link = Nokogiri::XML::Node.new('a', @page)
    torrent_link['href'] = "#{image.uri}?torrent"
    torrent_link.content = "[#{image.architecture}]"
    torrent_link.parent = torrent_link_value
  end
end

File.open(options[:output_path], 'w').write(@page.to_html)
