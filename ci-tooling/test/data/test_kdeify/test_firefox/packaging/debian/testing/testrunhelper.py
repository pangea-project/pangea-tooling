#!/usr/bin/python

import os
import os.path
import sys
from optparse import OptionParser
from subprocess import Popen
import tempfile
import shutil
import atexit
import re
import traceback
import time

skel = {
  '.config/user-dirs.dirs':
'''# This file is written by xdg-user-dirs-update
# If you want to change or add directories, just edit the line you're
# interested in. All local changes will be retained on the next run
# Format is XDG_xxx_DIR="$HOME/yyy", where yyy is a shell-escaped
# homedir-relative path, or XDG_xxx_DIR="/yyy", where /yyy is an
# absolute path. No other format is supported.
# 
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"''',

  '.config/gnome-session/sessions/test.session':
'''[GNOME Session]
Name=Test Session
RequiredComponents=gnome-settings-daemon;metacity;
DesktopName=GNOME''',

  '.config/autostart/run-test.desktop':
'''[Desktop Entry]
Name=Run Testsuite
Exec=sh -c 'sleep 5; $UBUNTU_MOZ_TEST_RUNNER $UBUNTU_MOZ_TEST_ARGS'
Terminal=false
Type=Application
Categories='''
}

def create_tmpdir():
  tmp = tempfile.mkdtemp()

  def clean():
    shutil.rmtree(tmp)

  atexit.register(clean)

  return tmp

