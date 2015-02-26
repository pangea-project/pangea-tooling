require 'json'
require 'ostruct'

Project = Struct.new(:name, :component, :deps, :dependees)

# chdist_archive = 'http://archive.ubuntu.com/ubuntu'
# chdist_release = 'utopic'
# chdist_components = 'main restricted universe multiverse'
# chdist_cache_dir = "#{Dir.pwd}/chdist-data"
# chdist_name = 'utopic_unstable'
# chdist_arch = 'i386'
# chdist_dir = "#{chdist_cache_dir}/#{chdist_name}"
# chdist = "chdist -d #{chdist_cache_dir} -a #{chdist_arch}"
# 
# chdist_exists = false
# `#{chdist} list`.split("\n").each do |line|
#     chdist_exists = true if line.strip == chdist_name
# end

# if !chdist_exists
#     %x[#{chdist} create #{chdist_name}]
#     File.open("#{chdist_dir}/etc/apt/sources.list", 'a') do |file|
#         file << "deb http://ppa.launchpad.net/kubuntu-ci/unstable/ubuntu utopic main\n"
#         file << "deb-src http://ppa.launchpad.net/kubuntu-ci/unstable/ubuntu utopic main\n"
#     end
# end

# apt_file_dir = "#{Dir.pwd}/apt-file/"
# Dir.mkdir(apt_file_dir) unless File.exist?(apt_file_dir)
# apt_file_cache_dir = "#{apt_file_dir}/cache"
# apt_file = "apt-file -c #{apt_file_cache_dir} -s #{chdist_dir}/etc/apt/sources.list"
# 
# File.open("#{apt_file_dir}/sources.list", 'a') do |file|
#     file << "deb http://ppa.launchpad.net/kubuntu-ci/unstable/ubuntu utopic main\n"
#     file << "deb-src http://ppa.launchpad.net/kubuntu-ci/unstable/ubuntu utopic main\n"
# end
# 
# puts "#{apt_file} update"
# %x[#{apt_file} update]
# 
# exit 0

static_map = {
    'PackageHandleStandardArgs' => 'cmake-data',
}

finder_map = {
    'FindExiv2.cmake' => 'libexiv2-dev',
    'FindJPEG.cmake' => 'libjpeg-dev',
    'FindKF5.cmake' => nil,
    'FindLCMS2.cmake' => 'liblcms2-dev',
    'FindPackageMessage.cmake' => nil,
    'FindPNG.cmake' => 'libpng-dev',
    'FindX11.cmake' => 'libx11-dev',
    'FindZLIB.cmake' => 'libzlib-dev',
}

projects = []

dep_dir = 'meta-dep'
Dir.mkdir(dep_dir) unless File.exist?(dep_dir)
Dir.chdir(dep_dir) do
    File.delete('dependency-metadata.tar.xz') if File.exist?('dependency-metadata.tar.xz')
    `wget http://build.kde.org/userContent/dependency-metadata.tar.xz`
    `tar -xf dependency-metadata.tar.xz`
    Dir.glob('*-kf5-qt5.json').each do |jsonFile|
        # FIXME: parser is fucked with missing deps
        # FIXME: qt5 parse entirely useless
        next if jsonFile.start_with?('qt5-')
        next unless jsonFile.start_with?('gwenview-kf5')
        
        puts "--------------- #{jsonFile} ------------------"
        
        project = Project.new
        project.name = jsonFile.gsub('-kf5-qt5.json', '')
        project.deps = []
        
        data = File.read(jsonFile)
        json = JSON::parse(data, :object_class => OpenStruct)
        json.each do |dependency|
#             next unless dependency.explicit
            puts "----------- #{dependency.project}"
#             p dependency.files

            dep_packages = []

            if static_map.include?(dependency.project)
                dep_packages << static_map[dependency.project]
                break
            else
                dependency.files.each do |file|
                    path_parts = []
                    possible_path_parts = file.split('/')
                    while not possible_path_parts.empty?
                        path_parts.unshift(possible_path_parts.pop)
                        path = path_parts.join('/')

