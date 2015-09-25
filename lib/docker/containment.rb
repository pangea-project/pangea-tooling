require_relative '../ci/containment'

warn 'W: Requiring deprecated Containment class. Use CI::Containment instead.'
Containment = CI::Containment
