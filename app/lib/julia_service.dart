import 'package:grpc/grpc.dart';

import 'grpc_generated/client.dart';
import 'grpc_generated/set_generator.pbgrpc.dart';
import 'julia_native/v1.dart' as v1;
import 'julia_native/v2.dart' as v2;
import 'julia_native/v3.dart' as v3;
import 'julia_native/v4.dart' as v4;
import 'julia_native/v5.dart' as v5;
import 'julia_native/v6.dart' as v6;
import 'julia_native/v7.dart' as v7;

enum FetchModes {
  grpcRepeatedInt32,
  grpcBytes,
  dartUiThreadV1,
  dartIsolatesV2,
  dartIsolatesV3,
  dartUiThreadV4,
  dartIsolatesV5,
  dartIsolatesV6,
  dartIsolatesV7,
}

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
    case FetchModes.dartUiThreadV1:
      stream = v1.getSetAsHeightMapAsBytesStream(
          widthPixels, heightPixels, iterationThreshold, startPosition);
      cancelationToken = () => v1.cancelSetGeneration();
      break;
    case FetchModes.dartIsolatesV2:
      stream = v2.getSetAsHeightMapAsBytesStream(
          widthPixels, heightPixels, iterationThreshold, startPosition);
      cancelationToken = () => v2.cancelSetGeneration();
      break;
    case FetchModes.dartIsolatesV3:
      stream = v3.getSetAsHeightMapAsBytesStream(
          widthPixels, heightPixels, iterationThreshold, startPosition);
      cancelationToken = () => v3.cancelSetGeneration();
      break;
    case FetchModes.dartUiThreadV4:
      stream = v4.getSetAsHeightMapAsBytesStream(
          widthPixels, heightPixels, iterationThreshold, startPosition);
      cancelationToken = () => v4.cancelSetGeneration();
      break;
    case FetchModes.dartIsolatesV5:
      stream = v5.getSetAsHeightMapAsBytesStream(
          widthPixels, heightPixels, iterationThreshold, startPosition);
      cancelationToken = () => v5.cancelSetGeneration();
      break;
    case FetchModes.dartIsolatesV6:
      stream = v6.getSetAsHeightMapAsBytesStream(
          widthPixels, heightPixels, iterationThreshold, startPosition);
      cancelationToken = () => v6.cancelSetGeneration();
      break;
    case FetchModes.dartIsolatesV7:
      stream = v7.getSetAsHeightMapAsBytesStream(
          widthPixels, heightPixels, iterationThreshold, startPosition);
      cancelationToken = () => v7.cancelSetGeneration();
      break;
  }

  return (stream, cancelationToken);
}
