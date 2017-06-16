require_relative '../job'
require_relative '../binarier'

# binary builder
class BinarierJob
  # Monkey patch cores in
  def cores
    JSON.parse(File.read("#{__dir__}/../../data/nci/jobs-to-cores.json")).fetch(job_name, '2')
  end
end
