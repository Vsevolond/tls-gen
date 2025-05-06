//
//  TLSGenerator.swift
//  tls-gen
//
//  Created by Всеволод Донченко on 14.04.2025.
//

import Foundation
import X509
import Crypto
import _CryptoExtras
import SwiftASN1
import OpenSSL
import Network

struct CertificateInputInfo {
    enum Signing {
        case selfSigned
        case signedByCA(issuerCert: Certificate, privateKey: Certificate.PrivateKey)
    }
    
    let version: TLSCertificate.Version
    let commonName: String
    let organizationName: String
    let signing: Signing
    let lifetime: TimeInterval
    let extensions: TLSCertificate.Extensions
    let algorithm: TLSCertificate.SignatureAlgorithm
}

struct CertificateOutputInfo {
    let serialNumber: String
    let certUrl: URL
    let keyUrl: URL
    let createDate: Date
    let expirationDate: Date
    
    let certificate: Certificate
    let privateKey: Certificate.PrivateKey
    
    init(
        serialNumber: String,
        certUrl: URL,
        keyUrl: URL,
        createDate: Date,
        expirationDate: Date,
        certificate: Certificate,
        privateKey: Certificate.PrivateKey
    ) {
        self.serialNumber = serialNumber
        self.certUrl = certUrl
        self.keyUrl = keyUrl
        self.createDate = createDate
        self.expirationDate = expirationDate
        self.certificate = certificate
        self.privateKey = privateKey
    }
}

final class TLSService {
    let basePath: URL
    
    init() {
        do {
            let basePath = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appending(path: "ssl-certs")
            
            try FileManager.default.createDirectory(at: basePath, withIntermediateDirectories: true)
            
            self.basePath = basePath
            
        } catch {
            fatalError("can't create directory for certs: \(error)")
        }
    }
    
    func generateCertificate(from input: CertificateInputInfo) throws -> CertificateOutputInfo {
        let privateKey = try Certificate.PrivateKey.makeWithSignatureAlgorithm(input.algorithm)
        let serialNumber = Certificate.SerialNumber()
        
        let subject = try DistinguishedName {
            CommonName(input.commonName)
            OrganizationName(input.organizationName)
        }
        
        let createDate = Date()
        let expirationDate = createDate.addingTimeInterval(input.lifetime)
        
        let version = Certificate.Version.makeWithCertificateVersion(input.version)
        let signatureAlgorithm = Certificate.SignatureAlgorithm.makeWithSignatureAlgorithm(input.algorithm)
        
        let extensions = try Certificate.Extensions.makeWithCertificateExtensions(
            input.extensions,
            signing: input.signing,
            privateKey: privateKey,
            distinguishedName: subject,
            serialNumber: serialNumber
        )
        
        switch input.signing {
        case .selfSigned:
            let certificate = try Certificate(
                version: version,
                serialNumber: serialNumber,
                publicKey: privateKey.publicKey,
                notValidBefore: createDate,
                notValidAfter: expirationDate,
                issuer: subject,
                subject: subject,
                signatureAlgorithm: signatureAlgorithm,
                extensions: extensions,
                issuerPrivateKey: privateKey
            )
            
            let (certUrl, keyUrl) = try saveCertificate(certificate, withKey: privateKey, name: input.commonName)
            
            return CertificateOutputInfo(
                serialNumber: serialNumber.description,
                certUrl: certUrl,
                keyUrl: keyUrl,
                createDate: createDate,
                expirationDate: expirationDate,
                certificate: certificate,
                privateKey: privateKey
            )
            
        case .signedByCA(let authorityCert, let authorityPrivateKey):
            let csr = try CertificateSigningRequest(
                version: CertificateSigningRequest.Version.v1,
                subject: subject,
                privateKey: privateKey,
                attributes: CertificateSigningRequest.Attributes(),
                signatureAlgorithm: signatureAlgorithm
            )
            
            let certificate = try Certificate(
                version: version,
                serialNumber: serialNumber,
                publicKey: csr.publicKey,
                notValidBefore: createDate,
                notValidAfter: expirationDate,
                issuer: authorityCert.subject,
                subject: csr.subject,
                signatureAlgorithm: signatureAlgorithm,
                extensions: extensions,
                issuerPrivateKey: authorityPrivateKey
            )
            
            let (certUrl, keyUrl) = try saveCertificate(certificate, withKey: privateKey, name: input.commonName)
            
            return CertificateOutputInfo(
                serialNumber: serialNumber.description,
                certUrl: certUrl,
                keyUrl: keyUrl,
                createDate: createDate,
                expirationDate: expirationDate,
                certificate: certificate,
                privateKey: privateKey
            )
        }
    }
    
