#!/usr/bin/python

from __future__ import print_function
from fnmatch import fnmatch
from glob import glob
from optparse import OptionParser
import json
import os.path
import shutil
import sys

def find_locale_match(locale, locales):
  return any(fnmatch(locale, i) for i in locales)

def install_one_override(config, options):
  print("Handling override for '%s'" % config["name"])

  if ("exclude_locales" in config and
      find_locale_match(options.locale, config["exclude_locales"])):
    print("No override for this locale (exclude_locales)")
    return

  match = config["match"]
  source = config["source"]

  if "locale_specific" in config:
    for i in config["locale_specific"]:
      if find_locale_match(options.locale, i["locales"]):
        match = i["match"]
        source = i["source"]
        break

  include = find_locale_match(options.locale, config["include_locales"])

  m = glob(os.path.join(options.stagedir, match))
  if len(m) == 0:
    if include:
      print("Cannot find search plugin to override for '%s'" % config["name"], file=sys.stderr)
      sys.exit(1)
    print("No override for this locale (include_locales)")
    return

  if not include:
    print("Found search plugin to override for '%s' even though it's not in "
          "include_dirs. Please check if it should be included" % config["name"])
    sys.exit(1)

  if len(m) > 1:
    print("More than one search plugin found for '%s'" % config["name"], file=sys.stderr)
    sys.exit(1)

  found = m[0]

  try:
    os.makedirs(options.destdir)
  except:
    pass

  s = os.path.join(options.srcdir, source)
  d = os.path.join(options.destdir, os.path.basename(found))
  print("Installing %s in to %s" % (s, d))
  shutil.copy(s, d)

def install_overrides(config, options):
  for i in config: install_one_override(i, options)

def install_one_addition(config, options):
  print("Handling addition for '%s'" % config["name"])

  if ("exclude_locales" in config and
      find_locale_match(options.locale, config["exclude_locales"])):
    print("No addition for this locale (exclude_locales)")
    return

  if (not find_locale_match(options.locale, config["include_locales"])):
    print("No addition for this locale (include_locales)")
    return

  s = os.path.join(options.srcdir, config["source"])
  d = os.path.join(options.destdir, os.path.basename(s))

  if os.path.exists(os.path.join(options.stagedir, os.path.basename(s))):
    print("There is already a searchplugin with this filename for '%s'" % config["name"])
    sys.exit(1)

  print("Installing %s in to %s" % (s, d))
  shutil.copy(s, d)

def install_additions(config, options):
  for i in config: install_one_addition(i, options)

def main(argv):
  parser = OptionParser("usage: %prog [options]")
  parser.add_option("-c", "--config", dest="config", help="Location of the config file")
  parser.add_option("-l", "--locale", dest="locale", help="The locale to install")
  parser.add_option("-u", "--stagedir", dest="stagedir")
  parser.add_option("-d", "--destdir", dest="destdir")
  parser.add_option("-s", "--srcdir", dest="srcdir")

  (options, args) = parser.parse_args(args=argv)

  if (any(getattr(options, o) == None for o in ["config", "locale", "stagedir", "destdir", "srcdir"])):
    print("Missing option", file=sys.stderr)
    sys.exit(1)

  config = {}
  with open(options.config, "r") as fd:
    config = json.load(fd)

  if "overrides" in config:
    install_overrides(config["overrides"], options)
  if "additions" in config:
    install_additions(config["additions"], options)

if __name__ == "__main__":
  main(sys.argv[1:])
