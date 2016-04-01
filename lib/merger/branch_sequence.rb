# frozen_string_literal: true
#
# Copyright (C) 2014-2016 Harald Sitter <sitter@kde.org>
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

require 'git'

class BranchSequence
  attr_reader :parent
  attr_reader :source

  def initialize(name, git:, parent: nil, dirty: false)
    @name = name
    @parent = parent
    @git = git
    @dirty = dirty
    @source = resolve_name(name)
    # FIXME: what happens if the first source doesn't exist?
    @source = parent.source if parent && !@source
  end

  def resolve_name(name)
    # FIXME: local v remote isn't test covered
    source = @git.branches.local.select { |b| b.name == name }
    source = @git.branches.remote.select { |b| b.name == name } if source.empty?
    raise "Found more than one matching source #{source}" if source.size > 1
    if source.empty?
      # FIXME: log
      # @log.warn "Apparently there is no branch named #{source_name}!"
      return nil
    end
    source[0]
  end

  # FIXME: yolo
  def noci_merge?(source)
    log = @git.log.between('', source.full)
    return false unless log.size >= 1
    log.each do |commit|
      return false unless commit.message.include?('NOCI')
    end
    true
  end

  def mergerino(target)
    return false unless @source
    return false unless target

    @git.checkout(target.name)
    msg = "Merging #{@source.full} into #{target.name}."
    # FIXME: is in merger
    # FIXME: true case not test covered
    if noci_merge?(@source)
      msg = "Merging #{@source.full} into #{target.name}.\n\nNOCI"
    end

    puts msg
    @git.merge(@source.full, msg)
    true
  end

  def merge_into(target)
    # FIXME: we should new differently so we can pass the resolved target
    # without having to resolve it again
    dirty = mergerino(resolve_name(target))
    BranchSequence.new(target, dirty: dirty, parent: self, git: @git)
  end

  def push
    branches = []
    branch = self
    while branch && branch.parent # Top most item has no parent and isn't dirty.
      branches << branch
      branch = branch.parent
    end
    branches.reverse!
    branches.each(&:push_branch)
  end

  # FIXME: should be private maybe?
  def push_branch
    return puts "Nothing to push for #{@name}" unless dirty? && valid?
    puts "pushing #{@source.name}"
    @git.push('origin', @source.name)
  end

  private

  def dirty?
    @dirty
  end

  def valid?
    !@source.nil?
  end
end
