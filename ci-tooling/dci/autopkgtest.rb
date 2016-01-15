require_relative '../lib/logger'

logger = DCILogger.instance

if ARGV[1].end_with? '.changes'
  logger.info('Starting autopkgtest')
  autopkgtest_result = system("DEB_BUILD_OPTIONS=\"parallel=$(nproc)\" " \
                              " adt-run --changes #{ARGV[1]} --- null")
  if autopkgtest_result
    logger.info('Autopkg test passed!')
  else
    logger.error('Autopkg test failed!')
  end
else
  logger.fatal("#{ARGV[1]} is not an actual changes file. Abort!")
end

logger.close
