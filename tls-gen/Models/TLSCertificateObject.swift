//
//  TLSCertificateObject.swift
//  tls-gen
//
//  Created by Всеволод Донченко on 15.04.2025.
//

import Foundation
import RealmSwift

final class TLSCertificateObject: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted var version: TLSCertificate.Version
    @Persisted var commonName: String
    @Persisted var serialNumber: String
    @Persisted var createDate: Date
    @Persisted var expirationDate: Date
    @Persisted var certPath: String
    @Persisted var keyPath: String
    @Persisted var signingData: Data
    @Persisted var extensionsData: Data
    @Persisted var algorithmData: Data
    @Persisted var p12InfoData: Data?
}

extension TLSCertificateObject {
    
    convenience init(from cert: TLSCertificate) throws {
        self.init()
        
        self.id = cert.id
        self.version =  cert.version
        self.commonName = cert.commonName
        self.serialNumber = cert.serialNumber
        self.createDate = cert.createDate
        self.expirationDate = cert.expirationDate
        self.certPath = cert.certUrl.path
        self.keyPath = cert.keyUrl.path
        
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        
        self.signingData = try encoder.encode(cert.signing)
        self.extensionsData = try encoder.encode(cert.extensions)
        self.algorithmData = try encoder.encode(cert.algorithm)
        
        if let p12Info = cert.p12Info {
            self.p12InfoData = try encoder.encode(p12Info)
        }
    }
}
