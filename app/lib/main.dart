import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import 'package:popover/popover.dart';

import 'grpc_generated/client.dart';
import 'grpc_generated/init_py.dart';
import 'julia_service.dart' as service;

// Config the looks of Julia set
const threshold = 100; // Must not be larger than 255
const initialPosition = 0.5; // any number, full period is 1.0

// Global state, in prod app it's better to keep it somewhere else (e.g. Provider) rather than in global vars
int lastFrameReceivedMicro = 10000;
int previousFrameReceivedMicro = 0;
Stopwatch sw = Stopwatch()..start();
int frameCount = 0;
service.FetchModes fetchMode = service.FetchModes.grpcRepeatedInt32;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  pyInitResult = initPy();

  runApp(const MainApp());
}

Future<void> pyInitResult = Future(() => null);

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  MainAppState createState() => MainAppState();
}

enum ScreenStates { notReady, ready, loading, animating }

class MainAppState extends State<MainApp> with WidgetsBindingObserver {
  @override
  Future<ui.AppExitResponse> didRequestAppExit() {
    shutdownPyIfAny();
    return super.didRequestAppExit();
  }

  double pixelRatio = 0;
  double position = 0.0;
  String error = '';
  double lastWidth = 0;
  double lastHeight = 0;
  ScreenStates screenState = ScreenStates.notReady;
  List<int> heightValues = [];
  service.CancelationToken cancelationToken = () {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pixelRatio = WidgetsBinding
        .instance.platformDispatcher.displays.first.devicePixelRatio;

    pyInitResult.then((v) => _setScreenState(ScreenStates.ready),
        onError: (error, stackTrace) {
      setState(() => this.error = error.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
            body: LayoutBuilder(
                builder: (context, constraints) => SafeArea(
                      child: Stack(
                          fit: StackFit.expand,
                          alignment: Alignment.center,
                          children: [
                            _Fractals(
                              values: heightValues,
                              width: lastWidth,
                              height: lastHeight,
                              pixelRatio: pixelRatio,
                              threshold: threshold,
                            ),
                            if (screenState == ScreenStates.loading)
                              const Positioned(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 6)),
                            Positioned(
                                left: 15,
                                top: 15,
                                child: _FpsCounter(
                                    frameCount,
                                    sw.elapsedMilliseconds,
                                    screenState == ScreenStates.animating)),
                            Positioned(
                                right: 15,
                                top: 15,
                                child: Text(
                                    '${(lastWidth * pixelRatio).toInt()} x '
                                    '${(lastHeight * pixelRatio).toInt()} · '
                                    '${position.toStringAsFixed(2)}')),
                            Positioned(
                                bottom: 15,
                                child: _BottomPanel(
                                  screenState: screenState,
                                  error: error,
                                  onOneFrame: () => _onOneFrame(constraints),
                                  onPlay: () => _onPlay(constraints),
                                  onPlayLongTap: () {
                                    // reset posotion and start over
                                    position = 0;
                                    _onPlay(constraints);
                                  },
                                  onPause: () {
                                    cancelationToken.call();
                                    _setScreenState(ScreenStates.ready);
                                  },
                                ))
                          ]),
                    ))));
  }

  void _setScreenState(ScreenStates state) {
    setState(() {
      screenState = state;
    });
  }

  /// Set lastWidth, lastHeight, reset stopwatch and frame counter
  void _prepBeforeGrpcCall(BoxConstraints constraints, ScreenStates state) {
    lastWidth = constraints.maxWidth;
    lastHeight = constraints.maxHeight;
    sw.reset();
    frameCount = 0;
    setState(() {
      screenState = state;
    });
  }

  /// Return the width and height in pixels based on device pixel ratio
  (int, int) _getPixelWH() {
    var pWidth = (lastWidth * pixelRatio).toInt();
    var pHeight = (lastHeight * pixelRatio).toInt();
    return (pWidth, pHeight);
  }

  void _onOneFrame(BoxConstraints constraints) {
    _prepBeforeGrpcCall(constraints, ScreenStates.loading);
    var (pWidth, pHeight) = _getPixelWH();
    service
        .getSetAsHeightMap(
            widthPixels: pWidth,
            heightPixels: pHeight,
            iterationThreshold: threshold,
            startPosition: position)
        .then((value) => setState(() {
              heightValues = value.heightMap;
              if (value.heightMap.length != pWidth * pHeight) {
                _onGrpcCallError('Invalid length of height map', context);
              }
              position += 0.02;
              _setScreenState(ScreenStates.ready);
            }))
        .onError(
            (error, stackTrace) => _onGrpcCallError(error.toString(), context));
  }

