//
//  TLSCertificate.swift
//  tls-gen
//
//  Created by Всеволод Донченко on 15.04.2025.
//

import Foundation
import RealmSwift
import Network

struct TLSCertificate: Hashable {
    enum Version: String, Hashable, CaseIterable {
        case v1
        case v3
    }
    
    enum Signing: Codable, Hashable {
        case selfSigned
        case signedByCA(issuerId: UUID, issuerName: String)
    }

    struct Extensions: Codable, Hashable {
        enum BasicConstraints: Codable, Hashable {
            enum MaxPathLength: Codable, Hashable {
                case unlimited
                case limited(count: Int)
            }
            
            case isCertificateAuthority(maxPathLength: MaxPathLength)
            case notCertificateAuthority
        }
        
        enum KeyUsage: Codable, Hashable, CaseIterable {
            case digitalSignature
            case keyEncipherment
            case keyAgreement
            case keyCertSign
            case cRLSign
        }
        
        enum ExtendedKeyUsage: Codable, Hashable, CaseIterable {
            case serverAuth
            case clientAuth
        }
        
        enum SubjectAlternativeName: Codable, Hashable {
            case dnsName(String)
            case ipAddress(IPv4Address)
        }
        
        let basicConstraints: BasicConstraints
        let keyUsages: Set<KeyUsage>
        let extendedKeyUsages: Set<ExtendedKeyUsage>
        let subjectKeyIdentifierIncludes: Bool
        let authorityKeyIdentifierIncludes: Bool
        let subjectAlternativeNames: Set<SubjectAlternativeName>
    }
    
    enum SignatureAlgorithm: Codable, Hashable {
        enum HashFunction: Codable, Hashable, CaseIterable {
            case sha256
            case sha384
            case sha512
        }
        
        enum RSAKeySize: Codable, Hashable, CaseIterable {
            case bits2048
            case bits3072
            case bits4096
        }
        
        case ecdsa(HashFunction)
        case rsa(RSAKeySize, HashFunction)
        case eddsaWithCurve25519
    }
    
    struct P12Info: Codable, Hashable {
        let url: URL
        let password: String
    }
    
    let id: UUID
    let version: Version
    let commonName: String
    let serialNumber: String
    let createDate: Date
    let expirationDate: Date
    let certUrl: URL
    let keyUrl: URL
    let signing: Signing
    let extensions: Extensions
    let algorithm: SignatureAlgorithm
    let p12Info: P12Info?
    
    init(
        id: UUID = UUID(),
        version: Version,
        commonName: String,
        serialNumber: String,
        createDate: Date,
        expirationDate: Date,
        certUrl: URL,
        keyUrl: URL,
        signing: Signing,
        extensions: Extensions,
        algorithm: SignatureAlgorithm,
        p12Info: P12Info? = nil
    ) {
        self.id = id
        self.version = version
        self.commonName = commonName
        self.serialNumber = serialNumber
        self.createDate = createDate
        self.expirationDate = expirationDate
        self.certUrl = certUrl
        self.keyUrl = keyUrl
        self.signing = signing
        self.extensions = extensions
        self.algorithm = algorithm
        self.p12Info = p12Info
    }
}

extension TLSCertificate {
    
    init(from object: TLSCertificateObject) throws {
        self.id = object.id
        self.version = object.version
        self.commonName = object.commonName
        self.serialNumber = object.serialNumber
        self.createDate = object.createDate
        self.expirationDate = object.expirationDate
        self.certUrl = URL(fileURLWithPath: object.certPath)
        self.keyUrl = URL(fileURLWithPath: object.keyPath)
        
        let decoder = PropertyListDecoder()
        
        self.signing = try decoder.decode(Signing.self, from: object.signingData)
        self.extensions = try decoder.decode(Extensions.self, from: object.extensionsData)
        self.algorithm = try decoder.decode(SignatureAlgorithm.self, from: object.algorithmData)
        
        if let p12InfoData = object.p12InfoData {
            self.p12Info = try decoder.decode(P12Info.self, from: p12InfoData)
            
        } else {
            self.p12Info = nil
        }
    }
}

extension TLSCertificate.Version: PersistableEnum {}

extension IPv4Address: Codable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.debugDescription)
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let ipAddress = try container.decode(String.self)
        
        guard let ipv4 = IPv4Address(ipAddress) else {
            throw NSError(domain: "IPv4Address", code: -1)
        }
        
        self = ipv4
    }
}
