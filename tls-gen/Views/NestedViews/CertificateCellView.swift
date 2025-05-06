//
//  CertificateCellView.swift
//  tls-gen
//
//  Created by Всеволод Донченко on 17.04.2025.
//

import SwiftUI

struct CertificateCellView: View {
    enum DownloadUrl: Equatable {
        case none
        case cert(url: URL)
        case key(url: URL)
        case p12(url: URL)
        
        var url: URL {
            switch self {
            case .none: URL(fileURLWithPath: "")
            case .cert(let url), .key(let url), .p12(let url): url
            }
        }
    }
    
    let cert: TLSCertificate
    @ObservedObject var model: ContentViewModel
    
    @State private var downloadPresented = false
    @State private var downloadFile: DownloadUrl = .none
    
    @State private var alertPresented = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(cert.commonName + "  ")
                    .font(.title2)
                    .bold()
                + Text(cert.signing.description)
                    .font(.callout)
                    .foregroundStyle(.gray)
                
                Spacer()
                
                Button {
                    alertPresented = true
                    
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.accessoryBar)
                .padding(.trailing)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Created: ")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    + Text(cert.createDate.medium)
                        .font(.subheadline)
                        .bold()
                    
                    Text("Valid: ")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    + Text(cert.expirationDate.medium)
                        .font(.subheadline)
                        .bold()
                    
                    Text("Basic Constraints: ")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    + Text(cert.extensions.basicConstraints.description)
                        .font(.subheadline)
                        .bold()
                    
                    if !cert.extensions.keyUsages.isEmpty {
                        Text("Key Usage: ")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        + Text(cert.extensions.keyUsages.description)
                            .font(.subheadline)
                            .bold()
                    }
                    
                    if !cert.extensions.extendedKeyUsages.isEmpty {
                        Text("Extended Key Usage: ")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        + Text(cert.extensions.extendedKeyUsages.description)
                            .font(.subheadline)
                            .bold()
                    }
                    
                    if cert.extensions.subjectKeyIdentifierIncludes {
                        Text("Subject Key Identifier ☑️")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    
                    if cert.extensions.authorityKeyIdentifierIncludes {
                        Text("Authority Key Identifier ☑️")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    
                    if !cert.extensions.subjectAlternativeNames.isEmpty {
                        Text("Subject Alternative Names: ")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        + Text(cert.extensions.subjectAlternativeNames.description)
                            .font(.subheadline)
                            .bold()
                    }
                    
                    if let p12Info = cert.p12Info {
                        HStack {
                            Text("P12 Password: ")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            + Text(String(repeating: "•", count: p12Info.password.count))
                            
                            Button {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(p12Info.password, forType: .string)
                                
                            } label: {
                                HStack(alignment: .center, spacing: 2) {
                                    Image(systemName: "square.on.square.dashed")
                                        .imageScale(.small)
                                    
                                    Text("Copy")
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                VStack {
                    HStack {
                        Button {
                            downloadFile = .cert(url: cert.certUrl)
                            downloadPresented = true
                            
                        } label: {
                            Label {
                                Text(".crt")
                                
                            } icon: {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        
                        Button {
                            downloadFile = .key(url: cert.keyUrl)
                            downloadPresented = true
                            
                        } label: {
                            Label {
                                Text(".key")
                                
                            } icon: {
                                Image(systemName: "key.fill")
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                    
                    if let p12Info = cert.p12Info {
                        Button {
                            downloadFile = .p12(url: p12Info.url)
                            downloadPresented = true
                            
                        } label: {
                            Label {
                                Text(".p12")
                                
                            } icon: {
                                Image(systemName: "shippingbox.fill")
                                    .foregroundStyle(.mint)
                            }
                            
                        }
                    }
                }
                .padding(.trailing)
            }
        }
        .padding(.vertical)
        .fileExporter(
            isPresented: $downloadPresented,
            document: URLDocument(url: downloadFile.url),
            contentType: .fileURL,
            defaultFilename: downloadFile.url.lastPathComponent
        ) { result in
            switch result {
            case .success(let url):
                print("File saved to url: \(url.absoluteString)")
                
            case .failure(let error):
                print("Failed to save file: \(error)")
            }
        }
        .alert("Warning", isPresented: $alertPresented) {
            Button("Delete", role: .destructive) {
                model.deleteCertificate(cert)
            }
            .keyboardShortcut(.defaultAction)
            
            Button("Cancel", role: .cancel) {}
            
        } message: {
            Text("Do you want to delete `\(cert.commonName)` certificate?")
        }

    }
}

private extension TLSCertificate.Signing {
    var description: String {
        switch self {
        case .selfSigned:
            return "Self-Signed CA"
        case .signedByCA(_, let name):
            return "Signed by `\(name)`"
        }
    }
}

private extension TLSCertificate.Extensions.BasicConstraints {
    var description: String {
        switch self {
        case .isCertificateAuthority(let maxPathLength):
            switch maxPathLength {
            case .limited(let count):
                return "CA = true, pathlen = \(count)"
                
            case .unlimited:
                return "CA = true"
            }
            
        case .notCertificateAuthority:
            return "CA = false"
        }
    }
}

private extension Set where Element == TLSCertificate.Extensions.KeyUsage {
    var description: String {
        let array = Array(self).sorted(by: { $0.rawValue < $1.rawValue }).map { $0.description }
        return array.joined(separator: ", ")
    }
}

private extension Set where Element == TLSCertificate.Extensions.ExtendedKeyUsage {
    var description: String {
        let array = Array(self).sorted(by: { $0.rawValue < $1.rawValue }).map { $0.description }
        return array.joined(separator: ", ")
    }
}

private extension Set where Element == TLSCertificate.Extensions.SubjectAlternativeName {
    var description: String {
        let array = Array(self).map { $0.description }
        return array.joined(separator: ", ")
    }
}

private extension TLSCertificate.Extensions.KeyUsage {
    var description: String {
        return switch self {
        case .digitalSignature: "digital_signature"
        case .keyEncipherment: "key_encipherment"
        case .keyAgreement: "key_agreement"
        case .keyCertSign: "key_cert_sign"
        case .cRLSign: "cRL_sign"
        }
    }
}

private extension TLSCertificate.Extensions.ExtendedKeyUsage {
    var description: String {
        return switch self {
        case .serverAuth: "server_auth"
        case .clientAuth: "client_auth"
        }
    }
}

private extension TLSCertificate.Extensions.SubjectAlternativeName {
    var description: String {
        return switch self {
        case .dnsName(let dns): "DNS - \(dns)"
        case .ipAddress(let ipv4): "IP - \(ipv4.debugDescription)"
        }
    }
}

private extension Date {
    var medium: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }
}
