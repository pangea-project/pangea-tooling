#!/usr/bin/python

import datetime
import os
import select
import subprocess
import sys
import thread

proc = None

def run_child(args, fd):
  global proc

  f = os.fdopen(fd, 'w')
  proc = subprocess.Popen(args)

  # Tell main thread to continue
  f.write('a')
  f.flush()

  f.write(str(proc.wait()))

def main():
  global proc

  def usage():
    sys.stderr.write('Usage: %s <max_minutes> <cmd> [<args> ..]\n' % sys.argv[0])
    sys.exit(1)

  if len(sys.argv) < 3:
    usage()

  try:
    max_mins = int(sys.argv[1])
  except:
    usage()

  max_days = max_mins / (24 * 60)
  max_seconds = (max_mins % (max_days * 24 * 60) if max_days > 0 else max_mins) * 60

  start = datetime.datetime.now()

  (rfd, wfd) = os.pipe()
  f = os.fdopen(rfd, 'r')
  thread.start_new_thread(run_child, (sys.argv[2:], wfd))

  # Make sure that we have a process before continuing
  f.read(1)

  target_timeout = 60

  last_target_timeout = target_timeout
  timeout = target_timeout
  terminated = False
  laststart = None

  while True:
    if target_timeout != last_target_timeout:
      last_target_timeout = target_timeout
      timeout = target_timeout
    elif laststart is not None:
      now = datetime.datetime.now()
      timeout = timeout - (((now - laststart).total_seconds() - target_timeout) / 4)
    laststart = datetime.datetime.now()

    (r, w, x) = select.select([f], [], [], timeout)
    if len(r) != 0:
      sys.exit(int(f.read()))

    duration = datetime.datetime.now() - start

    if not terminated:
      sys.stdout.write('*** KEEP ALIVE MARKER ***\n')
      sys.stdout.write('Total duration: %s\n' % str(duration))
      sys.stdout.flush()

    if (duration.days >= max_days and duration.seconds >= max_seconds) or terminated:
      if not terminated:
        sys.stderr.write('Process max time exceeded, attempting to terminate\n')
        sys.stderr.flush()
        proc.terminate()
        terminated = True
        target_timeout = 15
      else:
        sys.stderr.write('Attempting to kill process\n')
        sys.stderr.flush()
        proc.kill()

if __name__ == '__main__':
  main()
