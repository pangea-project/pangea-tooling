#!/usr/bin/python

from optparse import OptionParser
import os
import os.path
import re
import shutil
import subprocess
import sys
import time
import urllib
import xml.dom.minidom
import json
import tempfile
import select

class DependencyNotFound(Exception):
  def __init__(self, depend):
    super(DependencyNotFound, self).__init__(depend)
    self.path = depend[0]
    self.package = depend[1]

  def __str__(self):
    return 'Dependency not found: %s. Please install package %s' % (self.path, self.package)

class InvalidTagError(Exception):
  def __init__(self, tag):
    super(InvalidTagError, self).__init__(tag)
    self.tag = tag

  def __str__(self):
    return "Tag %s is invalid" % self.tag

def do_exec(args, quiet=True, ignore_error=False, cwd=None):
  if quiet == False:
    print 'Running %s%s' % (' '.join([x for x in args]), '' if cwd == None else (' in %s' % cwd))

  out = ''
  p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=cwd)
  while p.poll() == None:
    (r, w, e) = select.select([p.stdout], [], [], 5)
    for f in r:
      d = f.read()
      out += d
      if quiet == False:
        print d

  if p.returncode != 0 and ignore_error == False:
    raise Exception("Command '%s' returned exit-status %d:\n%s" % (args[0], p.returncode, p.stderr.read()))

  return (p.returncode, out)

def ensure_cache(repo, cache):
  dest = os.path.join(cache, os.path.basename(repo))
  if os.path.isdir(dest):
    (ret, out) = do_exec(['hg', 'summary'], cwd=dest, quiet=True, ignore_error=True)
    if ret == 0:
      print 'Cache location %s exists, using it' % dest
      do_exec(['hg', 'pull', repo], quiet=False, cwd=dest)
      do_exec(['hg', 'update'], quiet=False, cwd=dest)
      return

  if not os.path.isdir(cache):
    os.makedirs(cache)

  print 'Creating cache location %s' % dest
  do_exec(['hg', 'clone', repo, dest], quiet=False)

def do_checkout(source, dest, tag=None):
  dest = os.path.abspath(dest)
  dest_parent = os.path.dirname(dest)
  if dest_parent != '' and not os.path.isdir(dest_parent):
    os.makedirs(dest_parent)

  do_exec(['hg', 'clone', source, dest], quiet=False)

  try:
    args = ['hg', 'update']
    if tag != None:
      args.append('-r')
      args.append(tag)
    do_exec(args, quiet=False, cwd=dest)
  except:
    if tag != None:
      raise Exception("Revision %s not found in %s" % (tag, source))
    raise

def checkout_source(repo, cache, dest, tag=None):
  print '\n'
  print '*** Checking out source from %s%s ***' % (repo, ' using cache from %s' % cache if cache != None else '')
  local_source = None
  if cache != None:
    ensure_cache(repo, cache)
    local_source = os.path.join(cache, os.path.basename(repo))
  source = repo if local_source == None else local_source
  do_checkout(source, dest, tag=tag)
  print '\n'

def get_setting(settings, name, default=None):
  return settings[name] if name in settings else default

class ScopedTmpdir:
  def __enter__(self):
    self._tmpdir = tempfile.mkdtemp()
    print 'Using temporary directory %s' % self._tmpdir
    return self._tmpdir

  def __exit__(self, type, value, traceback):
    print 'Cleaning temporary directory %s' % self._tmpdir
    shutil.rmtree(self._tmpdir)

class ScopedWorkingDirectory:
  def __init__(self, dir):
    self._wd = os.path.abspath(dir)

  def __enter__(self):
    self._saved_wd = os.getcwd()
    if not os.path.isdir(self._wd):
      os.makedirs(self._wd)

    os.chdir(self._wd)

    return self._saved_wd

  def __exit__(self, type, value, traceback):
    os.chdir(self._saved_wd)

class ScopedRename:
  def __init__(self, src, dest):
    self._src = src
    self._dest = dest

  def __enter__(self):
    os.rename(self._src, self._dest)

  def __exit__(self, type, value, traceback):
    os.rename(self._dest, self._src)

