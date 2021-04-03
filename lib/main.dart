import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

void main() async {
  runApp(MyApp(await ServerSocket.bind(InternetAddress.anyIPv4, 14258)));
}

class MyApp extends StatelessWidget {
  MyApp(this.sock);
  final ServerSocket sock;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(sock),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage(this.sock);
  final ServerSocket sock;
  @override
  _MyHomePageState createState() => _MyHomePageState(sock);
}

class _MyHomePageState extends State<MyHomePage> {
  final meters = <Meter>[];

  _MyHomePageState(ServerSocket sock) {
    sock.listen((c) async {
      final client = c.transform(StreamTransformer<Uint8List, int>.fromHandlers(
          handleData: (data, sink) => data.forEach((i) => sink.add(i))));

      final jsonlenbytes = <int>[];
      var jsonlen = -1;
      final jsonbytes = <int>[];
      Meter? meter;
      var handshook = false;
      var samplelen = -1;
      final samplebuffer = <int>[];
      client.listen((b) {
        if (handshook) {
          samplebuffer.add(b);
          if (samplebuffer.length == samplelen) {
            final s = ByteData.sublistView(Uint8List.fromList(samplebuffer));
            var i = 0;
            for (final p in meter!.probes) {
              final f = p.size == 1
                  ? (i, e) => (p.signed ? s.getInt8(i) : s.getUint8(i))
                  : p.size == 2
                      ? (p.signed ? s.getInt16 : s.getUint16)
                      : p.size == 4
                          ? (p.signed ? s.getInt32 : s.getUint32)
                          : p.size == 8
                              ? (p.signed ? s.getInt64 : s.getUint64)
                              : throw 'unknown p.size';
              p.data.add(f(i, Endian.big));
              i += p.size;
            }
            samplebuffer.clear();
          }
        } else if (jsonlenbytes.length < 4) {
          jsonlenbytes.add(b);
          if (jsonlenbytes.length == 4) {
            jsonlen = ByteData.sublistView(Uint8List.fromList(jsonlenbytes))
                .getUint32(0, Endian.big);
          }
        } else {
          jsonbytes.add(b);
          if (jsonbytes.length == jsonlen) {
            meter = Meter.fromJson(jsonDecode(utf8.decode(jsonbytes)));
            meters.add(meter!);
            samplelen =
                meter!.probes.map((e) => e.size).reduce((v, e) => v + e);
            handshook = true;
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Demo Home Page'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              meters.toString(),
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {}),
      ),
    );
  }
}

class Probe {
  final String type, name;
  final int res;
  final bool signed;
  final double scale;
  final List<int> data;

  Probe(this.name, this.type, res, this.scale, this.data)
      : this.res = res < 0 ? -res : res,
        this.signed = res < 0;

  static Probe fromJson(dynamic json) =>
      Probe(json['name'], json['type'], json['res'], json['scale'], []);

  int get size => res == 0
      ? 0
      : res < 9
          ? 1
          : res < 17
              ? 2
              : res < 33
                  ? 4
                  : res < 65
                      ? 8
                      : throw 'res too big';

  String toString() => '$name:$type {res:$res,sign:$signed,scale:$scale} $data';
}

class Meter {
  final String name;
  final List<Probe> probes;

  Meter(this.name, this.probes);

  static Meter fromJson(dynamic json) => Meter(json['name'],
      json['probes'].map<Probe>((e) => Probe.fromJson(e)).toList());

  String toString() => '$name $probes';
}
