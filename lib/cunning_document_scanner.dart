import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ios_options.dart';

export 'ios_options.dart';

class CunningDocumentScanner {
  static const MethodChannel _channel =
      MethodChannel('cunning_document_scanner');

  /// Call this to start get Picture workflow.
  static Future<List<String>?> getPictures({
    int noOfPages = 100,
    bool isGalleryImportAllowed = false,
    IosScannerOptions? iosScannerOptions,
    String? filterType,
    bool? saveInGallery,
  }) async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
    ].request();
    if (statuses.containsValue(PermissionStatus.denied) ||
        statuses.containsValue(PermissionStatus.permanentlyDenied)) {
      throw Exception("Permission not granted");
    }

    // Prepare the iosScannerOptions map
    Map<String, dynamic>? iosOptionsMap;
    if (iosScannerOptions != null) {
      iosOptionsMap = {
        'imageFormat': iosScannerOptions.imageFormat.name,
        'jpgCompressionQuality': iosScannerOptions.jpgCompressionQuality,
        'filterType': iosScannerOptions.filterType,
        'saveInGallery': iosScannerOptions.saveInGallery,
      };
    }
    
    // Individual parameters take precedence
    if (filterType != null) {
      if (iosOptionsMap == null) {
        iosOptionsMap = {};
      }
      iosOptionsMap['filterType'] = filterType;
    }
    if (saveInGallery != null) {
      if (iosOptionsMap == null) {
        iosOptionsMap = {};
      }
      iosOptionsMap['saveInGallery'] = saveInGallery;
    }

    final List<dynamic>? pictures = await _channel.invokeMethod('getPictures', {
      'noOfPages': noOfPages,
      'isGalleryImportAllowed': isGalleryImportAllowed,
      if (iosOptionsMap != null) 'iosScannerOptions': iosOptionsMap,
    });
    return pictures?.map((e) => e as String).toList();
  }
}
