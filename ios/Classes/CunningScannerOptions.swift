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
    let autoShutterEnabled: Bool
    
    init() {
        self.imageFormat = CunningScannerImageFormat.png
        self.jpgCompressionQuality = 1.0
        self.scanFilter = CunningScannerFilter.photo
        self.autoShutterEnabled = false
    }
    
    init(imageFormat: CunningScannerImageFormat, jpgCompressionQuality: Double, scanFilter: CunningScannerFilter, autoShutterEnabled: Bool) {
        self.imageFormat = imageFormat
        self.jpgCompressionQuality = jpgCompressionQuality
        self.scanFilter = scanFilter
        self.autoShutterEnabled = autoShutterEnabled
    }
    
    static func fromArguments(args: Any?) -> CunningScannerOptions {
        guard
            let root = args as? [String: Any],
            let dict = root["iosScannerOptions"] as? [String: Any]
        else { return .init() }

        let imageFormat = CunningScannerImageFormat(rawValue: (dict["imageFormat"] as? String) ?? "png") ?? .png
        let jpgQ = (dict["jpgCompressionQuality"] as? Double) ?? 1.0
        let scanFilter = CunningScannerFilter(rawValue: (dict["scanFilter"] as? String) ?? "photo") ?? .photo
        let autoShutterEnabled = (dict["autoShutterEnabled"] as? Bool) ?? false
        
        return .init(imageFormat: imageFormat, jpgCompressionQuality: jpgQ, scanFilter: scanFilter, autoShutterEnabled: autoShutterEnabled)
    }
}
