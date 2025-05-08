//
//  TLSCertificateTemplateObject.swift
//  tls-gen
//
//  Created by Всеволод Донченко on 07.05.2025.
//

import Foundation
import RealmSwift

final class TLSCertificateTemplateObject: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted var date: Date
    @Persisted var name: String
    @Persisted var version: TLSCertificate.Version
    @Persisted var organizationName: String
    @Persisted var lifetime: TimeInterval
    @Persisted var extensionsData: Data
    @Persisted var algorithmData: Data
    @Persisted var p12InfoData: Data
}

extension TLSCertificateTemplateObject {
    convenience init(from temp: TLSCertificateTemplate) throws {
        self.init()
        
        self.id = temp.id
        self.date = temp.date
        self.name = temp.name
        self.version = temp.version
        self.organizationName = temp.organizationName
        self.lifetime = temp.lifetime
        
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        
        self.extensionsData = try encoder.encode(temp.extensions)
        self.algorithmData = try encoder.encode(temp.algorithm)
        self.p12InfoData = try encoder.encode(temp.p12Info)
    }
}
