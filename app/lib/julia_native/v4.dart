// v4, improved v1 (no Complex, no sqrt), Uint8List

import 'dart:math';
import 'dart:typed_data';
import '../grpc_generated/set_generator.pb.dart';

double _position = 0;
bool _canceled = false;

void cancelSetGeneration() {
  _canceled = true;
}

Stream<HeightMapBytesResponse> getSetAsHeightMapAsBytesStream(
    int widthPoints, int heightPoints, int threshold, double position) async* {
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

    var result = HeightMapBytesResponse(
        heightMap:
            _getSetAsHeightMap(widthPoints, heightPoints, threshold, _position),
        position: _position);
    yield result;

    // Hack to release the UI thread, 1ms seem insignificant delay.
    // E.g. if you have 60fps, adding 1 ms will make it 56 fps)
    // When testing on MBP never saw value above 40 FPS
    //await Future.delayed(const Duration(milliseconds: 1));

    // This variant makes UI very unresponsive
    await Future(() => null);
  }
}

Uint8List _getSetAsHeightMap(
    int widthPoints, int heightPoints, int threshold, double position) {
  Uint8List result = Uint8List(widthPoints * heightPoints);
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

// no difference
//@pragma('vm:prefer-inline')
int _checkInJuliaSet(
    double zx, double zy, double constX, double constY, int threshold) {
  // _Complex z = _Complex(zx, zy);
  // _Complex c = _Complex(constX, constY);
  var zx0 = zx;
  var zy0 = zy;

  for (int i = 0; i < threshold; i++) {
    //z = z * z + c;

    // var zx00 = zx0 * zx0 - zy0 * zy0 + constX;
    // zy0 = zx0 * zy0 + zy0 * zx0 + constY;
    final zx0zy0 = zx0 * zy0;
    zx0 = zx0 * zx0 - zy0 * zy0 + constX;
    zy0 = zx0zy0 + zx0zy0 + constY;
    // if (z.abs() > 4.0) {
    //   return i;
    // }
    if ((zx0 * zx0 + zy0 * zy0) > 16) {
      return i;
    }
  }

  return threshold - 1;
}

// no difference
//@pragma('vm:prefer-inline')
List<double> _linspace(double start, double end, int num) {
  double step = (end - start) / (num - 1);
  return List<double>.generate(num, (i) => start + (step * i));
}

// class _Complex {
//   double real;
//   double imag;

//   _Complex(this.real, this.imag);

//   _Complex operator +(_Complex other) =>
//       _Complex(real + other.real, imag + other.imag);
//   _Complex operator *(_Complex other) => _Complex(
//       real * other.real - imag * other.imag,
//       real * other.imag + imag * other.real);

//   double abs() => sqrt(real * real + imag * imag);
// }
