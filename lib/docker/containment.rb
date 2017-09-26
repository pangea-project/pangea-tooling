# frozen_string_literal: true
require_relative '../ci/containment'

warn 'W: Requiring deprecated Containment class. Use CI::Containment instead.'
Containment = CI::Containment
raise NameError, 'Using deprecated Containment class. Use CI::Containment.'

# TODO: remove docker/containment
