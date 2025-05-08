//
//  ContentViewModel.swift
//  tls-gen
//
//  Created by Всеволод Донченко on 15.04.2025.
//

import SwiftUI
import Network
import os

enum ContentViewState: Equatable {
    case idle
    case loading
    case loaded
    case failed(error: String)
    
    var isFail: Bool {
        guard case .failed(_) = self else {
            return true
        }
        return false
    }
}

enum CreateCertificateResult {
    case success
    case failed(String)
}

final class ContentViewModel: ObservableObject {
    @Published var state: ContentViewState = .idle
    
    @Published var certificates = [TLSCertificate]()
    @Published var templates = [TLSCertificateTemplate]()
    
    var selfSignedCertAuthorites: [TLSCertificate] {
        certificates.filter { $0.signing == .selfSigned && $0.isCertificateAuthority }
    }
    
    var intermediateCertAuthorities: [TLSCertificate] {
        certificates.filter { $0.signing != .selfSigned && $0.isCertificateAuthority }
    }
    
    var nonCertAuthorities: [TLSCertificate] {
        certificates.filter { $0.signing != .selfSigned && !$0.isCertificateAuthority }
    }
    
    var leafCertificates: [TLSCertificate] {
        certificates.filter { $0.signing == .selfSigned && !$0.isCertificateAuthority }
    }
    
    var availableCertAuthorities: [TLSCertificate] {
        certificates.filter { cert in
            guard case .isCertificateAuthority(let maxPathLength) = cert.extensions.basicConstraints else {
                return false
            }
            
            switch maxPathLength {
            case .unlimited:
                return true
                
            case .limited(let count):
                return count > 0
            }
        }
    }
    
    private let storage = Storage()
    private let tlsService = TLSService()
    
    private lazy var logger = os.Logger(subsystem: Bundle.main.appId, category: "ContentViewModel")
    
    // TODO: make async loading certificates and templates
    func loadCertificatesAndTemplates() {
        guard state == .idle || state.isFail else { return }
        
        Task {
            do {
                let certs = try await storage.fetchCertificates()
                    .sorted(by: { $0.createDate > $1.createDate })
                
                let temps = try await storage.fetchTemplates()
                    .sorted(by: { $0.date > $1.date })
                
                Task { @MainActor in
                    self.certificates = certs
                    self.templates = temps
                    
                    self.state = .loaded
                }
                
            } catch is StorageError {
                Task { @MainActor in
                    self.state = .failed(error: "Не удалось отобразить данные")
                }
            }
        }
    }
    
    func createCertificate(
        version: TLSCertificate.Version,
        commonName: String,
        organizationName: String,
        signing: TLSCertificate.Signing,
        lifetime: TimeInterval,
        extensions: TLSCertificate.Extensions,
        algorithm: TLSCertificate.SignatureAlgorithm,
        p12Password: String?,
        completion: @escaping (CreateCertificateResult) -> Void
    ) {
        Task {
            guard !certificates.contains(where: { $0.commonName == commonName }) else {
                completion(.failed("Certificate with same name already exists"))
                return
            }
            
            do {
                let input = try makeCertificateInputInfo(
                    version: version,
                    commonName: commonName,
                    organizationName: organizationName,
                    signing: signing,
                    lifetime: lifetime,
                    extensions: extensions,
                    algorithm: algorithm
                )
                
                let output = try tlsService.generateCertificate(from: input)
                
                if let p12Password {
                    let p12Url = try tlsService.exportToP12(
                        password: p12Password,
                        name: commonName,
                        privateKey: output.privateKey,
                        certificate: output.certificate
                    )
                    
                    let p12Info = TLSCertificate.P12Info(url: p12Url, password: p12Password)
                    
                    let certificate = TLSCertificate(
                        version: version,
                        commonName: commonName,
                        organizationName: organizationName,
                        serialNumber: output.serialNumber,
                        createDate: output.createDate,
                        expirationDate: output.expirationDate,
                        certUrl: output.certUrl,
                        keyUrl: output.keyUrl,
                        signing: signing,
                        extensions: extensions,
                        algorithm: algorithm,
                        p12Info: p12Info
                    )
                    
                    try await storage.saveCertificate(certificate)
                    
                    Task { @MainActor in
                        certificates.insert(certificate, at: 0)
                        completion(.success)
                    }
                    
                } else {
                    let certificate = TLSCertificate(
                        version: version,
                        commonName: commonName,
                        organizationName: organizationName,
                        serialNumber: output.serialNumber,
                        createDate: output.createDate,
                        expirationDate: output.expirationDate,
                        certUrl: output.certUrl,
                        keyUrl: output.keyUrl,
                        signing: signing,
                        extensions: extensions,
                        algorithm: algorithm
                    )
                    
                    try await storage.saveCertificate(certificate)
                    
                    Task { @MainActor in
                        certificates.insert(certificate, at: 0)
                        completion(.success)
                    }
                }
                
            } catch let err {
                error("can't create certificate: \(err)")
                
                Task { @MainActor in
                    completion(.failed(err.localizedDescription))
                }
            }
        }
    }
    
