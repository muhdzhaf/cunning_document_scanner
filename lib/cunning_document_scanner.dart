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

    // Use iOS options if provided, otherwise use individual parameters
    final Map<String, dynamic> arguments = {
      'noOfPages': noOfPages,
      'isGalleryImportAllowed': isGalleryImportAllowed,
    };
    
    if (iosScannerOptions != null) {
      arguments['filterType'] = iosScannerOptions.filterType;
      arguments['saveInGallery'] = iosScannerOptions.saveInGallery;
      arguments['imageFormat'] = iosScannerOptions.imageFormat.name;
      arguments['jpgCompressionQuality'] = iosScannerOptions.jpgCompressionQuality;
    } else {
      arguments['filterType'] = filterType ?? 'color';
      arguments['saveInGallery'] = saveInGallery ?? false;
      arguments['imageFormat'] = 'png';
      arguments['jpgCompressionQuality'] = 1.0;
    }

    final List<dynamic>? pictures = await _channel.invokeMethod('getPictures', arguments);
    return pictures?.map((e) => e as String).toList();
  }
}
