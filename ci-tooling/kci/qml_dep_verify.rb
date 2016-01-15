#!/usr/bin/env ruby

require_relative 'lib/qml_dependency_verifier'

dep_verify = QMLDependencyVerifier.new
dep_verify.add_ppa
missing_modules = dep_verify.missing_modules

## Log missing modules.
require 'logger'
require 'logger/colors'

log = Logger.new(STDOUT)
log.progname = 'QML Dep'
log.level = Logger::INFO

missing_modules.each do |package, modules|
  log.warn "#{package} has missing dependencies..."
  modules.uniq! { |mod| { mod.identifier => mod.version } }
  modules.each do |mod|
    log.info "  #{mod} not found."
    log.info '    looked for:'
    mod.import_paths.each do |path|
      log.info "      - #{path}"
    end
  end
end
