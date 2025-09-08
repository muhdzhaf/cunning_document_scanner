/// Enumerates the different output image formats are supported.
enum IosImageFormat {
  /// Indicates the output image should be formatted as JPEG image.
  jpg,

  /// Indicates the output image should be formatted as PNG image.
  png,
}

/// Enumerates the different post-processing filters for iOS document scanning.
enum IosScanFilter {
  /// No additional filter (VisionKit's default behavior)
  none,
  
  /// Neutralize VisionKit's color processing (default)
  photo,
  
  /// Convert to grayscale
  grayscale,
  
  /// Convert to black and white
  blackAndWhite
}

/// Different options that modify the behavior of the document scanner on iOS.
///
/// The [imageFormat] specifies the format of the output image file. Available
/// options are [IosImageFormat.jpeg] or [IosImageFormat.png]. Default value is
/// [IosImageFormat.png].
///
/// If [imageFormat] is set to [IosImageFormat.jpeg] the [jpgCompressionQuality]
/// can be used to control the quality of the resulting JPEG image. The value
/// 0.0 represents the maximum compression (or lowest quality) while the value
/// 1.0 represents the least compression (or best quality). Default value is 1.0.
///
/// The [scanFilter] specifies the post-processing filter to apply after VisionKit
/// scanning. Default value is [IosScanFilter.photo].
///
/// The [autoShutterEnabled] controls whether the scanner should automatically
/// capture detected documents. Default value is false.
final class IosScannerOptions {
  /// Creates a [IosScannerOptions].
  const IosScannerOptions({
    this.imageFormat = IosImageFormat.png,
    this.jpgCompressionQuality = 1.0,
    this.scanFilter = IosScanFilter.photo,
    this.autoShutterEnabled = false,
  });

  final IosImageFormat imageFormat;
  final IosScanFilter scanFilter;
  final bool autoShutterEnabled;

  /// The quality of the resulting JPEG image, expressed as a value from 0.0 to
  /// 1.0.
  ///
  /// The value 0.0 represents the maximum compression (or lowest quality) while
  /// the value 1.0 represents the least compression (or best quality). The
  /// [jpgCompressionQuality] only has an effect if the [imageFormat] is set to
  /// [IosImageFormat.jpeg] and is ignored otherwise.
  final double jpgCompressionQuality;
}
