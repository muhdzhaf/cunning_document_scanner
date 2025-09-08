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
                presenter.present(vc, animated: true)
            }
        } else {
            result(FlutterMethodNotImplemented)
            return
        }
    }

    private func applyFilterToImage(_ image: UIImage, filter: CunningScannerFilter) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        var outputImage: CIImage = ciImage
        
        switch filter {
        case .none:
            // No additional processing - keep VisionKit's default
            break
            
        case .photo:
            // Soften VisionKit's "Color" look (less pop, more neutral)
            // 1) Reduce vibrance (affects intense colors more gently than saturation)
            if let vibrance = CIFilter(name: "CIVibrance") {
                vibrance.setValue(outputImage, forKey: kCIInputImageKey)
                vibrance.setValue(-0.2, forKey: "inputAmount") // small pullback
                outputImage = vibrance.outputImage ?? outputImage
            }

            // 2) Slightly lower saturation & contrast; no brightness bump
            if let cc = CIFilter(name: "CIColorControls") {
                cc.setValue(outputImage, forKey: kCIInputImageKey)
                cc.setValue(0.9, forKey: kCIInputSaturationKey)  // from 1.0 -> 0.9
                cc.setValue(0.96, forKey: kCIInputContrastKey)   // from 1.0 -> 0.96
                cc.setValue(0.0, forKey: kCIInputBrightnessKey)  // avoid brightening
                outputImage = cc.outputImage ?? outputImage
            }

            // 3) Mild gamma to flatten midtone punch VisionKit adds
            if let gamma = CIFilter(name: "CIGammaAdjust") {
                gamma.setValue(outputImage, forKey: kCIInputImageKey)
                gamma.setValue(0.95, forKey: "inputPower")       // <1.0 lifts mids slightly
                outputImage = gamma.outputImage ?? outputImage
            }
            
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