  void _onPlay(BoxConstraints constraints) {
    _prepBeforeGrpcCall(constraints, ScreenStates.animating);
    var (pWidth, pHeight) = _getPixelWH();

    var (juliaStream, cn) = service.streamSetAsHeightMap(
        widthPixels: pWidth,
        heightPixels: pHeight,
        iterationThreshold: threshold,
        startPosition: position,
        fetchMode: fetchMode);

    cancelationToken = cn;

    juliaStream.listen(
        (value) {
          heightValues = value.heightMap;
          if (value.heightMap.length != pWidth * pHeight) {
            _onGrpcCallError('Invalid length of height map', context);
          }
          position = value.position;
          frameCount++;
          previousFrameReceivedMicro = lastFrameReceivedMicro;
          lastFrameReceivedMicro = sw.elapsedMicroseconds;
          _setScreenState(ScreenStates.animating);
        },
        cancelOnError: true,
        onError: (error, stackTrace) {
          if (error is GrpcError && error.code == 1) {
            return; // grpc call canceled
          }
          _onGrpcCallError(error.toString(), context);
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

// Doesn't account for rendering a frame side
// Shouldn't be a problm since rendering/rastering is happening in parallel thread and fast
class _FpsCounter extends StatefulWidget {
  const _FpsCounter(
      this.totalFrameCount, this.totalElapsedMs, this.showCurrent);

  final int totalFrameCount;
  final int totalElapsedMs;
  final bool showCurrent;

  @override
  State<_FpsCounter> createState() => _FpsCounterState();
}

class _FpsCounterState extends State<_FpsCounter> {
  // Use avg on the last few fps to have some intertia
  final List<double> _fpsCounts = List<double>.filled(3, 1.0);
  int _curr = 0;
  int _prevElapsedMs = 0;

  @override
  Widget build(BuildContext context) {
    double fps = 1000 / (widget.totalElapsedMs - _prevElapsedMs);

    _prevElapsedMs = widget.totalElapsedMs;

    _fpsCounts[_curr] = fps;
    _curr++;
    if (_curr >= _fpsCounts.length) {
      _curr = 0;
    }

    return Text(
        '${widget.totalFrameCount == 0 ? '' : 'AVG ${(widget.totalFrameCount / widget.totalElapsedMs * 1000).toStringAsFixed(1)}'}${widget.showCurrent ? ' NOW ${(_fpsCounts.reduce((a, b) => a + b) / _fpsCounts.length).toStringAsFixed(1)}' : ''}',
        style: const TextStyle(fontFamily: 'Fraps', fontSize: 20));
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel(
      {required this.screenState,
      this.error = '',
      required this.onOneFrame,
      required this.onPlay,
      required this.onPlayLongTap,
      required this.onPause});

  final ScreenStates screenState;
  final String error;
  final Function onOneFrame;
  final Function onPlay;
  final Function onPlayLongTap;
  final Function onPause;

  @override
  Widget build(BuildContext context) {
    return Material(
        elevation: 10,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: Container(
          width: 200,
          height: 54,
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
                            message: 'Error: $error',
                            child: const Icon(
                              Icons.circle,
                              color: Colors.red,
                            ))
                        : Tooltip(
                            richMessage: _getStatusText(),
                            child: MouseRegion(
                              cursor: MaterialStateMouseCursor.clickable,
                              child: GestureDetector(
                                child: const Icon(
                                  Icons.circle,
                                  color: Colors.green,
                                ),
                                onTap: () {
                                  showPopover(
                                    context: context,
                                    radius: 0,
                                    backgroundColor: Colors.transparent,
                                    barrierColor: Colors.white.withAlpha(150),
                                    shadow: [
                                      const BoxShadow(
                                          color: Colors.transparent,
                                          offset: Offset(0, 0),
                                          blurRadius: 0)
                                    ],
                                    //contentDyOffset: -60,
                                    transition: PopoverTransition.other,
                                    transitionDuration:
                                        const Duration(milliseconds: 100),
                                    bodyBuilder: (context) => _PanelPopup(
                                        statusText: _getStatusText()),
                                    direction: PopoverDirection.bottom,
                                    width: 380,
                                    height: 225,
                                  );
                                },
                              ),
                            ),
                          )),
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
                        : GestureDetector(
                            onLongPress: () => onPlayLongTap(),
                            child: const Icon(Icons.play_arrow_rounded)))
              ]),
        ));
  }

