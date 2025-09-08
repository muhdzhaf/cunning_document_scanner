import UIKit
import AVFoundation
import Vision
import Flutter

public class CunningDocumentScannerPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "cunning_document_scanner", binaryMessenger: registrar.messenger())
        let instance = CunningDocumentScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getPictures" {
            let arguments = call.arguments as? [String: Any]
            let saveInGallery = arguments?["saveInGallery"] as? Bool ?? false
            let filterType = arguments?["filterType"] as? String ?? "color"
            
            presentCustomScanner(saveInGallery: saveInGallery, filterType: filterType, result: result)
        }
    }
    
    private func presentCustomScanner(saveInGallery: Bool, filterType: String, result: @escaping FlutterResult) {
        guard let rootVC = UIApplication.shared.keyWindow?.rootViewController else {
            result(FlutterError(code: "ERROR", message: "Unable to get root view controller", details: nil))
            return
        }
        
        let scannerVC = CustomScannerViewController()
        scannerVC.saveInGallery = saveInGallery
        scannerVC.selectedFilter = filterType
        scannerVC.resultHandler = result
        
        let navController = UINavigationController(rootViewController: scannerVC)
        navController.modalPresentationStyle = .fullScreen
        rootVC.present(navController, animated: true)
    }
}

private class CustomScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var rectangleDetectionRequest: VNDetectRectanglesRequest!
    private var lastDetectedRectangle: VNRectangleObservation?
    private var captureButton: UIButton!
    private var filterButton: UIButton!
    private var closeButton: UIButton!
    
    var saveInGallery = false
    var selectedFilter = "color"
    var resultHandler: FlutterResult?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCaptureSession()
        setupUI()
    }
    
    private func configureCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let captureDevice = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            resultHandler?(FlutterError(code: "ERROR", message: "Camera initialization failed", details: nil))
            dismiss(animated: true)
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        }
        
        setupPreviewLayer()
        setupRectangleDetection()
        
        captureSession.startRunning()
    }
    
    private func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }
    
    private func setupRectangleDetection() {
        rectangleDetectionRequest = VNDetectRectanglesRequest(completionHandler: handleRectangleDetection)
        rectangleDetectionRequest.minimumConfidence = 0.8
        rectangleDetectionRequest.minimumAspectRatio = 0.3
        rectangleDetectionRequest.maximumObservations = 1
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Close button
        closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.frame = CGRect(x: 20, y: 50, width: 80, height: 40)
        view.addSubview(closeButton)
        
        // Capture button
        captureButton = UIButton(type: .system)
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.frame = CGRect(x: view.frame.midX - 35, y: view.frame.maxY - 90, width: 70, height: 70)
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        view.addSubview(captureButton)
        
        // Filter button
        filterButton = UIButton(type: .system)
        filterButton.setTitle("Filter: \(selectedFilter.capitalized)", for: .normal)
        filterButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        filterButton.frame = CGRect(x: view.frame.width - 120, y: 50, width: 110, height: 40)
        filterButton.addTarget(self, action: #selector(filterTapped), for: .touchUpInside)
        view.addSubview(filterButton)
    }
    
    @objc private func closeTapped() {
        captureSession.stopRunning()
        dismiss(animated: true)
        resultHandler?(FlutterError(code: "CANCELLED", message: "User cancelled scan", details: nil))
    }
    
    @objc private func captureTapped() {
        DispatchQueue.global().async {
            self.processCapturedImage()
        }
    }
    
    @objc private func filterTapped() {
        let alert = UIAlertController(title: "Select Filter", message: nil, preferredStyle: .actionSheet)
        
        let filters = ["color", "grayscale", "blackAndWhite", "enhanced"]
        for filter in filters {
            alert.addAction(UIAlertAction(title: filter.capitalized, style: .default) { [weak self] _ in
                self?.selectedFilter = filter
                self?.filterButton.setTitle("Filter: \(filter.capitalized)", for: .normal)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func handleRectangleDetection(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRectangleObservation],
              let firstObservation = observations.first else {
            lastDetectedRectangle = nil
            return
        }
        
        lastDetectedRectangle = firstObservation
    }
    
    private func processCapturedImage() {
        // Add photo output if not already added
        let photoOutput = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        let settings = AVCapturePhotoSettings()
        if let delegate = self as? AVCapturePhotoCaptureDelegate {
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
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
    
    func captureOutput(_ output: AVCaptureOutput, 
                       didOutput sampleBuffer: CMSampleBuffer, 
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? requestHandler.perform([rectangleDetectionRequest])
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, 
                    didFinishProcessingPhoto photo: AVCapturePhoto, 
                    error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            showError(message: "Failed to capture image")
            return
        }
        
        var finalImage = image
        finalImage = applyFilter(image: finalImage, filterType: selectedFilter)
        
        if let lastRect = lastDetectedRectangle {
            finalImage = finalImage.applyingPerspectiveCorrection(rectangle: lastRect)
        }
        
        // Save to gallery if needed
        if saveInGallery {
            UIImageWriteToSavedPhotosAlbum(finalImage, nil, nil, nil)
        }
        
        // Save to temp file
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let filePath = paths[0].appendingPathComponent("scan_\(Date().timeIntervalSince1970).jpg")
        
        guard let data = finalImage.jpegData(compressionQuality: 0.9),
              (try? data.write(to: filePath)) != nil else {
            showError(message: "Failed to save image")
            return
        }
        
        DispatchQueue.main.async {
            self.captureSession.stopRunning()
            self.dismiss(animated: true) {
                self.resultHandler?([filePath.path])
            }
        }
    }
    
    private func showError(message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}

extension UIImage {
    func applyingPerspectiveCorrection(rectangle: VNRectangleObservation) -> UIImage {
        guard let ciImage = CIImage(image: self) else { return self }
        
        let perspectiveCorrection = CIFilter(name: "CIPerspectiveCorrection")!
        perspectiveCorrection.setValue(ciImage, forKey: kCIInputImageKey)
        
        // Convert normalized coordinates to image coordinates
        let imageSize = ciImage.extent.size
        perspectiveCorrection.setValue(
            CIVector(cgPoint: CGPoint(x: rectangle.topLeft.x * imageSize.width, 
                                     y: rectangle.topLeft.y * imageSize.height)),
            forKey: "inputTopLeft"
        )
        perspectiveCorrection.setValue(
            CIVector(cgPoint: CGPoint(x: rectangle.topRight.x * imageSize.width, 
                                     y: rectangle.topRight.y * imageSize.height)),
            forKey: "inputTopRight"
        )
        perspectiveCorrection.setValue(
            CIVector(cgPoint: CGPoint(x: rectangle.bottomRight.x * imageSize.width, 
                                     y: rectangle.bottomRight.y * imageSize.height)),
            forKey: "inputBottomRight"
        )
        perspectiveCorrection.setValue(
            CIVector(cgPoint: CGPoint(x: rectangle.bottomLeft.x * imageSize.width, 
                                     y: rectangle.bottomLeft.y * imageSize.height)),
            forKey: "inputBottomLeft"
        )
        
        guard let output = perspectiveCorrection.outputImage else { return self }
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return self }
        return UIImage(cgImage: cgImage)
    }
}

