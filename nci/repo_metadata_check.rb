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
Check for changes in repo-metadata in the last day and e-mail them out

Likely changes might be new stable branch, new repos or repo moved
=end

require 'open-uri'
require 'json'
require 'pp'
require_relative '../lib/pangea/mail'

class RepoMetadataCheck

  attr_reader :diff
  def doDiff
    diff = `git whatchanged --since="8 day ago" -p`
    puts diff
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
    return if diff == ""
    puts 'sending notification mail'
    Pangea::SMTP.start do |smtp|
      mail = <<-MAIL
From: Neon CI <noreply@kde.org>
To: neon-notifications@kde.org
Subject: Changes in repo-metadata

#{diff}
        MAIL
        smtp.send_message(mail,
                          'no-reply@kde.org',
                          'neon-notifications@kde.org')
    end
  end
end

if __FILE__==$0
  checker = RepoMetadataCheck.new
  checker.doDiff
#  checker.send_email
end