  TextSpan _getStatusText() {
    return TextSpan(
      children: [
        const TextSpan(
          text: 'Connected to ',
        ),
        TextSpan(
          text: '$defaultHost:$defaultPort',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(
          text:
              ', ${localPyStartSkipped ? 'skipped launching bundled server' : 'launched bundled server'}',
        ),
      ],
    );
  }
}

class _PanelPopup extends StatefulWidget {
  const _PanelPopup({required this.statusText});

  final TextSpan statusText;

  @override
  State<_PanelPopup> createState() => _PanelPopupState();
}

class _PanelPopupState extends State<_PanelPopup> {
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(18),
        child: Material(
            elevation: 10,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text.rich(widget.statusText),
                  Column(
                    children: [
                      SizedBox(
                          height: 36,
                          child: RadioListTile<service.FetchModes>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Use "repeated int32" stream',
                                textScaleFactor: 1.1),
                            value: service.FetchModes.grpcRepeatedInt32,
                            groupValue: fetchMode,
                            onChanged: (value) {
                              setState(() {
                                fetchMode = value as service.FetchModes;
                              });
                            },
                          )),
                      SizedBox(
                          height: 36,
                          child: RadioListTile<service.FetchModes>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Use "bytes" stream',
                                textScaleFactor: 1.1),
                            value: service.FetchModes.grpcBytes,
                            groupValue: fetchMode,
                            onChanged: (value) {
                              setState(() {
                                fetchMode = value as service.FetchModes;
                              });
                            },
                          )),
                      SizedBox(
                        height: 36,
                        child: RadioListTile<service.FetchModes>(
                          dense: true,
                          title: const Text(
                            'Use Dart native implementation',
                            textScaleFactor: 1.1,
                          ),
                          contentPadding: EdgeInsets.zero,
                          value: service.FetchModes.dartUiThread,
                          groupValue: fetchMode,
                          onChanged: (value) {
                            setState(() {
                              fetchMode = value as service.FetchModes;
                            });
                          },
                        ),
                      ),
                    ],
                  )
                ]))));
  }
}

class _Fractals extends StatefulWidget {
  const _Fractals(
      {required this.values,
      required this.width,
      required this.height,
      required this.pixelRatio,
      required this.threshold});

  final List<int> values;
  final double width;
  final double height;
  final double pixelRatio;
  final int threshold;

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
        getImage(pWidth, pHeight, widget.values, threshold - 1).then((value) {
          if (image != null) {
            image!.dispose();
            image = null;
          }
          setState(() => image = value);
        });
      }
    }
  }

  Future<ui.Image> getImage(
      int width, int height, List<int> values, int maxVal) async {
    final pixelData = Uint32List(values.length);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        var pos = y * width + x;
        var iter = (values[pos] + 1) * 255 ~/ maxVal;
        //pixelData[pos] = 0xFF000000 + iter + iter << 8 + iter << 16;
        var diff = 0xFF - iter;
        diff = diff | diff << 8 | diff << 16;
        pixelData[pos] = 0xFF000000 | diff | 0xFF;
        // pixelData[pos] = 0xFF000000 +
        //     255 * (1 + cos(3.32 * log(iter))) ~/ 2 +
        //     (255 * 256 * (1 + cos(0.774 * log(iter))) ~/ 2) +
        //     (255 * 256 * 256 * (1 + cos(0.412 * log(iter))) ~/ 2);
      }
    }

    var buffer =
        await ui.ImmutableBuffer.fromUint8List(pixelData.buffer.asUint8List());
    var codec = await ui.ImageDescriptor.raw(buffer,
            width: width, height: height, pixelFormat: ui.PixelFormat.rgba8888)
        .instantiateCodec(targetWidth: width, targetHeight: height);
    var frame = await codec.getNextFrame();

    buffer.dispose();

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
