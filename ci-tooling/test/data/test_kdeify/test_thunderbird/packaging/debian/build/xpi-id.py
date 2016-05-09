#!/usr/bin/python

import sys
import xml.dom.minidom
import os
import zipfile

if __name__ == '__main__':
    if not len(sys.argv) == 2:
        print >> sys.stderr, "Must specify an xpi"
        exit(1)

    dom_doc = xml.dom.minidom.parseString(zipfile.ZipFile(sys.argv[1]).open('install.rdf').read().strip())

    try:
        attr = dom_doc.getElementsByTagName('RDF:Description')[0].attributes['em:id']
    except IndexError:
        attr = dom_doc.getElementsByTagName('Description')[0].attributes['em:id']

    assert attr.value
    print "%s" % attr.value
    exit(0)
