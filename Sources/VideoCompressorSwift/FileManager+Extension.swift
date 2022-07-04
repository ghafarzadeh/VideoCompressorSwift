//
//  File.swift
//  
//
//  Created by Habib Ghaffarzadeh on 1.07.2022.
//

import Foundation

extension FileManager {    
    public static func tempDirectory(with pathComponent: String = ProcessInfo.processInfo.globallyUniqueString) throws -> URL {
        var tempURL: URL
        let cacheURL = FileManager.default.temporaryDirectory
        if let url = try? FileManager.default.url(for: .itemReplacementDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: cacheURL,
                                                     create: true) {
            tempURL = url
        } else {
            tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
        }

        tempURL.appendPathComponent(pathComponent)

        if !FileManager.default.fileExists(atPath: tempURL.absoluteString) {
            do {
                try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
                return tempURL
            } catch {
                throw error
            }
        } else {
            return tempURL
        }
    }
}