#                         puts "trying #{path}"

                        packages = `dpkg -S #{path} 2>&1`.lines
                        if $? != 0
                            puts "   - got no match on #{path}"
                            next
                            exit 1
                        end

                        if packages.size < 1
                            p packages
                            puts "got no hit, wut"
                            exit 1
                        end

                        packages.collect! do |entry|
                            entry.split(':')[0]
                        end

                        if packages.size > 1
                            if packages.include?('cmake-data')
                                # CMake always wins.
                                # FIXME: possibly project should factor into the cmake winning, if project contains KF5 it probably should not win
                                # FIXME: static_map should override this
                                packages = ['cmake-data']
                            end
                        end

                        if packages.size > 1
                            puts "   - couldn't find absolute match on #{path}"
                            next
                            exit 1
                        end

                        dep_packages << packages[0]
                        break
                    end
                end
                dep_packages.uniq!
                raise 'Could not find concrete match' unless dep_packages.size == 1
            end

            if dependency.files.size == 1 and \
                    (finder = dependency.files.first.split('/').last) and \
                    finder.match(/Find.*\.cmake/)
                # The file we looked for was a finder script. Finder scripts while necessary
                # themselves do not actually enable the library in question to be installed.
                # We therefore always require a finder_map from a specific finder script to
                # a dev package.
                raise "need finder mapping for finder script #{finder}" unless finder_map.include?(finder)
                dep_packages << finder_map[finder]
            end

            dep_packages.uniq!
            puts "  + #{dep_packages.join(', ')}"
            project.deps.concat(dep_packages)

            # TODO: need to apt-file first to cover not installed stuff .. or maybe as a fallback?
            
#             packages = `dpkg -S #{dependency.files.join(' ')}`.lines
#             if $? != 0
# #                 puts "error"
#                 next
#                 exit 1
#             end
#             if packages.size < 1
#                 p packages
#                 puts "got no hit, wut"
#                 exit 1
#             end
#         
#             packages.collect! do |entry|
#                 entry.split(':')[0]
#             end
#             
#             if packages.size > 1
#                 if packages.include?('cmake-data')
#                     # CMake always wins.
#                     # FIXME: possibly project shoudl factor into the cmake winning, if project contains KF5 it probably should not win
#                     # FIXME: static_map should override this
#                     packages = ['cmake-data']
#                 end
#             end
#             
#             if packages.size > 1
#                 puts "couldn't find absolute match"
#                 exit 1
#             end
            
#             puts "packages: #{packages[0]}"
#             project.deps << packages[0]
        end
        
        project.deps.compact!
        project.deps.uniq!
        projects << project
    end
end

require 'pp'

pp projects

exit 1



provided_by = {}

require 'pp'
projects = []

components = [ 'frameworks', 'plasma' ]
components.each do |component|
    repos = %x[ssh git.debian.org ls /git/pkg-kde/#{component}].chop!.gsub!('.git', '').split(' ')
    repos.each do |name|
        project = Project.new(name, component, [], [])

        Dir.chdir('git') do
            unless File.exist?(name)
                i = 0
                while true and (i+=1) < 5
                    break if system("git clone debian:#{component}/#{name}")
                end
            end
            Dir.chdir(name) do
                system("git reset --hard")
                system("git checkout kubuntu_unstable")
                i = 0
                while true and (i+=1) < 5
                    break if system("git pull")
                end
                
                next unless File.exist?('debian/control')
                
                c = DebianControl.new
                c.parse!
                c.source['build-depends'].each do |dep|
                    project.deps << dep.name
                end
                c.binaries.each do |binary|
                    provided_by[binary['package']] = name
                end
            end
        end

        projects << project
    end
end

# Random explanation of the day:
# Ruby blocks generally "return" with next or break (implicitly by default mind you)
# collect! considering this will use the "return" value of break/next and aggregates
# those into the array.
# Consequentially one must always 'break var' or 'next var' (or simply 'var' because
# of the implicit return paradigm) in order to have collect! get the modified value.
# If one does not implicitly or explicitly return a value nil will be collected instead.
projects.collect! do |project|
    project.deps.collect! do |dep|
        next unless provided_by.include?(dep)
        dep = provided_by[dep]
        # Reverse insert us into the list of dependees of our dependency
        projects.collect! do |dep_project|
            next dep_project if dep_project.name != dep
            dep_project.dependees << project.name
            dep_project.dependees.compact!
            break dep_project
        end
        next dep
    end
    # Ditch nil and duplicates
    project.deps.compact!
    project
end

pp '---------------------------------------'
pp projects

