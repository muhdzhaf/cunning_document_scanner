import Flutter
import UIKit
import Vision
import VisionKit
import CoreImage

@available(iOS 13.0, *)
public class SwiftCunningDocumentScannerPlugin: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate {
    var resultChannel: FlutterResult?
    var presentingController: VNDocumentCameraViewController?
    var scannerOptions: CunningScannerOptions = CunningScannerOptions()
    var filterType: String = "color"
    var saveInGallery: Bool = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "cunning_document_scanner", binaryMessenger: registrar.messenger())
        let instance = SwiftCunningDocumentScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getPictures" {
            // Parse all parameters including new ones
            let arguments = call.arguments as? [String: Any]
            scannerOptions = CunningScannerOptions.fromArguments(args: call.arguments)
            filterType = arguments?["filterType"] as? String ?? "color"
            saveInGallery = arguments?["saveInGallery"] as? Bool ?? false
            
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

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        DispatchQueue.global(qos: .userInitiated).async {
            let tempDirPath = self.getDocumentsDirectory()
            let currentDateTime = Date()
            let df = DateFormatter()
            df.dateFormat = "yyyyMMdd-HHmmss"
            let formattedDate = df.string(from: currentDateTime)
            var filenames: [String] = []
            
            for i in 0 ..< scan.pageCount {
                // Get VisionKit's processed image
                let visionKitImage = scan.imageOfPage(at: i)
                
                // Apply post-processing to neutralize VisionKit's auto-enhancement
                let processedImage = self.applyPostProcessing(image: visionKitImage, filterType: self.filterType)
                
                // Save the final processed image
                let url = tempDirPath.appendingPathComponent(formattedDate + "-\(i).\(self.scannerOptions.imageFormat.rawValue)")
                
                switch self.scannerOptions.imageFormat {
                case .jpg:
                    try? processedImage.jpegData(compressionQuality: self.scannerOptions.jpgCompressionQuality)?.write(to: url)
                case .png:
                    try? processedImage.pngData()?.write(to: url)
                }
                
                // Optionally save to gallery
                if self.saveInGallery {
                    UIImageWriteToSavedPhotosAlbum(processedImage, nil, nil, nil)
                }
                
                filenames.append(url.path)
            }
            
            DispatchQueue.main.async {
                self.resultChannel?(filenames)
                self.presentingController?.dismiss(animated: true)
            }
        }
    }

    private func applyPostProcessing(image: UIImage, filterType: String) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        // First neutralize VisionKit's auto-enhancement
        let neutralizer = CIFilter(name: "CIColorControls")!
        neutralizer.setValue(ciImage, forKey: kCIInputImageKey)
        neutralizer.setValue(0.0, forKey: kCIInputSaturationKey)  // Remove color saturation
        neutralizer.setValue(0.0, forKey: kCIInputContrastKey)     // Remove contrast enhancement
        neutralizer.setValue(0.0, forKey: kCIInputBrightnessKey)   // Remove brightness adjustment
        
        guard let neutralizedImage = neutralizer.outputImage else { return image }
        
        // Then apply user-selected filter
        switch filterType {
        case "grayscale":
            let grayscale = CIFilter(name: "CIPhotoEffectMono")!
            grayscale.setValue(neutralizedImage, forKey: kCIInputImageKey)
            return renderCIImage(grayscale.outputImage!)
            
        case "blackAndWhite":
            let bwFilter = CIFilter(name: "CIColorControls")!
            bwFilter.setValue(neutralizedImage, forKey: kCIInputImageKey)
            bwFilter.setValue(0.0, forKey: kCIInputSaturationKey)
            bwFilter.setValue(1.0, forKey: kCIInputContrastKey)
            return renderCIImage(bwFilter.outputImage!)
            
        case "enhanced":
            let enhanceFilter = CIFilter(name: "CISharpenLuminance")!
            enhanceFilter.setValue(neutralizedImage, forKey: kCIInputImageKey)
            enhanceFilter.setValue(0.7, forKey: kCIInputSharpnessKey)
            return renderCIImage(enhanceFilter.outputImage!)
            
        default: // "color" - return neutralized image
            return renderCIImage(neutralizedImage)
        }
    }
    
    private func renderCIImage(_ ciImage: CIImage) -> UIImage {
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: cgImage)
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
