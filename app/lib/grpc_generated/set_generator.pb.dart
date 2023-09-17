//
//  Generated code. Do not modify.
//  source: set_generator.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Define the request message
class HeightMapRequest extends $pb.GeneratedMessage {
  factory HeightMapRequest({
    $core.int? width,
    $core.int? height,
  }) {
    final $result = create();
    if (width != null) {
      $result.width = width;
    }
    if (height != null) {
      $result.height = height;
    }
    return $result;
  }
  HeightMapRequest._() : super();
  factory HeightMapRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory HeightMapRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'HeightMapRequest', createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'width', $pb.PbFieldType.O3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'height', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  HeightMapRequest clone() => HeightMapRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  HeightMapRequest copyWith(void Function(HeightMapRequest) updates) => super.copyWith((message) => updates(message as HeightMapRequest)) as HeightMapRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HeightMapRequest create() => HeightMapRequest._();
  HeightMapRequest createEmptyInstance() => create();
  static $pb.PbList<HeightMapRequest> createRepeated() => $pb.PbList<HeightMapRequest>();
  @$core.pragma('dart2js:noInline')
  static HeightMapRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<HeightMapRequest>(create);
  static HeightMapRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get width => $_getIZ(0);
  @$pb.TagNumber(1)
  set width($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasWidth() => $_has(0);
  @$pb.TagNumber(1)
  void clearWidth() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get height => $_getIZ(1);
  @$pb.TagNumber(2)
  set height($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasHeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeight() => clearField(2);
}

/// Define the response message
class HeightMapResponse extends $pb.GeneratedMessage {
  factory HeightMapResponse({
    $core.Iterable<$core.double>? heightMap,
  }) {
    final $result = create();
    if (heightMap != null) {
      $result.heightMap.addAll(heightMap);
    }
    return $result;
  }
  HeightMapResponse._() : super();
  factory HeightMapResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory HeightMapResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'HeightMapResponse', createEmptyInstance: create)
    ..p<$core.double>(1, _omitFieldNames ? '' : 'heightMap', $pb.PbFieldType.KF)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  HeightMapResponse clone() => HeightMapResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  HeightMapResponse copyWith(void Function(HeightMapResponse) updates) => super.copyWith((message) => updates(message as HeightMapResponse)) as HeightMapResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HeightMapResponse create() => HeightMapResponse._();
  HeightMapResponse createEmptyInstance() => create();
  static $pb.PbList<HeightMapResponse> createRepeated() => $pb.PbList<HeightMapResponse>();
  @$core.pragma('dart2js:noInline')
  static HeightMapResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<HeightMapResponse>(create);
  static HeightMapResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.double> get heightMap => $_getList(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
