#!/usr/bin/python

import re
import socket

host = socket.gethostname()

if re.search(r'\bliferay\b', host):
    group = 'work'
elif re.match(r'retiro(?:\.(?:local|lan)?)?\Z', host):
    group = 'personal'
elif re.match(r'\bworkstation\b', host):
    group = 'workstation'
else:
    group = 'local'

print ("""
{
  "%s": {
    "hosts": [
      "localhost"
    ],
    "vars": {
      "ansible_connection": "local"
    }
  }
}
""" % group)
