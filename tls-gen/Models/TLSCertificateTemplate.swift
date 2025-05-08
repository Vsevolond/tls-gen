//
//  TLSCertificateTemplate.swift
//  tls-gen
//
//  Created by Всеволод Донченко on 07.05.2025.
//

import Foundation

struct TLSCertificateTemplate: Equatable {
    enum P12Info: Codable, Equatable {
        case notRequired
        case required(p12Password: String)
    }
    
    let id: UUID
    let date: Date
    let name: String
    let version: TLSCertificate.Version
    let organizationName: String
    let lifetime: TimeInterval
    let extensions: TLSCertificate.Extensions
    let algorithm: TLSCertificate.SignatureAlgorithm
    let p12Info: P12Info
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        name: String,
        version: TLSCertificate.Version,
        organizationName: String,
        lifetime: TimeInterval,
        extensions: TLSCertificate.Extensions,
        algorithm: TLSCertificate.SignatureAlgorithm,
        p12Info: P12Info
    ) {
        self.id = id
        self.date = date
        self.name = name
        self.version = version
        self.organizationName = organizationName
        self.lifetime = lifetime
        self.extensions = extensions
        self.algorithm = algorithm
        self.p12Info = p12Info
    }
}

extension TLSCertificateTemplate {
    
    init(from object: TLSCertificateTemplateObject) throws {
        self.id = object.id
        self.date = object.date
        self.name = object.name
        self.version = object.version
        self.organizationName = object.organizationName
        self.lifetime = object.lifetime
        
        let decoder = PropertyListDecoder()
        
        self.extensions = try decoder.decode(TLSCertificate.Extensions.self, from: object.extensionsData)
        self.algorithm = try decoder.decode(TLSCertificate.SignatureAlgorithm.self, from: object.algorithmData)
        self.p12Info = try decoder.decode(P12Info.self, from: object.p12InfoData)
    }
}