    func createTemplate(
        name: String,
        version: TLSCertificate.Version,
        organizationName: String,
        lifetime: TimeInterval,
        extensions: TLSCertificate.Extensions,
        algorithm: TLSCertificate.SignatureAlgorithm,
        p12Password: String?,
        completion: @escaping (CreateCertificateResult) -> Void
    ) {
        Task {
            do {
                let template = TLSCertificateTemplate(
                    name: name,
                    version: version,
                    organizationName: organizationName,
                    lifetime: lifetime,
                    extensions: extensions,
                    algorithm: algorithm,
                    p12Info: p12Password.map { .required(p12Password: $0) } ?? .notRequired
                )
                
                try await storage.saveTemplate(template)
                
                Task { @MainActor in
                    templates.insert(template, at: 0)
                    completion(.success)
                }
                
            } catch let err {
                error("can't create template: \(err)")
                
                Task { @MainActor in
                    completion(.failed(err.localizedDescription))
                }
            }
        }
    }
    
    func deleteCertificate(_ cert: TLSCertificate) {
        Task {
            do {
                try await storage.deleteCertififcate(cert)
                
                try FileManager.default.removeItem(at: cert.certUrl)
                try FileManager.default.removeItem(at: cert.keyUrl)
                
                if let p12Info = cert.p12Info {
                    try FileManager.default.removeItem(at: p12Info.url)
                }
                
                guard let index = certificates.firstIndex(where: { $0.id == cert.id }) else {
                    return
                }
                
                Task { @MainActor in
                    certificates.remove(at: index)
                }
                
            } catch let err {
                error("can't delete certificate: \(err)")
            }
        }
    }
    
    func deleteTemplate(_ temp: TLSCertificateTemplate) {
        Task {
            do {
                try await storage.deleteTemplate(temp)
                
                guard let index = templates.firstIndex(where: { $0.id == temp.id }) else {
                    return
                }
                
                Task { @MainActor in
                    templates.remove(at: index)
                }
                
            } catch let err {
                error("can't delete template: \(err)")
            }
        }
    }
    
    func loadRepresentation(
        of cert: TLSCertificate,
        completion: @escaping (_ certificate: String?, _ privateKey: String?) -> Void
    ) {
        Task {
            let certificate = tlsService.loadCertificateRepresentation(url: cert.certUrl)
            let privateKey = tlsService.loadPrivateKeyRepresentation(url: cert.keyUrl)
            
            Task { @MainActor in
                completion(certificate, privateKey)
            }
        }
    }
    
    private func makeCertificateInputInfo(
        version: TLSCertificate.Version,
        commonName: String,
        organizationName: String,
        signing: TLSCertificate.Signing,
        lifetime: TimeInterval,
        extensions: TLSCertificate.Extensions,
        algorithm: TLSCertificate.SignatureAlgorithm
    ) throws -> CertificateInputInfo {
        switch signing {
        case .selfSigned:
            return CertificateInputInfo(
                version: version,
                commonName: commonName,
                organizationName: organizationName,
                signing: .selfSigned,
                lifetime: lifetime,
                extensions: extensions,
                algorithm: algorithm
            )
            
        case .signedByCA(_, let issuerName):
            let (issuerCert, privateKey) = try tlsService.loadCertificateWithPrivateKey(byName: issuerName)
            
            return CertificateInputInfo(
                version: version,
                commonName: commonName,
                organizationName: organizationName,
                signing: .signedByCA(issuerCert: issuerCert, privateKey: privateKey),
                lifetime: lifetime,
                extensions: extensions,
                algorithm: algorithm
            )
        }
    }
    
    private func log(_ message: String) {
        logger.log("ContentViewModel: \(message)")
    }
    
    private func error(_ message: String) {
        logger.error("ContentViewModel: \(message)")
    }
}

private extension TLSCertificate {
    var isCertificateAuthority: Bool {
        guard case .isCertificateAuthority(_) = extensions.basicConstraints else {
            return false
        }
        return true
    }
}
