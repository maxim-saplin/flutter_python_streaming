import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:app/grpc_generated/client.dart';
import 'package:app/grpc_generated/init_py.dart';
import 'package:app/grpc_generated/init_py_native.dart';
import 'dart:math';

import 'grpc_generated/set_generator.pbgrpc.dart';

const width = 64;
const height = 64;
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

class MainAppState extends State<MainApp> with WidgetsBindingObserver {
  @override
  Future<AppExitResponse> didRequestAppExit() {
    shutdownPyIfAny();
    return super.didRequestAppExit();
  }

  var widthPixels = 0;
  var heightPixels = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widthPixels = (width *
            WidgetsBinding
                .instance.platformDispatcher.displays.first.devicePixelRatio)
        .toInt();

    heightPixels = (height *
            WidgetsBinding
                .instance.platformDispatcher.displays.first.devicePixelRatio)
        .toInt();
  }

  // List<int> numList = [];

  bool ready = false;
  List<int> values = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      body: Stack(alignment: Alignment.bottomCenter, children: [
        Container(
          padding: const EdgeInsets.all(20),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: width.toDouble(),
                height: height.toDouble(),
                child: !ready || values.isEmpty
                    ? const Text('Awating...')
                    : CustomPaint(
                        painter: HeightMapPainter(
                            width: widthPixels,
                            height: heightPixels,
                            values: values)),
              ),
            ],
          ),
        ),
        Padding(
            padding: const EdgeInsets.all(10),
            child: // Set the borderRadius property of the Container widget to make it rounded
                Container(
              width: 140,
              height: 40,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[300],
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                FutureBuilder<void>(
                  future: pyInitResult,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 6));
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
                      Future(() => setState(() {
                            ready = true;
                          }));
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
                SizedBox(
                    height: 30,
                    child: IconButton(
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: () {
                        setState(() {});
                        JuliaSetGeneratorServiceClient(getClientChannel())
                            .getSetAsHeightMap(HeightMapRequest(
                                width: widthPixels,
                                height: heightPixels,
                                threshold: threshold,
                                position: position))
                            .then((p0) => setState(() {
                                  values = p0.heightMap;
                                }));
                      },
                    ))
              ]),
            ))
      ]),
    ));
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
