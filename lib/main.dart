import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_plot/flutter_plot.dart';

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
      Meter? meter;
      var handshook = false;
      var samplelen = -1;
      final buffer = <int>[];
      client.listen((b) {
        if (handshook) {
          buffer.add(b);
          if (buffer.length == samplelen) {
            final s = ByteData.sublistView(Uint8List.fromList(buffer));
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
            buffer.clear();
          }
        } else if (jsonlenbytes.length < 4) {
          jsonlenbytes.add(b);
          if (jsonlenbytes.length == 4) {
            jsonlen = ByteData.sublistView(Uint8List.fromList(jsonlenbytes))
                .getUint32(0, Endian.big);
          }
        } else {
          buffer.add(b);
          if (buffer.length == jsonlen) {
            meter = Meter.fromJson(jsonDecode(utf8.decode(buffer)));
            meters.add(meter!);
            samplelen =
                meter!.probes.map((e) => e.size).reduce((v, e) => v + e);
            buffer.clear();
            handshook = true;
          }
        }
      });
    });
  }

  List<Point> meterToPoints(Meter meter) {
    final d = meter.probes
        .map((p) => p.data.map((d) => d * p.scale).toList())
        .toList();
    assert(d.length == 2);
    assert(d[0].length == d[1].length);
    return [for (var i = 0; i < d.first.length; i++) Point(d[0][i], d[1][i])];
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
            Text(meters.toString()),
            meters.length > 0
                ? Plot(
                    data: meterToPoints(meters.first),
                    style: PlotStyle(textStyle: TextStyle(), trace: true),
                    gridSize: Offset(1, 1),
                    padding: EdgeInsets.all(1),
                  )
                : Container(),
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
