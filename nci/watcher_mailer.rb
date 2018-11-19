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
Send an e-mail to say the watcher has found a new version.

This used to be part of watcher.rb but it is run within a container
which is faffy to send mail from.
=end

require_relative '../lib/pangea/mail'

class WatcherMailer

  def send_email
    puts 'sending notification mail'
    Pangea::SMTP.start do |smtp|
      mail = <<-MAIL
From: Neon CI <noreply@kde.org>
To: neon-notifications@kde.org
Subject: New Version Found

#{ENV['RUN_DISPLAY_URL']}
        MAIL
        smtp.send_message(mail,
                          'no-reply@kde.org',
                          'neon-notifications@kde.org')
    end
  end
end

if __FILE__==$0
  watcher_mailer = WatcherMailer.new
  puts watcher_mailer.send_email
end
