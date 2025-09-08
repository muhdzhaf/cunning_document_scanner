import Flutter
import UIKit
import Vision
import VisionKit

@available(iOS 13.0, *)
public class SwiftCunningDocumentScannerPlugin: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate {
  var resultChannel: FlutterResult?
  var presentingController: VNDocumentCameraViewController?
  var scannerOptions: CunningScannerOptions = CunningScannerOptions()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "cunning_document_scanner", binaryMessenger: registrar.messenger())
    let instance = SwiftCunningDocumentScannerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "getPictures" {
            scannerOptions = CunningScannerOptions.fromArguments(args: call.arguments)
            let presentedVC: UIViewController? = UIApplication.shared.keyWindow?.rootViewController
            self.resultChannel = result
            if VNDocumentCameraViewController.isSupported {
                self.presentingController = VNDocumentCameraViewController()
                self.presentingController!.delegate = self
                presentedVC?.present(self.presentingController!, animated: true)
            } else {
                result(FlutterError(code: "UNAVAILABLE", message: "Document camera is not available on this device", details: nil))
            }
        } else {
            result(FlutterMethodNotImplemented)
            return
        }
  }


    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }

    private func applyFilterToImage(_ image: UIImage, filter: CunningScannerFilter) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let context = CIContext()
        var outputImage: CIImage = ciImage
        
        switch filter {
        case .none:
            // No additional processing - keep VisionKit's default
            break
            
        case .photo:
            // Neutralize VisionKit's color processing - adjust contrast/saturation
            let colorControls = CIFilter(name: "CIColorControls")!
            colorControls.setValue(outputImage, forKey: kCIInputImageKey)
            colorControls.setValue(1.0, forKey: kCIInputContrastKey) // Normal contrast
            colorControls.setValue(0.0, forKey: kCIInputSaturationKey) // Desaturate to neutralize
            colorControls.setValue(0.0, forKey: kCIInputBrightnessKey)
            outputImage = colorControls.outputImage ?? outputImage
            
        case .grayscale:
            // Convert to grayscale
            let grayscale = CIFilter(name: "CIPhotoEffectMono")!
            grayscale.setValue(outputImage, forKey: kCIInputImageKey)
            outputImage = grayscale.outputImage ?? outputImage
            
        case .blackAndWhite:
            // Convert to black and white with high contrast
            let colorControls = CIFilter(name: "CIColorControls")!
            colorControls.setValue(outputImage, forKey: kCIInputImageKey)
            colorControls.setValue(2.0, forKey: kCIInputContrastKey) // High contrast
            colorControls.setValue(0.0, forKey: kCIInputSaturationKey) // Remove color
            
            if let controlledImage = colorControls.outputImage {
                outputImage = controlledImage
            }
        }
        
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        let tempDirPath = self.getDocumentsDirectory()
        let currentDateTime = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let formattedDate = df.string(from: currentDateTime)
        var filenames: [String] = []
        
        for i in 0 ..< scan.pageCount {
            var processedImage = scan.imageOfPage(at: i)
            
            // Apply post-processing filter
            if scannerOptions.scanFilter != .none {
                processedImage = applyFilterToImage(processedImage, filter: scannerOptions.scanFilter)
            }
            
            let url = tempDirPath.appendingPathComponent(formattedDate + "-\(i).\(scannerOptions.imageFormat.rawValue)")
            switch scannerOptions.imageFormat {
            case .jpg:
                try? processedImage.jpegData(compressionQuality: scannerOptions.jpgCompressionQuality)?.write(to: url)
            case .png:
                try? processedImage.pngData()?.write(to: url)
            }
            
            filenames.append(url.path)
        }
        resultChannel?(filenames)
        presentingController?.dismiss(animated: true)
    }

    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        resultChannel?(nil)
        presentingController?.dismiss(animated: true)
    }

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        resultChannel?(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
        presentingController?.dismiss(animated: true)
    }
}