    func loadCertificateWithPrivateKey(byName name: String) throws -> (Certificate, Certificate.PrivateKey) {
        let commonName = name.lowercased().replacingOccurrences(of: " ", with: "-")
        
        let certPath = basePath.appendingPathComponent("\(commonName).crt")
        let keyPath = basePath.appendingPathComponent("\(commonName).key")

        let certPem = try String(contentsOf: certPath, encoding: .utf8)
        let keyPem = try String(contentsOf: keyPath, encoding: .utf8)

        let certificate = try Certificate(pemEncoded: certPem)
        let privateKey = try Certificate.PrivateKey(pemEncoded: keyPem)

        return (certificate, privateKey)
    }

    func exportToP12(
        password: String,
        name: String,
        privateKey: Certificate.PrivateKey,
        certificate: Certificate
    ) throws -> URL {
        let certificatePem = try certificate.serializeAsPEM().pemString
        let privateKeyPem = try privateKey.serializeAsPEM().pemString
        
        let certificateData = Data(certificatePem.utf8)
        let privateKeyData = Data(privateKeyPem.utf8)
        
        let bioCertificate = BIO_new_mem_buf(
            certificateData.withUnsafeBytes { $0.baseAddress },
            Int32(certificateData.count)
        )
        let bioPrivateKey = BIO_new_mem_buf(
            privateKeyData.withUnsafeBytes { $0.baseAddress },
            Int32(privateKeyData.count)
        )
        
        let bioOutput = BIO_new(BIO_s_mem())
        
        var certificatePtr: OpaquePointer?
        var privateKeyPtr: OpaquePointer?
        
        defer {
            BIO_free(bioCertificate)
            BIO_free(bioPrivateKey)
            
            X509_free(certificatePtr)
            EVP_PKEY_free(privateKeyPtr)
        }
        
        certificatePtr = PEM_read_bio_X509(bioCertificate, nil, nil, nil)
        privateKeyPtr = PEM_read_bio_PrivateKey(bioPrivateKey, nil, nil, nil)
        
        guard let certificatePtr, let privateKeyPtr else {
            throw NSError(domain: "OpenSSL", code: -1)
        }
        
        let p12Data = try password.withCString { passwordPtr in
            try name.withCString { namePtr in
                guard let p12Pointer = PKCS12_create(
                    passwordPtr,
                    namePtr,
                    privateKeyPtr,
                    certificatePtr,
                    nil,
                    0,
                    0,
                    0,
                    0,
                    0
                ) else {
                    throw NSError(domain: "OpenSSL", code: -3)
                }
                
                defer { PKCS12_free(p12Pointer) }
                
                guard i2d_PKCS12_bio(bioOutput, p12Pointer) == 1 else {
                    throw NSError(domain: "OpenSSL", code: -4)
                }
                
                let length = BIO_ctrl_pending(bioOutput)
                var buffer = [UInt8](repeating: 0, count: length)
                let bytes = BIO_read(bioOutput, &buffer, Int32(length))
                
                guard bytes > 0 else {
                    throw NSError(domain: "OpenSSL", code: -5)
                }
                
                return Data(buffer[0..<Int(bytes)])
            }
        }
        
        return try saveContainer(data: p12Data, withName: name)
    }
    
