import UIKit
import VisionKit
import Vision
import Flutter

@objc public class CunningDocumentScannerPlugin: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "cunning_document_scanner", binaryMessenger: registrar.messenger())
        let instance = CunningDocumentScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    private var resultHandler: FlutterResult?
    private var saveInGallery = false
    private var filterType = "color"
    private var imageFormat = "png"
    private var jpgCompressionQuality: Double = 1.0
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getPictures" {
            let arguments = call.arguments as? [String: Any]
            saveInGallery = arguments?["saveInGallery"] as? Bool ?? false
            filterType = arguments?["filterType"] as? String ?? "color"
            imageFormat = arguments?["imageFormat"] as? String ?? "png"
            jpgCompressionQuality = arguments?["jpgCompressionQuality"] as? Double ?? 1.0
            
            resultHandler = result
            presentVisionKitScanner()
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func presentVisionKitScanner() {
        DispatchQueue.main.async {
            guard VNDocumentCameraViewController.isSupported,
                  let rootVC = UIApplication.shared.keyWindow?.rootViewController else {
                self.resultHandler?(FlutterError(code: "ERROR", message: "Document scanning not supported", details: nil))
                return
            }
            
            let scannerVC = VNDocumentCameraViewController()
            scannerVC.delegate = self
            rootVC.present(scannerVC, animated: true)
        }
    }
    
    // MARK: - VNDocumentCameraViewControllerDelegate
    
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true) {
            self.processScannedDocument(scan: scan)
        }
    }
    
    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true) {
            self.resultHandler?(FlutterError(code: "CANCELLED", message: "User cancelled scan", details: nil))
        }
    }
    
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true) {
            self.resultHandler?(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func processScannedDocument(scan: VNDocumentCameraScan) {
        DispatchQueue.global(qos: .userInitiated).async {
            var processedImagePaths: [String] = []
            
            for pageIndex in 0..<scan.pageCount {
                let originalImage = scan.imageOfPage(at: pageIndex)
                let processedImage = self.applyFilter(image: originalImage, filterType: self.filterType)
                
                let filePath = self.saveImageToTempFile(image: processedImage, pageIndex: pageIndex)
                processedImagePaths.append(filePath)
                
                if self.saveInGallery {
                    UIImageWriteToSavedPhotosAlbum(processedImage, nil, nil, nil)
                }
            }
            
            DispatchQueue.main.async {
                self.resultHandler?(processedImagePaths)
            }
        }
    }
    
    private func saveImageToTempFile(image: UIImage, pageIndex: Int) -> String {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let fileName = "scan_\(pageIndex)_\(Date().timeIntervalSince1970).\(self.imageFormat == "jpg" ? "jpg" : "png")"
        let filePath = paths[0].appendingPathComponent(fileName)
        
        let data: Data?
        if self.imageFormat == "jpg" {
            data = image.jpegData(compressionQuality: CGFloat(self.jpgCompressionQuality))
        } else {
            data = image.pngData()
        }
        
        if let validData = data {
            try? validData.write(to: filePath)
        }
        
        return filePath.path
    }
    
    private func applyFilter(image: UIImage, filterType: String) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        switch filterType {
        case "grayscale":
            let grayscale = CIFilter(name: "CIPhotoEffectMono")!
            grayscale.setValue(ciImage, forKey: kCIInputImageKey)
            return renderCIImage(grayscale.outputImage!)
            
        case "blackAndWhite":
            let bwFilter = CIFilter(name: "CIColorControls")!
            bwFilter.setValue(ciImage, forKey: kCIInputImageKey)
            bwFilter.setValue(0.0, forKey: kCIInputSaturationKey)
            bwFilter.setValue(1.1, forKey: kCIInputContrastKey)
            return renderCIImage(bwFilter.outputImage!)
            
        case "enhanced":
            let enhanceFilter = CIFilter(name: "CISharpenLuminance")!
            enhanceFilter.setValue(ciImage, forKey: kCIInputImageKey)
            enhanceFilter.setValue(0.5, forKey: kCIInputSharpnessKey)
            return renderCIImage(enhanceFilter.outputImage!)
            
        default: // Color/original
            return image
        }
    }
    
    private func renderCIImage(_ ciImage: CIImage) -> UIImage {
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: cgImage)
    }
}


