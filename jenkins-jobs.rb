Dir.glob(File.expand_path('jenkins-jobs/*.rb', File.dirname(__FILE__))).each do |file|
  require file
end