    func loadCertificateRepresentation(url: URL) -> String? {
        guard let bio = BIO_new_file(url.path, "r") else { return nil }
        defer { BIO_free(bio) }
        
        guard let cert = PEM_read_bio_X509(bio, nil, nil, nil) else { return nil }
        defer { X509_free(cert) }
        
        guard let mem = BIO_new(BIO_s_mem()) else { return nil }
        defer { BIO_free(mem) }
        
        X509_print(mem, cert)
        
        let length = BIO_ctrl_pending(mem)
        var buffer = [UInt8](repeating: 0, count: Int(length))
        let bytesRead = BIO_read(mem, &buffer, Int32(length))

        guard bytesRead > 0 else { return nil }
        return String(decoding: buffer[0..<Int(bytesRead)], as: UTF8.self)
    }
    
    func loadPrivateKeyRepresentation(url: URL) -> String? {
        guard let bio = BIO_new_file(url.path, "r") else { return nil }
        defer { BIO_free(bio) }

        guard let pkey = PEM_read_bio_PrivateKey(bio, nil, nil, nil) else { return nil }
        defer { EVP_PKEY_free(pkey) }

        guard let mem = BIO_new(BIO_s_mem()) else { return nil }
        defer { BIO_free(mem) }

        EVP_PKEY_print_private(mem, pkey, 0, nil)

        let length = BIO_ctrl_pending(mem)
        var buffer = [UInt8](repeating: 0, count: Int(length))
        let bytesRead = BIO_read(mem, &buffer, Int32(length))

        guard bytesRead > 0 else { return nil }
        return String(decoding: buffer[0..<Int(bytesRead)], as: UTF8.self)
    }
    
    private func saveCertificate(
        _ certificate: Certificate,
        withKey privateKey: Certificate.PrivateKey,
        name: String
    ) throws -> (certPath: URL, keyPath: URL) {
        let commonName = name.lowercased().replacingOccurrences(of: " ", with: "-")
        
        let certPath = basePath.appending(path: "\(commonName).crt")
        let keyPath = basePath.appending(path: "\(commonName).key")
        
        let certPem = try certificate.serializeAsPEM().pemString
        try certPem.write(to: certPath, atomically: true, encoding: .utf8)
        
        let keyPem = try privateKey.serializeAsPEM().pemString
        try keyPem.write(to: keyPath, atomically: true, encoding: .utf8)
        
        return (certPath, keyPath)
    }
    
    private func saveContainer(data: Data, withName name: String) throws -> URL {
        let commonName = name.lowercased().replacingOccurrences(of: " ", with: "-")
        
        let containerPath = basePath.appending(path: "\(commonName).p12")
        try data.write(to: containerPath, options: .atomic)
        
        return containerPath
    }
}

fileprivate extension Certificate.PrivateKey {
    
    static func makeWithSignatureAlgorithm(
        _ signatureAlgorithm: TLSCertificate.SignatureAlgorithm
    ) throws -> Certificate.PrivateKey {
        switch signatureAlgorithm {
        case .ecdsa(let hashFunction):
            switch hashFunction {
            case .sha256:
                let key = P256.Signing.PrivateKey()
                return Certificate.PrivateKey(key)
                
            case .sha384:
                let key = P384.Signing.PrivateKey()
                return Certificate.PrivateKey(key)
                
            case .sha512:
                let key = P521.Signing.PrivateKey()
                return Certificate.PrivateKey(key)
            }
            
        case .rsa(let rsaKeySize, _):
            switch rsaKeySize {
            case .bits2048:
                let key = try _RSA.Signing.PrivateKey(keySize: .bits2048)
                return Certificate.PrivateKey(key)
                
            case .bits3072:
                let key = try _RSA.Signing.PrivateKey(keySize: .bits3072)
                return Certificate.PrivateKey(key)
                
            case .bits4096:
                let key = try _RSA.Signing.PrivateKey(keySize: .bits4096)
                return Certificate.PrivateKey(key)
            }
            
        case .eddsaWithCurve25519:
            let key = Curve25519.Signing.PrivateKey()
            return Certificate.PrivateKey(key)
        }
    }
}

