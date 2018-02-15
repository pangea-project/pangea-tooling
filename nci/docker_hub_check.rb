#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2018 Jonathan Riddell <jr@jriddell.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

=begin
Check Docker Hub for the status of latest Neon image builds

Build history JSON from API https://hub.docker.com/v2/repositories/kdeneon/plasma/buildhistory/?page_size=10
results is a list
for each item get "dockertag_name": "latest"
unless already met that tag name check status
"status": 10 good, -1 bad
return error on -1    
=end

require 'open-uri'
require 'json'
require 'pp'
require_relative '../lib/pangea/mail'

class DockerHubCheck

  attr_reader :urls
  def initialize
    @urls = {'plasma'=> 'https://hub.docker.com/v2/repositories/kdeneon/plasma/buildhistory/?page_size=10',
             'all'=> 'https://hub.docker.com/v2/repositories/kdeneon/plasma/buildhistory/?page_size=10'}
  end
  
  # Returns a hash of images and their latest build status
  def build_statuses(url)
    @statuses = {}
    @failure_found = false
    open(url) do |f|
      json = JSON.parse(f.read)
      json['results'].each do |result|
        @statuses.key?(result['dockertag_name']) || @statuses[result['dockertag_name']] = result['status']
        @failure_found = true if result['status'] < 0
      end
    end
    @statuses
  end
  
  def format_email
    @text = ""
    @statuses.each do |name, status_code|
      if status_code < 0
        @text += "#{name}: #{status_code}\n"
      end
    end
    @text
  end
  
  def send_email
    return if @failure_found == false
    puts 'sending notification mail'
    Pangea::SMTP.start do |smtp|
      mail = <<-MAIL
From: Neon CI <no-reply@kde.org>
To: neon-notifications@kde.org
Subject: Broken Neon Docker Hub Build

#{format_email}
        MAIL
        smtp.send_message(mail,
                          'no-reply@kde.org',
                          'neon-notifications@kde.org')
    end
  end
end

if __FILE__==$0
  checker = DockerHubCheck.new
  puts checker.build_statuses(checker.urls['plasma'])
  checker.send_email
  puts checker.build_statuses(checker.urls['all'])
  checker.send_email
end
