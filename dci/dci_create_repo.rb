#!/usr/bin/env ruby

require 'aptly'
require 'optparse'
require 'ostruct'
require 'uri'
require 'net/ssh/gateway'
require 'date'

require_relative '../lib/dci'
require_relative '../lib/aptly-ext/remote'

Faraday.default_connection_options =
  Faraday::ConnectionOptions.new(timeout: 15 * 60)
Aptly::Ext::Remote.dci do
  @all_repos = []
  all_repos = Aptly::Repository.list.collect do |repo|
    next if repo.Name.include?('old')

    @all_repos << repo.Name
  end
  puts @all_repos
  all_repos.compact!
  @repos = []
  distribution = DCI.latest_series
    DCI.types.each do |type|
      file = "data/projects/dci/#{distribution}/#{type}.yaml"
      next unless File.exist?(file)

      puts distribution
      puts type
      repo_base = YAML.load_stream(File.read(file))
      repo_base.each do |repos|
        repos.each do |_url, allrepos|
          allrepos.each.with_index do |component, _repo|
            puts component
            component.each_key do |repo|
              if @all_repos.include?("#{repo}-#{distribution}")
                puts "#{repo}-#{distribution} exists, moving on.".gsub(/[\,\"\[\]*]/, '')
                next
              else
                puts "Creating #{repo}-#{distribution}".gsub(/[\,\"\[\]*]/, '')
                x = Aptly::Repository.create(
                  "#{repo}-#{distribution}".gsub(/[\,\"\[\]*]/, ''),
                  DefaultDistribution: "netrunner-#{distribution}",
                  DefaultComponent: repo.to_s.gsub(/[\,\"\[\]*]/, ''),
                  Architectures: %w[all amd64 armhf arm64 i386 source]
                )
                @repos << { Name: x.Name, Component: x.DefaultComponent }
              end
            end
          end
        end
      end
    end
  Aptly.publish(
    @repos,
    'netrunner',
    Architectures: %w[all amd64 armhf arm64 i386 source]
  )
end
