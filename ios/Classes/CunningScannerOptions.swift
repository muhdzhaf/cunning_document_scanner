//
//  ScannerOptions.swift
//  cunning_document_scanner
//
//  Created by Maurits van Beusekom on 15/10/2024.
//

import Foundation

enum CunningScannerImageFormat: String {
    case jpg
    case png
}

enum CunningScannerFilter: String {
    case none
    case photo
    case grayscale
    case blackAndWhite
}

struct CunningScannerOptions {
    let imageFormat: CunningScannerImageFormat
    let jpgCompressionQuality: Double
    let scanFilter: CunningScannerFilter
    
    init() {
        self.imageFormat = CunningScannerImageFormat.png
        self.jpgCompressionQuality = 1.0
        self.scanFilter = CunningScannerFilter.photo
    }
    
    init(imageFormat: CunningScannerImageFormat) {
        self.imageFormat = imageFormat
        self.jpgCompressionQuality = 1.0
        self.scanFilter = CunningScannerFilter.photo
    }
    
    init(imageFormat: CunningScannerImageFormat, jpgCompressionQuality: Double) {
        self.imageFormat = imageFormat
        self.jpgCompressionQuality = jpgCompressionQuality
        self.scanFilter = CunningScannerFilter.photo
    }
    
    init(imageFormat: CunningScannerImageFormat, jpgCompressionQuality: Double, scanFilter: CunningScannerFilter) {
        self.imageFormat = imageFormat
        self.jpgCompressionQuality = jpgCompressionQuality
        self.scanFilter = scanFilter
    }
    
    static func fromArguments(args: Any?) -> CunningScannerOptions {
        if (args == nil) {
            return CunningScannerOptions()
        }
        
        let arguments = args as? Dictionary<String, Any>
    
        if arguments == nil || arguments!.keys.contains("iosScannerOptions") == false {
            return CunningScannerOptions()
        }
        
        let scannerOptionsDict = arguments!["iosScannerOptions"] as! Dictionary<String, Any>
        let imageFormat: String = (scannerOptionsDict["imageFormat"] as? String) ?? "png"
        let jpgCompressionQuality: Double = (scannerOptionsDict["jpgCompressionQuality"] as? Double) ?? 1.0
        let scanFilter: String = (scannerOptionsDict["scanFilter"] as? String) ?? "photo"
            
        return CunningScannerOptions(
            imageFormat: CunningScannerImageFormat(rawValue: imageFormat) ?? CunningScannerImageFormat.png,
            jpgCompressionQuality: jpgCompressionQuality,
            scanFilter: CunningScannerFilter(rawValue: scanFilter) ?? CunningScannerFilter.photo
        )
    }
}
