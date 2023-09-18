//
//  Generated code. Do not modify.
//  source: set_generator.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'set_generator.pb.dart' as $0;

export 'set_generator.pb.dart';

@$pb.GrpcServiceName('JuliaSetGeneratorService')
class JuliaSetGeneratorServiceClient extends $grpc.Client {
  static final _$getSetAsHeightMap = $grpc.ClientMethod<$0.HeightMapRequest, $0.HeightMapResponse>(
      '/JuliaSetGeneratorService/GetSetAsHeightMap',
      ($0.HeightMapRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.HeightMapResponse.fromBuffer(value));
  static final _$getSetAsHeightMapStream = $grpc.ClientMethod<$0.HeightMapRequest, $0.HeightMapResponse>(
      '/JuliaSetGeneratorService/GetSetAsHeightMapStream',
      ($0.HeightMapRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.HeightMapResponse.fromBuffer(value));

  JuliaSetGeneratorServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.HeightMapResponse> getSetAsHeightMap($0.HeightMapRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getSetAsHeightMap, request, options: options);
  }

  $grpc.ResponseStream<$0.HeightMapResponse> getSetAsHeightMapStream($0.HeightMapRequest request, {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$getSetAsHeightMapStream, $async.Stream.fromIterable([request]), options: options);
  }
}

@$pb.GrpcServiceName('JuliaSetGeneratorService')
abstract class JuliaSetGeneratorServiceBase extends $grpc.Service {
  $core.String get $name => 'JuliaSetGeneratorService';

  JuliaSetGeneratorServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.HeightMapRequest, $0.HeightMapResponse>(
        'GetSetAsHeightMap',
        getSetAsHeightMap_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.HeightMapRequest.fromBuffer(value),
        ($0.HeightMapResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.HeightMapRequest, $0.HeightMapResponse>(
        'GetSetAsHeightMapStream',
        getSetAsHeightMapStream_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.HeightMapRequest.fromBuffer(value),
        ($0.HeightMapResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.HeightMapResponse> getSetAsHeightMap_Pre($grpc.ServiceCall call, $async.Future<$0.HeightMapRequest> request) async {
    return getSetAsHeightMap(call, await request);
  }

  $async.Stream<$0.HeightMapResponse> getSetAsHeightMapStream_Pre($grpc.ServiceCall call, $async.Future<$0.HeightMapRequest> request) async* {
    yield* getSetAsHeightMapStream(call, await request);
  }

  $async.Future<$0.HeightMapResponse> getSetAsHeightMap($grpc.ServiceCall call, $0.HeightMapRequest request);
  $async.Stream<$0.HeightMapResponse> getSetAsHeightMapStream($grpc.ServiceCall call, $0.HeightMapRequest request);
}