fileprivate extension Certificate.SignatureAlgorithm {
    
    static func makeWithSignatureAlgorithm(
        _ signatureAlgorithm: TLSCertificate.SignatureAlgorithm
    ) -> Certificate.SignatureAlgorithm {
        switch signatureAlgorithm {
        case .ecdsa(let hashFunction):
            switch hashFunction {
            case .sha256:
                return .ecdsaWithSHA256
                
            case .sha384:
                return .ecdsaWithSHA384
                
            case .sha512:
                return .ecdsaWithSHA512
            }
            
        case .rsa(_, let hashFunction):
            switch hashFunction {
            case .sha256:
                return .sha256WithRSAEncryption
                
            case .sha384:
                return .sha384WithRSAEncryption
                
            case .sha512:
                return .sha512WithRSAEncryption
            }
            
        case .eddsaWithCurve25519:
            return .ed25519
        }
    }
}

fileprivate extension Certificate.Extensions {
    
    static func makeWithCertificateExtensions(
        _ extensions: TLSCertificate.Extensions,
        signing: CertificateInputInfo.Signing,
        privateKey: Certificate.PrivateKey,
        distinguishedName: DistinguishedName,
        serialNumber: Certificate.SerialNumber
    ) throws -> Certificate.Extensions {
        try Certificate.Extensions {
            switch extensions.basicConstraints {
            case .isCertificateAuthority(let maxPathLength):
                switch maxPathLength {
                case .unlimited:
                    Critical(
                        X509.BasicConstraints.isCertificateAuthority(maxPathLength: nil)
                    )
                    
                case .limited(let count):
                    Critical(
                        X509.BasicConstraints.isCertificateAuthority(maxPathLength: count)
                    )
                }
                
            case .notCertificateAuthority:
                Critical(
                    X509.BasicConstraints.notCertificateAuthority
                )
            }
            
            if !extensions.keyUsages.isEmpty {
                let usages = extensions.keyUsages
                
                Critical(
                    X509.KeyUsage(
                        digitalSignature: usages.contains(.digitalSignature),
                        keyEncipherment: usages.contains(.keyEncipherment),
                        keyAgreement: usages.contains(.keyAgreement),
                        keyCertSign: usages.contains(.keyCertSign),
                        cRLSign: usages.contains(.cRLSign)
                    )
                )
            }
            
            if !extensions.extendedKeyUsages.isEmpty {
                try X509.ExtendedKeyUsage(
                    extensions.extendedKeyUsages.map { usage in
                        return switch usage {
                        case .clientAuth: .clientAuth
                        case .serverAuth: .serverAuth
                        }
                    }
                )
            }
            
            if extensions.subjectKeyIdentifierIncludes {
                SubjectKeyIdentifier(keyIdentifier: privateKey.publicKey.subjectPublicKeyInfoBytes)
            }
            
            if extensions.authorityKeyIdentifierIncludes {
                switch signing {
                case .selfSigned:
                    AuthorityKeyIdentifier(
                        keyIdentifier: privateKey.publicKey.subjectPublicKeyInfoBytes,
                        authorityCertIssuer: [.directoryName(distinguishedName)],
                        authorityCertSerialNumber: serialNumber
                    )
                    
                case .signedByCA(let authorityCert, let authorityPrivateKey):
                    AuthorityKeyIdentifier(
                        keyIdentifier: authorityPrivateKey.publicKey.subjectPublicKeyInfoBytes,
                        authorityCertIssuer: [.directoryName(authorityCert.subject)],
                        authorityCertSerialNumber: authorityCert.serialNumber
                    )
                }
            }
            
            if !extensions.subjectAlternativeNames.isEmpty {
                SubjectAlternativeNames(
                    extensions.subjectAlternativeNames.map { altName in
                        switch altName {
                        case .dnsName(let dns):
                            return .dnsName(dns)
                            
                        case .ipAddress(let ipv4):
                            let parts = ipv4.debugDescription.split(separator: ".").compactMap { UInt8($0) }
                            return .ipAddress(
                                ASN1OctetString(contentBytes: ArraySlice(parts))
                            )
                        }
                    }
                )
            }
        }
    }
}

fileprivate extension Certificate.Version {
    
    static func makeWithCertificateVersion(_ version: TLSCertificate.Version) -> Certificate.Version {
        switch version {
        case .v1: return .v1
        case .v3: return .v3
        }
    }
}