class TestRunHelper(OptionParser):

  def __init__(self, runner, get_runner_parser_cb, pass_args=[], paths=[], need_x=False):
    OptionParser.__init__(self)
    self.__tmpdir = None
    self._xredir = None

    self.root = os.path.dirname(__file__)

    args = iter(sys.argv[1:])
    while True:
      try:
        arg = args.next()
      except StopIteration:
        break

      if arg == '--harness-root-dir':
        try:
          self.root = args.next()
        except StopIteration:
          break
      elif arg == '--xre-path':
        try:
          self._xredir = args.next()
        except StopIteration:
          break

    self._orig_root = self.root
    self._pass_args = pass_args
    self._need_x = need_x

    self._pass_args.append('--xre-path')

    self.add_option('--harness-root-dir',
                    dest='root',
                    help='Override the path to the test harness installation')
    if self._need_x:
      self.add_option('--own-session',
                      action='store_true', dest='wantOwnSession', default=False,
                      help='Run the test inside its own X session')

    if not os.path.exists(os.path.join(self.root, runner)):
      for f in os.listdir(self.root):
        if re.match(r'[a-z\-]*-[0-9\.ab]*\.en-US\.linux-\S*\.tests\.zip', f) or f == 'extra.test.zip':
          os.system('unzip -qu %s -d %s' % (os.path.join(self.root, f), self._tmpdir))

      assert os.path.exists(os.path.join(self._tmpdir, runner))
      self.root = self._tmpdir

    runner = os.path.join(self.root, runner)
    sys.path.insert(0, os.path.dirname(runner))

    for path in reversed(paths):
      sys.path.insert(0, os.path.join(self.root, path))

    self._runner_global = {}
    self._runner_global['__file__'] = runner
    saved_argv0 = sys.argv[0]
    saved_cwd = os.getcwd()
    sys.argv[0] = runner
    os.chdir(self.root)
    try:
      execfile(runner, self._runner_global)

      runner_parser = get_runner_parser_cb(self._runner_global)

      for arg in self._pass_args:
        assert runner_parser.has_option(arg)
        self.add_option(runner_parser.get_option(arg))

    finally:
      sys.argv[0] = saved_argv0
      os.chdir(saved_cwd)

  @property
  def _tmpdir(self):
    if self.__tmpdir != None:
      return self.__tmpdir

    self.__tmpdir = create_tmpdir()
    return self.__tmpdir

  @property
  def xredir(self):
    if self._xredir != None:
      return self._xredir

    if self.root != self._orig_root:
      # This allows us to run with the harness root set to objdir/dist (which should contain
      # a testsuite tarball)
      # Note, our install layout mimics this
      libxul = os.path.join(self._orig_root, 'bin', 'libxul.so')
    else:
      # This allows us to run with the harness root set to objdir/dist/test-package-stage
      libxul = os.path.join(self.root, os.pardir, 'bin', 'libxul.so')

    if os.path.exists(libxul):
      self._xredir = os.path.dirname(libxul)
    else:
      libxul = os.path.join(os.path.dirname(__file__), os.pardir, 'libxul.so')
      if os.path.exists(libxul):
        self._xredir = os.path.dirname(libxul)

    return self._xredir

  def run(self, defaults=[], pre_run_cb=None):
    (options, args) = self.parse_args()

    if os.getenv('DESKTOP_AUTOSTART_ID') == None:
      # If we were started by the session manager, use the current homedir
      os.mkdir(os.path.join(self._tmpdir, 'home'))
      for name in skel:
        os.system('mkdir -p %s' % os.path.dirname(os.path.join(self._tmpdir, 'home', name))) 
        with open(os.path.join(self._tmpdir, 'home', name), 'w+') as f:
          print >>f, skel[name]

      os.environ['HOME'] = os.path.join(self._tmpdir, 'home')

    try:
      if self._need_x and (options.wantOwnSession or os.getenv('DISPLAY') == None):
        import subprocess

        i = 0
        while len(sys.argv) > 0 and len(sys.argv) > i:
          arg = sys.argv[i]
          if arg == '--own-session':
            del sys.argv[i]
          elif arg == '--harness-root-dir':
            del sys.argv[i]
            del sys.argv[i]
          else:
            i += 1

        extra_args = ['--harness-root-dir', self.root]
        if '--xre-path' not in sys.argv and self.xredir != None:
          extra_args.extend(['--xre-path', self.xredir])

        os.environ['UBUNTU_MOZ_TEST_ARGS'] = ' '.join(extra_args + sys.argv[1:])
        os.environ['UBUNTU_MOZ_TEST_RUNNER'] = sys.executable + ' ' + sys.argv[0]
        session_args = ['xvfb-run', '-a', '-s', '-screen 0 1280x1024x24 -extension MIT-SCREEN-SAVER', 'dbus-launch', '--exit-with-session', 'gnome-session', '--session', 'test']
        subprocess.call(session_args, stdin=sys.stdin, stdout=sys.stdout, stderr=sys.stderr)

        if not os.path.exists(os.path.join(os.environ['HOME'], '.test_return')):
          return 1
        with open(os.path.join(os.environ['HOME'], '.test_return'), 'r') as f:
          return int(f.read().strip())

      os.environ['MOZ_PLUGIN_PATH'] = os.path.join(self.root, 'bin/plugins')

      sys.argv = []
      argv = sys.argv
      argv.append(self._runner_global['__file__'])

      for arg in self._pass_args:
        opt = self.get_option(arg)
        action = opt.action
        val = getattr(options, opt.dest)
        if val == opt.default and action != 'append':
          continue
        if action == 'store':
          if val != None:
            argv.extend([arg, str(val)])
        elif action == 'store_true':
          if val == True:
            argv.append(arg)
        elif action == 'store_false':
          if val == False:
            argv.append(arg)
        elif action == 'append':
          if val != None:
            for v in val:
              argv.extend([arg, str(v)])
        else:
          raise RuntimeError('Unexpected argument type with action "%s"' % action)

      for arg in defaults:
        if arg not in argv:
          argv.extend([arg, defaults[arg]() if hasattr(defaults[arg], '__call__') else defaults[arg]])

      if '--xre-path' not in sys.argv and self.xredir != None:
        argv.extend(['--xre-path', self.xredir])

      if pre_run_cb != None:
        pre_run_cb(options, args)

      argv.extend(args)
      os.chdir(self.root)
      return self._runner_global['main']()

    except Exception:
      with open(os.path.join(os.getenv('HOME'), '.test_return'), 'w+') as f:
        print >>f, '1'

      traceback.print_exc()

    finally:
      if os.getenv('DESKTOP_AUTOSTART_ID') != None:
        if not os.path.exists(os.path.join(os.getenv('HOME'), '.test_return')):
          with open(os.path.join(os.getenv('HOME'), '.test_return'), 'w+') as f:
            print >>f, '0'
        i = 0
        while i < 5:
          os.system('gnome-session-quit --logout --no-prompt --force')
          i += 1
          time.sleep(10)
