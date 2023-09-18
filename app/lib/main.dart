// ignore_for_file: sort_child_properties_last

import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:app/grpc_generated/client.dart';
import 'package:app/grpc_generated/init_py.dart';
import 'package:app/grpc_generated/init_py_native.dart';
import 'dart:math';
import 'dart:ui' as ui;

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
  double position = 0.0;
  String error = '';
  double lastWidth = 0;
  double lastHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pixelRatio = WidgetsBinding
        .instance.platformDispatcher.displays.first.devicePixelRatio;

    pyInitResult
        .onError(
            (error, stackTrace) => setState(() => error = error.toString()))
        .whenComplete(() => setState(() => viewState = ViewStates.ready));
  }

  ViewStates viewState = ViewStates.notReady;
  List<int> values = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
            body: LayoutBuilder(
          builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                _Fractals(
                    ready: viewState == ViewStates.ready,
                    values: values,
                    width: lastWidth,
                    height: lastHeight,
                    // width: 100,
                    // height: 100,
                    pixelRatio: pixelRatio),
                if (viewState == ViewStates.loading)
                  const Positioned(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 6)),
                Positioned(
                    top: 15,
                    child: Text(
                        '${(lastWidth * pixelRatio).toInt()} x ${(lastHeight * pixelRatio).toInt()}')),
                Positioned(
                    bottom: 15,
                    child: _BottomPanel(
                      viewState: viewState,
                      error: error,
                      onOneFrame: () {
                        setState(() {
                          viewState = ViewStates.loading;
                        });
                        lastWidth = constraints.maxWidth;
                        lastHeight = constraints.maxHeight;
                        JuliaSetGeneratorServiceClient(getClientChannel())
                            .getSetAsHeightMap(HeightMapRequest(
                                width: (lastWidth * pixelRatio).toInt(),
                                height: (lastHeight * pixelRatio).toInt(),
                                // width: 100,
                                // height: 100,
                                threshold: threshold,
                                position: position))
                            .then((p0) => setState(() {
                                  values = p0.heightMap;
                                  if (p0.heightMap.length !=
                                      (lastWidth * pixelRatio).toInt() *
                                          (lastHeight * pixelRatio).toInt()) {
                                    throw 'Invalid length of height map';
                                  }
                                  position += 0.05;
                                  setState(() {
                                    viewState = ViewStates.ready;
                                  });
                                }))
                            .onError((error, stackTrace) {
                          setState(() {
                            viewState = ViewStates.ready;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('An error occured\n$error')));
                        });
                      },
                      onPlay: () {},
                    ))
              ]),
        )));
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel(
      {required this.viewState,
      this.error = '',
      required this.onOneFrame,
      required this.onPlay});

  final ViewStates viewState;
  final String error;
  final Function onOneFrame;
  final Function onPlay;

  @override
  Widget build(BuildContext context) {
    return Material(
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
                error.isEmpty && viewState == ViewStates.notReady
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 6))
                    : (error.isNotEmpty
                        ? Tooltip(
                            message: 'Error: $error}',
                            child: const Icon(
                              Icons.circle,
                              color: Colors.red,
                            ))
                        :
                        // When future completes, display a message saying that Python has been loaded
                        Tooltip(
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
                            ))),
                FloatingActionButton(
                    child: const Icon(Icons.skip_next_rounded),
                    backgroundColor: Colors.white,
                    foregroundColor:
                        viewState == ViewStates.ready ? null : Colors.grey[200],
                    tooltip: 'One frame',
                    onPressed: viewState == ViewStates.ready
                        ? () => onOneFrame()
                        : null),
                FloatingActionButton(
                    child: const Icon(Icons.play_arrow_rounded),
                    backgroundColor: Colors.white,
                    foregroundColor:
                        viewState == ViewStates.ready ? null : Colors.grey[200],
                    tooltip: 'Play animation',
                    onPressed:
                        viewState == ViewStates.ready ? () => onPlay() : null)
              ]),
        ));
  }
}

class _Fractals extends StatefulWidget {
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
  State<_Fractals> createState() => _FractalsState();
}

class _FractalsState extends State<_Fractals> {
  ui.Image? image;

  @override
  void didUpdateWidget(_Fractals oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.height != widget.height ||
        oldWidget.width != widget.width ||
        oldWidget.values.hashCode != widget.values.hashCode) {
      if (image != null) {
        image!.dispose();
        image = null;
      }

      var pWidth = (widget.width * widget.pixelRatio).toInt();
      var pHeight = (widget.height * widget.pixelRatio).toInt();

      if (widget.values.isNotEmpty &&
          widget.values.length == pWidth * pHeight) {
        getImage(pWidth, pHeight, widget.values)
            .then((value) => setState(() => image = value));
      }
    }
  }

  Future<ui.Image> getImage(int width, int height, List<int> values) async {
    final pixelData = Uint32List(values.length);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        var pos = y * width + x;
        var iter = values[pos] + 1;
        //pixelData[pos] = 0xFF000000 + iter + iter << 8 + iter << 16;
        pixelData[pos] = 0xFF000000 +
            255 * (1 + cos(3.32 * log(iter))) ~/ 2 +
            (255 * 256 * (1 + cos(0.774 * log(iter))) ~/ 2) +
            (255 * 256 * 256 * (1 + cos(0.412 * log(iter))) ~/ 2);
      }
    }

    var buffer =
        await ImmutableBuffer.fromUint8List(pixelData.buffer.asUint8List());
    var codec = await ImageDescriptor.raw(buffer,
            width: width, height: height, pixelFormat: PixelFormat.rgba8888)
        .instantiateCodec(targetWidth: width, targetHeight: height);
    var frame = await codec.getNextFrame();

    //buffer.dispose();

    return frame.image;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: widget.width.toDouble(),
        height: widget.height.toDouble(),
        child: widget.ready && image != null
            ? RawImage(image: image)
            : const Center(child: Text('Fractals will be displayed here...')));
  }
}
