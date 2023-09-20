//
//  Generated code. Do not modify.
//  source: set_generator.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use heightMapRequestDescriptor instead')
const HeightMapRequest$json = {
  '1': 'HeightMapRequest',
  '2': [
    {'1': 'width', '3': 1, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 2, '4': 1, '5': 5, '10': 'height'},
    {'1': 'threshold', '3': 3, '4': 1, '5': 5, '10': 'threshold'},
    {'1': 'position', '3': 4, '4': 1, '5': 2, '10': 'position'},
  ],
};

/// Descriptor for `HeightMapRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heightMapRequestDescriptor = $convert.base64Decode(
    'ChBIZWlnaHRNYXBSZXF1ZXN0EhQKBXdpZHRoGAEgASgFUgV3aWR0aBIWCgZoZWlnaHQYAiABKA'
    'VSBmhlaWdodBIcCgl0aHJlc2hvbGQYAyABKAVSCXRocmVzaG9sZBIaCghwb3NpdGlvbhgEIAEo'
    'AlIIcG9zaXRpb24=');

@$core.Deprecated('Use heightMapResponseDescriptor instead')
const HeightMapResponse$json = {
  '1': 'HeightMapResponse',
  '2': [
    {'1': 'height_map', '3': 1, '4': 3, '5': 5, '10': 'heightMap'},
    {'1': 'position', '3': 2, '4': 1, '5': 2, '10': 'position'},
  ],
};

/// Descriptor for `HeightMapResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heightMapResponseDescriptor = $convert.base64Decode(
    'ChFIZWlnaHRNYXBSZXNwb25zZRIdCgpoZWlnaHRfbWFwGAEgAygFUgloZWlnaHRNYXASGgoIcG'
    '9zaXRpb24YAiABKAJSCHBvc2l0aW9u');

