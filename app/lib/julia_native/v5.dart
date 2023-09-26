// v5, v3 with improved v4 calcullations
import 'dart:math';
import 'dart:typed_data';
import 'package:isolate_pool_2/isolate_pool_2.dart';
import '../grpc_generated/set_generator.pb.dart';
import 'common.dart';

double _position = 0;
bool _canceled = false;

void cancelSetGeneration() {
  _canceled = true;
  try {
    _pool.stop();
  } catch (_) {}
}

late IsolatePool _pool;

Stream<HeightMapBytesResponse> getSetAsHeightMapAsBytesStream(
    int widthPoints, int heightPoints, int threshold, double position) async* {
  _pool = IsolatePool(numberOfIsolates);
  await _pool.start();
  _position = position;
  _canceled = false;
  while (!_canceled) {
    var fractionPart = _position % 1;
    if (fractionPart > 0.65 && fractionPart < 0.75) {
      _position += 0.001;
    } else if (fractionPart > 0.45 && fractionPart < 0.65) {
      _position += 0.05;
    } else {
      _position += 0.01;
    }

    List<int> list = await _getSetAsHeightMapParallel(
        widthPoints, heightPoints, _pool, threshold);
    yield HeightMapBytesResponse(heightMap: list, position: _position);

    // Hack to release the UI thread, 1ms seem insignificant delay.
    // E.g. if you have 60fps, adding 1 ms will make it 56 fps)
    // When testing on MBP never saw value above 40 FPS
    //await Future.delayed(const Duration(milliseconds: 1));

    // This variant makes UI very unresponsive
    await Future(() => null);
  }
}

// The following code changes the parallel implementation to iterate over N blocks (where N is the number of isolates), rather than individual rows.

Future<Uint8List> _getSetAsHeightMapParallel(
    int widthPoints, int heightPoints, IsolatePool pool, int threshold) async {
  var list = Uint8List(widthPoints * heightPoints);

  double width = 4, height = 4 * heightPoints / widthPoints;
  double xStart = -width / 2, yStart = -height / 2;
  List<double> im = _linspace(yStart, yStart + height, heightPoints);

  int blockSize = (heightPoints / pool.numberOfIsolates).ceil();

  List<Future> futures = [];

  for (var i = 0; i < heightPoints; i += blockSize) {
    futures.add(pool
        .scheduleJob<Uint8List>(GetBlockJob(
            widthPoints: widthPoints,
            heightPoints: heightPoints,
            width: width,
            height: height,
            xStart: xStart,
            yStart: yStart,
            im: im.sublist(i, min(i + blockSize, heightPoints)),
            threshold: threshold,
            position: _position))
        .then((v) {
      list.setAll(i * widthPoints, v);
    }));
  }

  await Future.wait(futures);
  return list;
}

class GetBlockJob extends PooledJob<Uint8List> {
  GetBlockJob(
      {required this.widthPoints,
      required this.heightPoints,
      required this.width,
      required this.height,
      required this.xStart,
      required this.yStart,
      required this.im,
      required this.threshold,
      required this.position});

  final int widthPoints;
  final int heightPoints;
  final double width;
  final double height;
  final double xStart;
  final double yStart;
  final List<double> im;
  final int threshold;
  final double position;

  @override
  Future<Uint8List> job() async {
    Uint8List result = Uint8List(widthPoints * im.length);

    List<double> re = _linspace(xStart, xStart + width, widthPoints);

    double r = 0.7;
    double a = 2 * pi * position;
    double cx = r * cos(a), cy = r * sin(a);

    for (int i = 0; i < im.length; i++) {
      for (int j = 0; j < widthPoints; j++) {
        result[i * widthPoints + j] =
            _checkInJuliaSet(re[j], im[i], cx, cy, threshold);
      }
    }

    return result;
  }
}

int _checkInJuliaSet(
    double zx, double zy, double constX, double constY, int threshold) {
  var zx0 = zx;
  var zy0 = zy;

  for (int i = 0; i < threshold; i++) {
    final zx0zy0 = zx0 * zy0;
    zx0 = zx0 * zx0 - zy0 * zy0 + constX;
    zy0 = zx0zy0 + zx0zy0 + constY;
    if ((zx0 * zx0 + zy0 * zy0) > 16) {
      return i;
    }
  }

  return threshold - 1;
}

List<double> _linspace(double start, double end, int num) {
  double step = (end - start) / (num - 1);
  return List<double>.generate(num, (i) => start + (step * i));
}
