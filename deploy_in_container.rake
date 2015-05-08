require 'fileutils'

desc 'deploy inside the container'
task :deploy_in_container do
  home = '/var/lib/jenkins'

  Dir.chdir(home) do
    # Clean up legacy things
    FileUtils.rm_rf(%w(ci-tooling .gem .rvm))
  end

  # Deploy ci-tooling and bundle. We later use internal libraries to provision
  # so we need all dependencies met as early as possible in the process.
  # FIXME: copy from above
  tooling_path = File.join(home, 'tooling-pending')
  final_path = File.join(home, 'ci-tooling')
  Dir.chdir(tooling_path) do
    sh 'gem install bundler'
    system('bundle install --no-cache --local --frozen --system --without development test')
    FileUtils.cp_rf(Dir.glob('*'), final_path)
  end

  require_relative 'ci-tooling/lib/apt'

  # Use apt.
  Apt.update
  Apt.dist_upgrade
  Apt.install(%w(xz-utils
                 dpkg-dev
                 dput
                 debhelper
                 pkg-kde-tools
                 devscripts
                 python-launchpadlib
                 ubuntu-dev-tools
                 git
                 dh-systemd
                 zlib1g-dev
                 python-paramiko
                 language-pack-en-base))

  # FIXME: it would be much more reasonable to provision via chef-single...
  require 'etc'
  user_exist = false
  Etc.passwd do |user|
    if user.name == 'jenkins'
      user_exist = true
      break
    end
  end
  sh 'addgroup --system --gid 120 jenkins' unless user_exist
  group_exist = false
  Etc.group do |group|
    if group.name == 'jenkins'
      group_exist = true
      break
    end
  end
  if group_exist
    sh "adduser --system --home #{home} --uid 100000 --ingroup jenkins" \
       ' --disabled-password jenkins'
  end

  # language-pack-base should take care of this:
  # RUN echo 'LANG=en_US.UTF-8' >> /etc/profile
  # RUN echo 'LANG=en_US.UTF-8' >> /etc/environment
  # RUN update-locale LANG=en_US.UTF-8
end
