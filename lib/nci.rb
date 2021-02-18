# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2015-2021 Harald Sitter <sitter@kde.org>

# NB: this mustn't use any gems! it is used during provisioning.
require_relative 'xci'

# NCI specific data.
module NCI
  extend XCI

  module_function

  # This is a list of job_name parts that we want to not have any QA done on.
  # The implementation is a bit ugh so this should be used very very very very
  # sparely and best avoided if at all possible as we can expect this property
  # to go away for a better solution at some point in the future.
  # The array values basically are job_name.include?(x) matched.
  # @return [Array<String>] .include match exclusions
  def experimental_skip_qa
    data['experimental_skip_qa']
  end

  # Only run autopkgtest on jobs matching one of the patterns.
  # @return [Array<String>] .include match exclusions
  def only_adt
    data['only_adt']
  end

  # The old main series. That is: the series being phased out in favor of
  # the current.
  # This may be nil when none is being phased out!
  def old_series
    data.fetch('old_series')
  end

  # The current main series. That is: the series in production.
  def current_series
    data.fetch('current_series')
  end

  # The future main series. That is: the series being groomed for next
  # production.
  # This may be nil when none is being prepared!
  def future_series
    data.fetch('future_series', nil)
  end

  # Whether the future series is in its early stages. While this is true
  # the series mustn't be very public (e.g. ISOs should go to some private
  # place etc.)
  def future_is_early
    data.fetch('future_is_early')
  end

  # The archive key for archive.neon.kde.org. The returned value is suitable
  # as input for Apt::Key.add. Beyond this there are no assumptions to made
  # about its format!
  def archive_key
    data.fetch('archive_key')
  end

  # Special abstraction for the name of the type and repo Qt updates gets
  # staged in.
  def qt_stage_type
    data.fetch('qt_stage_type')
  end

  def divert_repo?(repo)
    data.fetch('repo_diversion') &&
      data.fetch('divertable_repos').include?(repo)
  end
end
