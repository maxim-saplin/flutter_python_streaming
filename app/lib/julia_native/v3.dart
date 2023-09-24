// v3, v2 with Uint8List

import 'dart:math';
import 'package:isolate_pool_2/isolate_pool_2.dart';
import '../grpc_generated/set_generator.pb.dart';

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
  _pool = IsolatePool(8);
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
    if (_pool.numberOfIsolates > heightPoints) {
      var result = HeightMapBytesResponse(
          heightMap: _getSetAsHeightMap(
              widthPoints, heightPoints, threshold, _position),
          position: _position);
      yield result;
    } else {
      List<int> list = await _getSetAsHeightMapParallel(
          widthPoints, heightPoints, _pool, threshold);
      yield HeightMapBytesResponse(heightMap: list, position: _position);
    }

    // Hack to release the UI thread, 1ms seem insignificant delay.
    // E.g. if you have 60fps, adding 1 ms will make it 56 fps)
    // When testing on MBP never saw value above 40 FPS
    //await Future.delayed(const Duration(milliseconds: 1));

    // This variant makes UI very unresponsive
    await Future(() => null);
  }
}

// The following code changes the parallel implementation to iterate over N blocks (where N is the number of isolates), rather than individual rows.

Future<List<int>> _getSetAsHeightMapParallel(
    int widthPoints, int heightPoints, IsolatePool pool, int threshold) async {
  var list = List.filled(widthPoints * heightPoints, 0);

  double width = 4, height = 4 * heightPoints / widthPoints;
  double xStart = -width / 2, yStart = -height / 2;
  List<double> im = _linspace(yStart, yStart + height, heightPoints);

  int blockSize = (heightPoints / pool.numberOfIsolates).ceil();

  List<Future> futures = [];

  for (var i = 0; i < heightPoints; i += blockSize) {
    futures.add(pool
        .scheduleJob<List<int>>(GetBlockJob(
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

class GetBlockJob extends PooledJob<List<int>> {
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
  Future<List<int>> job() async {
    List<int> result = List<int>.filled(widthPoints * im.length, 0);

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

List<int> _getSetAsHeightMap(
    int widthPoints, int heightPoints, int threshold, double position) {
  List<int> result = List<int>.filled(widthPoints * heightPoints, 0);
  double width = 4, height = 4 * heightPoints / widthPoints;
  double xStart = -width / 2, yStart = -height / 2;

  List<double> re = _linspace(xStart, xStart + width, widthPoints);
  List<double> im = _linspace(yStart, yStart + height, heightPoints);

  double r = 0.7;
  double a = 2 * pi * position;
  double cx = r * cos(a), cy = r * sin(a);

  for (int i = 0; i < heightPoints; i++) {
    for (int j = 0; j < widthPoints; j++) {
      result[i * widthPoints + j] =
          _checkInJuliaSet(re[j], im[i], cx, cy, threshold);
    }
  }

  return result;
}

int _checkInJuliaSet(
    double zx, double zy, double constX, double constY, int threshold) {
  _Complex z = _Complex(zx, zy);
  _Complex c = _Complex(constX, constY);

  for (int i = 0; i < threshold; i++) {
    z = z * z + c;
    if (z.abs() > 4.0) {
      return i;
    }
  }

  return threshold - 1;
}

List<double> _linspace(double start, double end, int num) {
  double step = (end - start) / (num - 1);
  return List<double>.generate(num, (i) => start + (step * i));
}

class _Complex {
  double real;
  double imag;

  _Complex(this.real, this.imag);

  _Complex operator +(_Complex other) =>
      _Complex(real + other.real, imag + other.imag);
  _Complex operator *(_Complex other) => _Complex(
      real * other.real - imag * other.imag,
      real * other.imag + imag * other.real);

  double abs() => sqrt(real * real + imag * imag);
}



// Future<List<int>> _getSetAsHeightMapParallel(int widthPoints, int heightPoints, IsolatePool pool, int threshold) async {
//   var list = List.filled(widthPoints * heightPoints, 0);
//   late Future complete;
  
//   double width = 4, height = 4 * heightPoints / widthPoints;
//   double xStart = -width / 2, yStart = -height / 2;
//   List<double> im = _linspace(yStart, yStart + height, heightPoints);
  
//   for (var i = 0; i < heightPoints; i++) {
//     complete = pool
//         .scheduleJob<List<int>>(GetLineJob(
//             widthPoints: widthPoints,
//             heightPoints: heightPoints,
//             width: width,
//             height: height,
//             xStart: xStart,
//             yStart: yStart,
//             im: im[i],
//             threshold: threshold,
//             position: _position))
//         .then((v) {
//       list.setAll(i * widthPoints, v);
//     });
//   }
  
//   await complete;
//   return list;
// }

// class GetLineJob extends PooledJob<List<int>> {
//   GetLineJob(
//       {required this.widthPoints,
//       required this.heightPoints,
//       required this.width,
//       required this.height,
//       required this.xStart,
//       required this.yStart,
//       required this.im,
//       required this.threshold,
//       required this.position});

//   final int widthPoints;
//   final int heightPoints;
//   final double width;
//   final double height;
//   final double xStart;
//   final double yStart;
//   final double im;
//   final int threshold;
//   final double position;

//   @override
//   Future<List<int>> job() async {
//     List<int> result = List<int>.filled(widthPoints, 0);

//     List<double> re = _linspace(xStart, xStart + width, widthPoints);

//     double r = 0.7;
//     double a = 2 * pi * position;
//     double cx = r * cos(a), cy = r * sin(a);

//     for (int j = 0; j < widthPoints; j++) {
//       result[j] = _checkInJuliaSet(re[j], im, cx, cy, threshold);
//     }

//     return result;
//   }
// }