#!/usr/bin/python

import os
import sys

class JsonValue:
    """
    A class to serialize Python values into JSON-compatible representations.
    """
    def __init__(self, v):
        if v is not None and not (isinstance(v,str) or isinstance(v,bool) or isinstance(v,int)):
            raise Exception("Unhandled data type: %s" % type(v))
        self.v = v
    def __repr__(self):
        if self.v is None:
            return "null"
        if isinstance(self.v,bool):
            return str(self.v).lower()
        return repr(self.v)

def jsonify(d):
    """
    Return a JSON string of the dict |d|. Only handles a subset of Python
    value types: bool, str, int, None.
    """
    jd = {}
    for k, v in d.iteritems():
        jd[k] = JsonValue(v)
    return repr(jd)

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print >>sys.stderr, "Must specify a single file and appname"

    with open(sys.argv[1], 'r') as f:
        s = eval(f.read(),{'true':True,'false':False,'null':None})
        s['appname'] = sys.argv[2]

        with open(sys.argv[1] + '.tmp', 'w') as g:
            g.write(jsonify(s))

    os.rename(sys.argv[1] + '.tmp', sys.argv[1])
