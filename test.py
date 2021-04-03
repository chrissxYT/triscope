#!/usr/bin/env python3

import json
import random
import socket
import struct
import time

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect(("127.0.0.1", 14258))
infojson = json.dumps({'name': 'Test Meter', 'probes': [
    {'name': 'Bad TSC', 'type': 'time', 'res': 32, 'scale': 1.0},
    {'name': 'Fake Amps', 'type': 'current', 'res': 32, 'scale': .001}]}).encode('utf-8')
sock.send(struct.pack('>I', len(infojson)))
sock.send(infojson)
timestamp = 0
while True:
    sock.send(struct.pack('>I', timestamp))
    sock.send(struct.pack('>I', random.randint(1, 30000)))
    timestamp += 1
    time.sleep(1)
