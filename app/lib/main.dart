import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:app/grpc_generated/client.dart';
import 'package:app/grpc_generated/init_py.dart';
import 'package:app/grpc_generated/init_py_native.dart';
import 'package:grpc/grpc.dart';
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

enum ScreenStates { notReady, ready, loading, animating }

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
  ResponseStream<HeightMapResponse>? grpcStream;
  ScreenStates screenState = ScreenStates.notReady;
  List<int> heightValues = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pixelRatio = WidgetsBinding
        .instance.platformDispatcher.displays.first.devicePixelRatio;

    pyInitResult
        .onError(
            (error, stackTrace) => setState(() => error = error.toString()))
        .whenComplete(() => setState(() => screenState = ScreenStates.ready));
  }

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
                    values: heightValues,
                    width: lastWidth,
                    height: lastHeight,
                    pixelRatio: pixelRatio),
                if (screenState == ScreenStates.loading)
                  const Positioned(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 6)),
                Positioned(
                    top: 15,
                    child: Text(
                        '${(lastWidth * pixelRatio).toInt()} x ${(lastHeight * pixelRatio).toInt()} · ${position.toStringAsFixed(2)}')),
                Positioned(
                    bottom: 15,
                    child: _BottomPanel(
                      screenState: screenState,
                      error: error,
                      onOneFrame: () {
                        _prepBeforeGrpcCall(constraints, ScreenStates.loading);
                        JuliaSetGeneratorServiceClient(getClientChannel())
                            .getSetAsHeightMap(HeightMapRequest(
                                width: (lastWidth * pixelRatio).toInt(),
                                height: (lastHeight * pixelRatio).toInt(),
                                threshold: threshold,
                                position: position))
                            .then((value) => setState(() {
                                  heightValues = value.heightMap;
                                  if (value.heightMap.length !=
                                      (lastWidth * pixelRatio).toInt() *
                                          (lastHeight * pixelRatio).toInt()) {
                                    _onGrpcCallError(
                                        'Invalid length of height map',
                                        context);
                                  }
                                  position += 0.05;
                                  _setScreenState(ScreenStates.ready);
                                }))
                            .onError((error, stackTrace) =>
                                _onGrpcCallError(error.toString(), context));
                      },
                      onPlay: () {
                        _prepBeforeGrpcCall(
                            constraints, ScreenStates.animating);
                        grpcStream =
                            JuliaSetGeneratorServiceClient(getClientChannel())
                                .getSetAsHeightMapStream(HeightMapRequest(
                                    width: (lastWidth * pixelRatio).toInt(),
                                    height: (lastHeight * pixelRatio).toInt(),
                                    threshold: threshold,
                                    position: position));

                        grpcStream!.listen(
                            (value) {
                              heightValues = value.heightMap;
                              if (value.heightMap.length !=
                                  (lastWidth * pixelRatio).toInt() *
                                      (lastHeight * pixelRatio).toInt()) {
                                _onGrpcCallError(
                                    'Invalid length of height map', context);
                              }
                              position = value.position;
                              _setScreenState(ScreenStates.animating);
                            },
                            cancelOnError: true,
                            onError: (error, stackTrace) {
                              if (error is GrpcError && error.code == 1) {
                                return; // grpc call canceled
                              }
                              _onGrpcCallError(error.toString(), context);
                            });
                      },
                      onPause: () {
                        grpcStream?.cancel();
                        _setScreenState(ScreenStates.ready);
                      },
                    ))
              ]),
        )));
  }

  void _setScreenState(ScreenStates state) {
    setState(() {
      screenState = state;
    });
  }

  void _prepBeforeGrpcCall(BoxConstraints constraints, ScreenStates state) {
    lastWidth = constraints.maxWidth;
    lastHeight = constraints.maxHeight;
    setState(() {
      screenState = state;
    });
  }

  void _onGrpcCallError(String error, BuildContext context) {
    setState(() {
      screenState = ScreenStates.ready;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('An error occured\n$error')));
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel(
      {required this.screenState,
      this.error = '',
      required this.onOneFrame,
      required this.onPlay,
      required this.onPause});

  final ScreenStates screenState;
  final String error;
  final Function onOneFrame;
  final Function onPlay;
  final Function onPause;

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
                error.isEmpty && screenState == ScreenStates.notReady
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
                        : Tooltip(
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
                    backgroundColor: Colors.white,
                    foregroundColor: screenState == ScreenStates.ready
                        ? null
                        : Colors.grey[200],
                    tooltip: 'One frame',
                    onPressed: screenState == ScreenStates.ready
                        ? () => onOneFrame()
                        : null,
                    child: const Icon(Icons.skip_next_rounded)),
                FloatingActionButton(
                    backgroundColor: Colors.white,
                    tooltip: 'Play animation',
                    onPressed: screenState == ScreenStates.animating
                        ? () => onPause()
                        : () => onPlay(),
                    child: screenState == ScreenStates.animating
                        ? const Icon(Icons.pause_rounded)
                        : const Icon(Icons.play_arrow_rounded))
              ]),
        ));
  }
}

class _Fractals extends StatefulWidget {
  const _Fractals(
      {required this.values,
      required this.width,
      required this.height,
      required this.pixelRatio});

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
        oldWidget.values != widget.values) {
      var pWidth = (widget.width * widget.pixelRatio).toInt();
      var pHeight = (widget.height * widget.pixelRatio).toInt();

      if (widget.values.isNotEmpty &&
          widget.values.length == pWidth * pHeight) {
        getImage(pWidth, pHeight, widget.values).then((value) {
          if (image != null) {
            image!.dispose();
            image = null;
          }
          setState(() => image = value);
        });
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
    return RawImage(
        image: image,
        width: widget.height.toDouble(),
        height: widget.height.toDouble());
  }
}
