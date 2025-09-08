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
    private let ciContext = CIContext()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "cunning_document_scanner", binaryMessenger: registrar.messenger())
        let instance = SwiftCunningDocumentScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
        var top = root
        while let next = top?.presentedViewController { top = next }
        return top
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getPictures" {
            scannerOptions = CunningScannerOptions.fromArguments(args: call.arguments)
            self.resultChannel = result

            guard presentingController == nil else {
                result(FlutterError(code: "ALREADY_PRESENTED", message: "Scanner already active", details: nil))
                return
            }
            
            guard VNDocumentCameraViewController.isSupported,
                  let presenter = topViewController() else {
                result(FlutterError(code: "UNAVAILABLE", message: "Document camera not available", details: nil))
                return
            }
            
            DispatchQueue.main.async {
                let vc = VNDocumentCameraViewController()
                vc.delegate = self
                self.presentingController = vc
                
                // Disable auto shutter after presentation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.disableAutoShutter(vc)
                }
                
                presenter.present(vc, animated: true)
            }
        } else {
            result(FlutterMethodNotImplemented)
            return
        }
    }

    private func disableAutoShutter(_ documentCameraVC: VNDocumentCameraViewController) {
        // Only disable if auto shutter is not enabled in options
        guard !scannerOptions.autoShutterEnabled else { return }
        
        // More reliable approach: find the specific camera view controller
        if let cameraController = findDocumentCameraController(in: documentCameraVC) {
            // Try multiple private API methods that might control auto capture
            let selectors = [
                "setAutoCaptureEnabled:",
                "autoCaptureEnabled",
                "setAutomaticallyCaptures:",
                "automaticallyCaptures"
            ]
            
            for selectorName in selectors {
                let selector = NSSelectorFromString(selectorName)
                if cameraController.responds(to: selector) {
                    // For boolean properties, we want to set to false
                    if selectorName.contains("set") {
                        cameraController.perform(selector, with: false)
                    } else if selectorName == "autoCaptureEnabled" || selectorName == "automaticallyCaptures" {
                        // If it's a getter, try to find the corresponding setter
                        let setterName = "set" + selectorName.prefix(1).uppercased() + selectorName.dropFirst()
                        let setterSelector = NSSelectorFromString(setterName + ":")
                        if cameraController.responds(to: setterSelector) {
                            cameraController.perform(setterSelector, with: false)
                        }
                    }
                }
            }
        }
    }

    private func findDocumentCameraController(in viewController: UIViewController) -> AnyObject? {
        // More specific search for the document camera controller
        let className = NSStringFromClass(type(of: viewController))
        
        // Look for classes that contain "Document" and "Camera" in their name
        if className.contains("Document") && className.contains("Camera") && className.contains("ViewController") {
            return viewController
        }
        
        // Recursively search through children
        for child in viewController.children {
            if let found = findDocumentCameraController(in: child) {
                return found
            }
        }
        
        // Also check presented view controllers
        if let presented = viewController.presentedViewController {
            if let found = findDocumentCameraController(in: presented) {
                return found
            }
        }
        
        return nil
    }

    private func applyFilterToImage(_ image: UIImage, filter: CunningScannerFilter) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        var outputImage: CIImage = ciImage
        
        switch filter {
        case .none:
            // No additional processing - keep VisionKit's default
            break
            
        case .photo:
            // For photo filter, we want to neutralize VisionKit's aggressive processing
            // by applying a light color correction to make it look more natural
            let exposure = CIFilter(name: "CIExposureAdjust")!
            exposure.setValue(outputImage, forKey: kCIInputImageKey)
            exposure.setValue(0.3, forKey: kCIInputEVKey) // Slight exposure adjustment
            
            let colorControls = CIFilter(name: "CIColorControls")!
            colorControls.setValue(exposure.outputImage ?? outputImage, forKey: kCIInputImageKey)
            colorControls.setValue(1.1, forKey: kCIInputSaturationKey) // Slightly enhance color
            colorControls.setValue(1.05, forKey: kCIInputContrastKey) // Slight contrast boost
            colorControls.setValue(0.05, forKey: kCIInputBrightnessKey) // Minor brightness adjustment
            
            outputImage = colorControls.outputImage ?? outputImage
            
        case .grayscale:
            // Convert to grayscale
            let grayscale = CIFilter(name: "CIPhotoEffectMono")!
            grayscale.setValue(outputImage, forKey: kCIInputImageKey)
            outputImage = grayscale.outputImage ?? outputImage
            
        case .blackAndWhite:
            // Convert to black and white with proper thresholding
            let grayscale = CIFilter(name: "CIPhotoEffectMono")!
            grayscale.setValue(outputImage, forKey: kCIInputImageKey)
            
            let colorControls = CIFilter(name: "CIColorControls")!
            colorControls.setValue(grayscale.outputImage ?? outputImage, forKey: kCIInputImageKey)
            colorControls.setValue(2.0, forKey: kCIInputContrastKey) // High contrast
            
            outputImage = colorControls.outputImage ?? outputImage
        }
        
        guard let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        let baseURL = FileManager.default.temporaryDirectory
        var filenames: [String] = []
        
        autoreleasepool {
            for i in 0 ..< scan.pageCount {
                var processedImage = scan.imageOfPage(at: i)
                
                // Apply post-processing filter
                if scannerOptions.scanFilter != .none {
                    processedImage = applyFilterToImage(processedImage, filter: scannerOptions.scanFilter)
                }
                
                let filename = "\(UUID().uuidString).\(scannerOptions.imageFormat.rawValue)"
                let url = baseURL.appendingPathComponent(filename)
                
                if let data = (scannerOptions.imageFormat == .jpg)
                    ? processedImage.jpegData(compressionQuality: scannerOptions.jpgCompressionQuality)
                    : processedImage.pngData() {
                    do {
                        try data.write(to: url)
                        filenames.append(url.path)
                    } catch {
                        print("Failed to write image file: \(error)")
                    }
                }
            }
        }
        
        self.resultChannel?(filenames)
        self.resultChannel = nil
        self.presentingController?.dismiss(animated: true)
        self.presentingController = nil
    }

    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        self.resultChannel?(nil)
        self.resultChannel = nil
        self.presentingController?.dismiss(animated: true)
        self.presentingController = nil
    }

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        self.resultChannel?(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
        self.resultChannel = nil
        self.presentingController?.dismiss(animated: true)
        self.presentingController = nil
    }
}
