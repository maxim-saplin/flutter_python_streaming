import 'package:grpc/grpc.dart';

import 'grpc_generated/client.dart';
import 'grpc_generated/set_generator.pbgrpc.dart';
import 'julia.dart';

enum FetchModes { grpcRepeatedInt32, grpcBytes, dartUiThread }

typedef CancelationToken = Function();

Future<HeightMapResponse> getSetAsHeightMap(
    {required int widthPixels,
    required int heightPixels,
    required int iterationThreshold,
    required double startPosition}) {
  assert(widthPixels > 0, 'Width must be positive');
  assert(heightPixels > 0, 'Height must be positive');
  assert(iterationThreshold >= 1 && iterationThreshold <= 255,
      'Threshold must be between 1 and 255');
  return JuliaSetGeneratorServiceClient(getClientChannel()).getSetAsHeightMap(
      HeightMapRequest(
          width: widthPixels,
          height: heightPixels,
          threshold: iterationThreshold,
          position: startPosition));
}

(Stream, CancelationToken) streamSetAsHeightMap(
    {required int widthPixels,
    required int heightPixels,
    required int iterationThreshold,
    required double startPosition,
    required FetchModes fetchMode}) {
  Stream stream;
  CancelationToken cancelationToken;

  switch (fetchMode) {
    case FetchModes.grpcRepeatedInt32:
      stream = JuliaSetGeneratorServiceClient(getClientChannel())
          .getSetAsHeightMapStream(HeightMapRequest(
              width: widthPixels,
              height: heightPixels,
              threshold: iterationThreshold,
              position: startPosition));
      cancelationToken = () => (stream as ResponseStream).cancel();
      break;
    case FetchModes.grpcBytes:
      stream = JuliaSetGeneratorServiceClient(getClientChannel())
          .getSetAsHeightMapAsBytesStream(HeightMapRequest(
              width: widthPixels,
              height: heightPixels,
              threshold: iterationThreshold,
              position: startPosition));
      cancelationToken = () => (stream as ResponseStream).cancel();
      break;
    case FetchModes.dartUiThread:
      stream = getSetAsHeightMapAsBytesStream(
          widthPixels, heightPixels, iterationThreshold, startPosition);
      cancelationToken = () => cancelSetGeneration();
      break;
  }

  return (stream, cancelationToken);
}
