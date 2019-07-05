#!/usr/bin/env ruby

require 'aptly'
require 'optparse'
require 'ostruct'
require 'uri'
require 'net/ssh/gateway'
require 'date'

require_relative '../ci-tooling/lib/dci'
require_relative '../lib/aptly-ext/remote'

Faraday.default_connection_options =
  Faraday::ConnectionOptions.new(timeout: 15 * 60)
Aptly::Ext::Remote.dci do
  @all_repos = []
  all_repos = Aptly::Repository.list.collect do |repo|
    next if repo.Name.include?('old')

    @all_repos << repo.Name
  end
  all_repos.compact!
  @repos = []
  @pub_repos = []
  DCI.series.each_key do |distribution|
    DCI.types.each do |type|
      file =
        "ci-tooling/data/projects/dci/#{distribution}/#{type}.yaml"
      next unless File.exist?(file)

      repo_base = YAML.load_stream(File.read(file))
      repo_base.each do |repos|
        repos.each do |_url, allrepos|
          allrepos.each.with_index do |component, _repo|
            @repos << component.keys.to_s
          end
        end
      end
      @repos.each do |repo|
        if @all_repos.include?("#{repo}-#{distribution}")
          puts "#{repo}-#{distribution} exists, moving on."
          next
        else
          puts "Creating #{repo}-#{distribution}"
          x = Aptly::Repository.create(
            "#{repo}-#{distribution}",
            DefaultDistribution: "netrunner-#{distribution}",
            DefaultComponent: repo,
            Architectures: %w[all amd64 armhf arm64 i386 source]
          )
          @pub_repos << { Name: x.Name, Component: x.DefaultComponent }
        end
      end
    end
  end
  Aptly.publish(
    @pub_repos,
    'netrunner',
    Architectures: %w[all amd64 armhf arm64 i386 source]
  )
end
