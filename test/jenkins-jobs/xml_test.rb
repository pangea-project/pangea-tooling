require 'equivalent-xml'
require 'test/unit'

require_relative '../../ci-tooling/lib/projects'

# Adds instance methods for XML assertations based on EquivalentXml
module XmlAssertations
  def assert_xml_equal(expected, actual)
    EquivalentXml.equivalent?(expected, actual, element_order: false)
  end

  def assert_not_xml_equal(expected, actual)
    !assert_xml_equal(expected, actual)
  end
end

# Fake project to bypass shortcomings in testability of Projects.
class FakeProject < Project
  def initialize(name: 'testproject', component: 'testcomponent',
                 dependencies: [], dependees: [])
    @name = name
    @component = component
    @dependencies = dependencies
    @dependees = dependees
    @upstream_scm = Scm.new('git', 'kitten', 'master')
    @series_branches = []
  end
end

# Regular TestCase extended with {XmlAssertations}.
class XmlTestCase < Test::Unit::TestCase
  include XmlAssertations

  # Helper to ouput pretty formatted xml to stdout.
  # Mostly useful to get a fixture out of a test.
  # @param xml the xml data (not document!) to output
  def format_output(xml)
    require 'rexml/document'

    doc = REXML::Document.new(xml)
    formatter = REXML::Formatters::Pretty.new

    # Compact uses as little whitespace as possible
    formatter.compact = true
    formatter.write(doc, STDOUT)
  end

  # @return data of the given fixture format
  def fixture(f)
    @file_directory ||= File.expand_path(File.dirname(__FILE__))
    File.read("#{@file_directory}/data/#{f}.xml")
  end
end
