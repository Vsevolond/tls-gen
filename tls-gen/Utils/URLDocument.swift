//
//  URLDocument.swift
//  tls-gen
//
//  Created by Всеволод Донченко on 18.04.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct URLDocument: FileDocument {
    let url: URL

    static var readableContentTypes: [UTType] { [.fileURL] }
    
    init(url: URL) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        throw NSError(domain: "URLDocument", code: -1)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let fileWrapper = try FileWrapper(url: url, options: [])
        return fileWrapper
    }
}
