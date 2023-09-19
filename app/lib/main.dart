import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:app/grpc_generated/client.dart';
import 'package:app/grpc_generated/init_py.dart';
import 'package:app/grpc_generated/init_py_native.dart';
import 'package:grpc/grpc.dart';
import 'package:popover/popover.dart';
import 'dart:ui' as ui;

import 'grpc_generated/set_generator.pbgrpc.dart';

// Config the looks of Julia set
const threshold = 100; // Must not be larger than 255
const initialPosition = 0.5; // any number, full period is 1.0

// Global state, better keep it somewhere else rather than in global vars
int lastFrameReceivedMicro = 10000;
int previousFrameReceivedMicro = 0;
Stopwatch sw = Stopwatch()..start();
bool useByteStreaming =
    false; // choose which streaming method to use, byte vs int32

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
  ResponseStream? grpcStream;
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
                            if (screenState == ScreenStates.animating)
                              Positioned(
                                  left: 15,
                                  top: 15,
                                  child: _FpsCounter(lastFrameReceivedMicro -
                                      previousFrameReceivedMicro)),
                            Positioned(
                                top: 15,
                                child: Text(
                                    '${(lastWidth * pixelRatio).toInt()} x ${(lastHeight * pixelRatio).toInt()} · ${position.toStringAsFixed(2)}')),
                            Positioned(
                                bottom: 15,
                                child: _BottomPanel(
                                  screenState: screenState,
                                  error: error,
                                  onOneFrame: () => _onOneFrame(constraints),
                                  onPlay: () => _onPlay(constraints),
                                  onPause: () {
                                    grpcStream?.cancel();
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

  void _prepBeforeGrpcCall(BoxConstraints constraints, ScreenStates state) {
    lastWidth = constraints.maxWidth;
    lastHeight = constraints.maxHeight;
    setState(() {
      screenState = state;
    });
  }

  void _onOneFrame(BoxConstraints constraints) {
    _prepBeforeGrpcCall(constraints, ScreenStates.loading);
    var pWidth = (lastWidth * pixelRatio).toInt();
    var pHeight = (lastHeight * pixelRatio).toInt();
    JuliaSetGeneratorServiceClient(getClientChannel())
        .getSetAsHeightMap(HeightMapRequest(
            width: pWidth,
            height: pHeight,
            threshold: threshold,
            position: position))
        .then((value) => setState(() {
              heightValues = value.heightMap;
              if (value.heightMap.length != pWidth * pHeight) {
                _onGrpcCallError('Invalid length of height map', context);
              }
              position += 0.05;
              _setScreenState(ScreenStates.ready);
            }))
        .onError(
            (error, stackTrace) => _onGrpcCallError(error.toString(), context));
  }

  void _onPlay(BoxConstraints constraints) {
    _prepBeforeGrpcCall(constraints, ScreenStates.animating);
    var pWidth = (lastWidth * pixelRatio).toInt();
    var pHeight = (lastHeight * pixelRatio).toInt();

    grpcStream = useByteStreaming
        ? JuliaSetGeneratorServiceClient(getClientChannel())
            .getSetAsHeightMapAsBytesStream(HeightMapRequest(
                width: (lastWidth * pixelRatio).toInt(),
                height: (lastHeight * pixelRatio).toInt(),
                threshold: threshold,
                position: position))
        : JuliaSetGeneratorServiceClient(getClientChannel())
            .getSetAsHeightMapStream(HeightMapRequest(
                width: (lastWidth * pixelRatio).toInt(),
                height: (lastHeight * pixelRatio).toInt(),
                threshold: threshold,
                position: position));

    grpcStream!.listen(
        (value) {
          heightValues = value.heightMap;
          if (value.heightMap.length != pWidth * pHeight) {
            _onGrpcCallError('Invalid length of height map', context);
          }
          position = value.position;
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

// Doesn't account for rendering on the client side, might be added
// via WidgetsBinding.instance.addPostFrameCallback, though when
// testing on Desktop this part seems to be ~5% of total time, can be ignored
class _FpsCounter extends StatefulWidget {
  const _FpsCounter(this.timeBetweenFramesMicro);

  final int timeBetweenFramesMicro;

  @override
  State<_FpsCounter> createState() => _FpsCounterState();
}

class _FpsCounterState extends State<_FpsCounter> {
  // Use avg on the last few fps to have some intertia
  final List<double> _fpsCounts = List<double>.filled(7, 10.0);
  int _curr = 0;

  @override
  Widget build(BuildContext context) {
    double fps = 1000000 / widget.timeBetweenFramesMicro;

    _fpsCounts[_curr] = fps;
    _curr++;
    if (_curr >= _fpsCounts.length) {
      _curr = 0;
    }

    return Text(
        (_fpsCounts.reduce((a, b) => a + b) / _fpsCounts.length)
            .toStringAsFixed(1),
        style: const TextStyle(fontFamily: 'Fraps', fontSize: 24));
  }
}

// // FPS reportted by Flutter diagnostics, showed high FPS (hundreds of FPS),
// // Apparently local rendering is quick, no point using it
// class _FpsCounterFlutter extends StatefulWidget {
//   const _FpsCounterFlutter();

//   @override
//   State<_FpsCounterFlutter> createState() => _FpsCounterFlutterState();
// }

// class _FpsCounterFlutterState extends State<_FpsCounterFlutter> {
//   final List<double> _fpsCounts = List<double>.filled(10, 0.0);
//   int _curr = 0;

//   @override
//   void initState() {
//     super.initState();

//     WidgetsBinding.instance.addTimingsCallback((timings) {
//       double fps = 1000000 / timings.last.totalSpan.inMicroseconds;
//       if (mounted) {
//         setState(() {
//           _fpsCounts[_curr] = fps;
//           _curr++;
//           if (_curr >= _fpsCounts.length) {
//             _curr = 0;
//           }
//         });
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     double averageFps = _fpsCounts.isNotEmpty
//         ? _fpsCounts.reduce((a, b) => a + b) / _fpsCounts.length
//         : 0;

//     return Text(averageFps.toStringAsFixed(1));
//   }
// }

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
                            message: 'Error: $error}',
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
                                    // onPop: () => print('Popover was popped!'),
                                    direction: PopoverDirection.bottom,
                                    width: 380,
                                    height: 160,
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
                        : const Icon(Icons.play_arrow_rounded))
              ]),
        ));
  }

  TextSpan _getStatusText() {
    return TextSpan(
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
        padding: const EdgeInsets.all(20),
        child: Material(
            elevation: 10,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text.rich(widget.statusText),
                  const SizedBox(
                    height: 16,
                  ),
                  Row(
                    children: [
                      Checkbox(
                          value: useByteStreaming,
                          onChanged: (value) {
                            setState(() {
                              useByteStreaming = value ?? false;
                            });
                          }),
                      const Text('Use byte stream instead of int32')
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
        await ImmutableBuffer.fromUint8List(pixelData.buffer.asUint8List());
    var codec = await ImageDescriptor.raw(buffer,
            width: width, height: height, pixelFormat: PixelFormat.rgba8888)
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
