// ignore_for_file: sort_child_properties_last

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:app/grpc_generated/client.dart';
import 'package:app/grpc_generated/init_py.dart';
import 'package:app/grpc_generated/init_py_native.dart';
import 'dart:math';

import 'grpc_generated/set_generator.pbgrpc.dart';

const threshold = 100;
const position = 0.5;

Future<void> pyInitResult = Future(() => null);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  pyInitResult = initPy();

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  MainAppState createState() => MainAppState();
}

enum ViewStates { notReady, ready, loading }

class MainAppState extends State<MainApp> with WidgetsBindingObserver {
  @override
  Future<AppExitResponse> didRequestAppExit() {
    shutdownPyIfAny();
    return super.didRequestAppExit();
  }

  double pixelRatio = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pixelRatio = WidgetsBinding
        .instance.platformDispatcher.displays.first.devicePixelRatio;
  }

  ViewStates viewState = ViewStates.notReady;
  List<int> values = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
            body: LayoutBuilder(
          builder: (context, constraints) =>
              Stack(alignment: Alignment.center, children: [
            _Fractals(
                ready: viewState == ViewStates.ready,
                values: values,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                pixelRatio: pixelRatio),
            if (viewState == ViewStates.loading)
              const CircularProgressIndicator(strokeWidth: 6),
            Positioned(
                bottom: 15,
                child: Material(
                    elevation: 10,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    child: Container(
                      width: 180,
                      height: 48,
                      padding: const EdgeInsets.all(8),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            FutureBuilder<void>(
                              future: pyInitResult,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 6));
                                } else if (snapshot.hasError) {
                                  return Tooltip(
                                    message: 'Error: ${snapshot.error}',
                                    child: const Icon(
                                      Icons.circle,
                                      color: Colors.red,
                                    ),
                                  );
                                } else {
                                  // When future completes, display a message saying that Python has been loaded

                                  if (snapshot.hasData) {
                                    Future(() => setState(() {
                                          viewState = ViewStates.ready;
                                        }));
                                  }
                                  return Tooltip(
                                    richMessage: TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: 'Using ',
                                        ),
                                        TextSpan(
                                          text: '$defaultHost:$defaultPort',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              ', ${localPyStartSkipped ? 'skipped launching local server' : 'launched local server'}',
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.circle,
                                      color: Colors.green,
                                    ),
                                  );
                                }
                              },
                            ),
                            FloatingActionButton(
                              child: const Icon(Icons.skip_next_rounded),
                              tooltip: 'One frame',
                              onPressed: () {
                                setState(() {
                                  viewState = ViewStates.loading;
                                });
                                JuliaSetGeneratorServiceClient(
                                        getClientChannel())
                                    .getSetAsHeightMap(HeightMapRequest(
                                        width:
                                            (constraints.maxWidth * pixelRatio)
                                                .toInt(),
                                        height:
                                            (constraints.maxHeight * pixelRatio)
                                                .toInt(),
                                        threshold: threshold,
                                        position: position))
                                    .then((p0) => setState(() {
                                          values = p0.heightMap;
                                          setState(() {
                                            viewState = ViewStates.ready;
                                          });
                                        }))
                                    .onError((error, stackTrace) {
                                  setState(() {
                                    viewState = ViewStates.ready;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'An error occured\n$error')));
                                });
                              },
                            ),
                            FloatingActionButton(
                                child: const Icon(Icons.play_arrow_rounded),
                                tooltip: 'Play animation',
                                onPressed: () {})
                          ]),
                    )))
          ]),
        )));
  }
}

class _Fractals extends StatelessWidget {
  const _Fractals(
      {required this.ready,
      required this.values,
      required this.width,
      required this.height,
      required this.pixelRatio});

  final bool ready;
  final List<int> values;
  final double width;
  final double height;
  final double pixelRatio;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width.toDouble(),
      height: height.toDouble(),
      child: !ready || values.isEmpty
          ? const Center(child: Text('Fractals will be displayed here...'))
          : CustomPaint(
              painter: HeightMapPainter(
                  width: (width * pixelRatio).toInt(),
                  height: (height * pixelRatio).toInt(),
                  values: values)),
    );
  }
}

class HeightMapPainter extends CustomPainter {
  final int width;
  final int height;
  final List<int> values;

  HeightMapPainter(
      {required this.width, required this.height, required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 1.0;

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        var iter = values[y * width + x] + 1;
        // paint.color = Color.fromRGBO(iter, iter, iter, 1);
        paint.color = Color.fromRGBO(
            255 * (1 + cos(3.32 * log(iter))) ~/ 2,
            255 * (1 + cos(0.774 * log(iter))) ~/ 2,
            255 * (1 + cos(0.412 * log(iter))) ~/ 2,
            1);
        // Put pixel
        canvas.drawPoints(PointMode.points,
            <Offset>[Offset(x.toDouble(), y.toDouble())], paint);
      }
    }
  }

  @override
  bool shouldRepaint(HeightMapPainter oldDelegate) => true;
}
