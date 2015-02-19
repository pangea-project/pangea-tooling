#!/usr/bin/env ruby

require_relative 'lib/schroot'

arches = %w(amd64 i386)
serieses = %w(utopic vivid)
stabilities = %w(stable unstable)

arches.each do |arch|
  serieses.each do |series|
    stabilities.each do |stability|
      Schroot.new(stability: stability,
                  series: series,
                  arch: arch).create
    end
  end
end
