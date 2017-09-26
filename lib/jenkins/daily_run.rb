#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'ostruct'
require 'net/http'
require 'date'

module Jenkins
  # Helps with checking whether the job at hand is supposed to do a daily run
  class DailyRun
    def initialize(job_url: ENV.fetch('JOB_URL'),
                   build_number: ENV.fetch('BUILD_NUMBER').to_i)
      @build_number = build_number
      uri = URI("#{job_url}/api/json?pretty=false&depth=1")
      job_json = Net::HTTP.get(uri)
      job = JSON.parse(job_json, object_class: OpenStruct)

      @builds = job.builds
      @builds.sort_by!(&:number)
      @builds.reverse!
    end

    def manually_triggered?
      @builds.each do |build|
        next if build.number != @build_number
        if !build.actions.empty? && build.actions[0] &&
           !build.actions[0].empty? && build.actions[0].causes[0] &&
           build.actions[0].causes[0].respond_to?(:userId)
          return true
        end
      end
      false
    end

    def ran_today?
      current_build = nil
      current_build_date = nil
      out_of_date_range = false
      builds = @builds.delete_if do |build|
        next true if out_of_date_range
        next true if build.number > @build_number
        if build.number == @build_number
          current_build = build
          current_build_date = Date.parse(Time.at(build.timestamp / 1000).to_s)
          next true
        end
        previous_build_date = Date.parse(Time.at(build.timestamp / 1000).to_s)
        out_of_date_range = current_build_date != previous_build_date
      end

      # builds now only contains builds of the same day as the current build.

      ran_results = %w[SUCCESS]
      builds.each do |build|
        return true if ran_results.include?(build.result)
      end
      false
    end
  end
end
