#!/usr/bin/env ruby

require 'aws'
require 'aws/core' rescue nil
require 'date'
require 'json'
require 'nokogiri'
require 'optparse'

class Image
  attr_reader :uri
  attr_reader :timestamp
  attr_reader :architecture

  def initialize(object_key)
    @uri = nil
    @timestamp = nil
    @architecture = nil

    @uri = "http://pangea-data.s3.amazonaws.com/#{object_key}"
    fileName = object_key.split('/').last
    @timestamp = DateTime.parse(fileName.split('-')[-2])
    %w[amd64 i386].each do |architecture|
      @architecture = architecture if fileName.include?(architecture)
    end
    raise "Could not determine architecture of #{object_key}" unless @architecture
  end
end

def getObjectHash(objectCollection)
  objectHash = {}
  objectCollection.each do |object|
    if object.key.end_with? ".iso"
      image = Image.new(object.key)
      date = image.timestamp.to_date
      objectHash[date] ||= []
      objectHash[date] << image

      ## Set the right acl
      object.acl = :public_read
    end
  end
  return objectHash
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)}.rb [options] BASEPATHINBUCKET"

  opts.on("-o=FILE", "Output file path") do |o|
    options[:output_path] = o
  end
end.parse!
raise OptionParser::MissingArgument.new(["-o"]) if options[:output_path].nil?

unless ARGV[0]
  puts "What do you think you're trying to pull mister!"
  puts "Need path relative to bucket root as argument...."
  exit
end

if File.exist?("#{ENV['HOME']}/.config/aws.json")
    puts "Parsing aws.json config"
    data = File.read("#{ENV['HOME']}/.config/aws.json")
    config = JSON::parse(data, :symbolize_names => true)
    AWS.config(config)
end

s3 = AWS::S3.new()

bucket = s3.buckets['pangea-data']

prefix = ARGV[0] + '/images'
prefix += '/' + ARGV[1] unless ARGV[1].nil?
ci_object_collection = bucket.objects.with_prefix(prefix)

if !File.exist?('index.html')
  puts "What?! No index.html?! Boo!"
  exit
end

@page = Nokogiri::HTML(open("#{File.expand_path(File.dirname(File.dirname(__FILE__)))}/index.html"))
tableElement = @page.at_css "tbody"

objectHash = getObjectHash(ci_object_collection)

objectHash.keys.sort.reverse_each do |datetime|
    tableEntry = Nokogiri::XML::Node.new "tr", @page
    tableEntry.parent = tableElement

    tableEntryKey = Nokogiri::XML::Node.new "td", @page
    tableEntryKey.content = datetime
    tableEntryKey.parent = tableEntry

    directLinkValue = Nokogiri::XML::Node.new "td", @page
    directLinkValue.parent = tableEntry

    torrentLinkValue = Nokogiri::XML::Node.new "td", @page
    torrentLinkValue.parent = tableEntry

    # TODO: what if there are multiple images per day?
    # For now at least sort them...
    objectHash[datetime].sort_by! { |image| image.timestamp }

    # Iterate images and add approrpriate arch entries.
    objectHash[datetime].each do |image|
      directLink = Nokogiri::XML::Node.new "a", @page
      directLink['href'] = image.uri
      directLink.content = "[#{image.architecture}]"
      directLink.parent = directLinkValue

      torrentLink = Nokogiri::XML::Node.new "a", @page
      torrentLink['href'] = "#{image.uri}?torrent"
      torrentLink.content = "[#{image.architecture}]"
      torrentLink.parent = torrentLinkValue
    end
end

File.open(options[:output_path], "w").write(@page.to_html)