class TarballCreator(OptionParser):
  def __init__(self):
    OptionParser.__init__(self, 'usage: %prog [options]')

    self.add_option('-r', '--repo', dest='repo', help='The remote repository from which to pull the main source')
    self.add_option('-c', '--cache', dest='cache', help='A local cache of the remote repositories')
    self.add_option('-l', '--l10n-base-repo', dest='l10nbase', help='The base directory of the remote repositories to pull l10n data from')
    self.add_option('-t', '--tag', dest='tag', help='Release tag to base the checkout on')
    self.add_option('-n', '--name', dest='name', help='The package name')
    self.add_option('-a', '--application', dest='application', help='The application to build')
    self.add_option('-m', '--mozdir', dest='mozdir', help='The location of the Mozilla source', default='')

  def run(self):
    (options, args) = self.parse_args()

    if options.repo == None:
      self.error('Must specify a remote repository')

    if options.name == None:
      self.error('Must specify a package name')

    if options.application == None:
      self.error('Must specify an application')

    if options.cache != None and not os.path.isabs(options.cache):
      options.cache = os.path.join(os.getcwd(), options.cache)

    settings = None
    with open('debian/config/tarball.conf', 'r') as fd:
      settings = json.load(fd)

    DEPENDENCIES = [
      [ 'hg', 'mercurial' ],
      [ 'tar', 'tar' ]
    ]

    print 'Checking dependencies'
    for depend in DEPENDENCIES:
      if os.path.isabs(depend[0]) and not os.access(depend[0], os.X_OK):
        raise DependencyNotFound(depend)
      else:
        found = False
        for path in os.environ['PATH'].split(os.pathsep):
          if os.access(os.path.join(path, depend[0]), os.X_OK):
            found = True
            break
        if found == False:
          raise DependencyNotFound(depend)

    repo = options.repo
    cache = options.cache
    tag = options.tag
    application = options.application
    l10nbase = options.l10nbase
    name = options.name
    mozdir = options.mozdir

    with ScopedTmpdir() as tmpdir:
      with ScopedWorkingDirectory(os.path.join(tmpdir, name)) as saved_wd:

        checkout_source(repo, cache, '', tag=tag)

        need_moz = get_setting(settings, 'run-client-script', False)
        if need_moz:
          print '\n'
          print '*** Running checkout script ***'
          moz_local = None
          moz_repo = os.path.join(os.path.dirname(repo), os.path.basename(repo).replace('comm', 'mozilla'))
          if cache != None:
            ensure_cache(moz_repo, cache)
            moz_local = os.path.join(cache, os.path.basename(moz_repo))
          args = [sys.executable, 'client.py', 'checkout']
          if moz_local != None:
            args.append('--mozilla-repo=%s' % moz_local)
          if tag != None:
            args.append('--comm-rev=%s' % tag)
            args.append('--mozilla-rev=%s' % tag)
          do_exec(args, quiet=False)
          print '\n'

        checkout_source('https://hg.mozilla.org/build/compare-locales', cache, os.path.join(mozdir, 'python/compare-locales'), tag=tag)

        # XXX: In the future we may have an additional l10n source from Launchpad
        if l10nbase != None:
          got_locales = set()
          shipped_locales = os.path.join(application, 'locales/shipped-locales')
          all_locales = os.path.join(application, 'locales/all-locales')
          blacklist_file = get_setting(settings, 'l10n-blacklist')

          print '\n\n'
          print '*** Checking out l10n source from %s%s ***' % (l10nbase, ' using cache from %s' % cache if cache != None else '')

          l10ndir = 'l10n'
          if not os.path.isdir(l10ndir):
            os.makedirs(l10ndir)

          with open(os.path.join(l10ndir, 'changesets'), 'w') as changesets:
            for l10nlist in [shipped_locales, all_locales]:
              with open(l10nlist, 'r') as fd:
                for line in fd:
                  locale = line.split(' ')[0].strip()
                  if locale.startswith('#') or locale in got_locales or locale == 'en-US':
                    continue

                  try:
                    checkout_source(os.path.join(l10nbase, locale), os.path.join(cache, 'l10n') if cache != None else None, 'l10n/' + locale, tag=tag)
                    (ret, out) = do_exec(['hg', 'tip'], cwd='l10n/' + locale, quiet=True)
                    for line in out.split('\n'):
                      if line.startswith('changeset:'):
                        changesets.write('%s %s\n' % (locale, line.split()[1].strip()))
                        print 'Got changeset %s' % line.split()[1].strip()
                        break

                    got_locales.add(locale)

                  except Exception as e:
                    # checkout_locale will throw if the specified revision isn't found
                    # In this case, omit it from the tarball
                    print >> sys.stderr, 'Failed to checkout %s: %s' % (locale, e)
                    localedir = os.path.join(l10ndir, locale)
                    if os.path.exists(localedir):
                      shutil.rmtree(localedir)

          # When we also use translations from Launchpad, there will be a file
          # containing the additional locales we want to ship (locales.extra??)
          print '\n\n'
          print '*** Checking that required locales are present ***'

          blacklist = set()
          if blacklist_file:
            with open(os.path.join(saved_wd, blacklist_file), 'r') as fd:
              for line in fd:
                locale = re.sub(r'([^#]*)#?.*', r'\1', line).strip()
                if locale is '':
                  continue

                blacklist.add(locale)

          with open(shipped_locales, 'r') as fd:
            for line in fd:
              line = line.strip()
              if line.startswith('#'):
                continue

              if line == 'en-US':
                print 'Ignoring en-US'
                continue

              locale = line.split(' ')[0].strip()
              platforms = line.split(' ')[1:]

              if locale in blacklist:
                print 'Ignoring blacklisted locale %s' % locale
                continue

              if len(platforms) > 0:
                for_linux = False
                for platform in platforms:
                  if platform == 'linux':
                    for_linux = True
                    break
                if not for_linux:
                  print 'Ignoring %s (not for linux)' % locale
                  continue

              if not locale in got_locales:
                raise Exception("Locale %s is missing from the source tarball" % locale)

              print '%s - Yes' % locale

        version = None
        with open(os.path.join(options.application, 'config/version.txt'), 'r') as vf:
          version = re.sub(r'~$', '', re.sub(r'([0-9\.]*)(.*)', r'\1~\2', vf.read().strip()))

        if tag == None:
          (ret, out) = do_exec(['hg', 'tip'], quiet=True)
          for line in out.split('\n'):
            if line.startswith('changeset:'):
              rev = line.split()[1].split(':')[0].strip()
              changeset = line.split()[1].split(':')[1].strip()
              break

          u = urllib.urlopen('%s/pushlog?changeset=%s' % (repo, changeset))
          dom = xml.dom.minidom.parseString(u.read())
          t = time.strptime(dom.getElementsByTagName('updated')[0].firstChild.nodeValue.strip(), '%Y-%m-%dT%H:%M:%SZ')
          version += '~hg%s%s%sr%s' % ('%02d' % t.tm_year, '%02d' % t.tm_mon, '%02d' % t.tm_mday, rev)
          u.close()

          if need_moz:
            # Embed the moz revision in the version number too. Allows us to respin dailies for comm-central
            # even if the only changes landed in mozilla-central
            (ret, out) = do_exec(['hg', 'tip'], cwd='mozilla', quiet=True)
            for line in out.split('\n'):
              if line.startswith('changeset:'):
                version += '.%s' % line.split()[1].split(':')[0].strip()
                break
        else:
          parsed = False
          version_from_upstream = version
          version = ''
          build = None
          for comp in tag.split('_')[1:]:
            if parsed == True:
              raise InvalidTagError(tag)

            if comp.startswith('BUILD'):
              build = re.sub(r'BUILD', '', comp)
              parsed = True
            elif comp.startswith('RELEASE'):
              parsed = True
            else:
              if version != '':
                version += '.'
              version += re.sub(r'~$', '', re.sub(r'([0-9]*)(.*)', r'\1~\2', comp))

            if parsed == True and version == '':
              raise InvalidTagError(tag)

          if version == '':
            raise InvalidTagError(tag)

          if build != None:
            version += '+build%s' % build

          if not version.startswith(version_from_upstream):
            raise InvalidTagError(tag)

        print '\n\n'
        print '*** Upstream version is %s' % version

        print '\n\n'
        print '*** Packing tarball ***'
        with ScopedWorkingDirectory('..'):
          topsrcdir = '%s-%s' % (name, version)
          with ScopedRename(name, topsrcdir):
            args = ['tar', '-jc', '--exclude-vcs']
            for exclude in settings['excludes']:
              args.append('--no-wildcards-match-slash') if exclude['wms'] == False else args.append('--wildcards-match-slash')
              args.append('--exclude')
              args.append(os.path.join(topsrcdir , exclude['path']))
            args.append('-f')
            args.append(os.path.join(saved_wd, '%s_%s.orig.tar.bz2' % (name, version)))
            for include in settings['includes']:
              args.append(os.path.join(topsrcdir, include))

            do_exec(args, quiet=False)

def main():
  creator = TarballCreator()
  creator.run()

if __name__ == '__main__':
  main()
