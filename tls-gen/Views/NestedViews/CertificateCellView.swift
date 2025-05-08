//
//  CertificateCellView.swift
//  tls-gen
//
//  Created by Всеволод Донченко on 17.04.2025.
//

import SwiftUI

struct CertificateCellView: View {
    enum CellValue: Equatable {
        case certificate(TLSCertificate)
        case template(TLSCertificateTemplate)
    }
    
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
    
    @ObservedObject var model: ContentViewModel
    let value: CellValue
    
    @State private var downloadPresented = false
    @State private var downloadFile: DownloadUrl = .none
    
    @State private var createCertificatePresented = false
    @State private var alertPresented = false
    
    var body: some View {
        VStack(alignment: .leading) {
            headerView
            
            HStack {
                descriptionView
                
                Spacer()
                
                controlView
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
                switch value {
                case .certificate(let cert):
                    model.deleteCertificate(cert)
                    
                case .template(let temp):
                    model.deleteTemplate(temp)
                }
            }
            .keyboardShortcut(.defaultAction)
            
            Button("Cancel", role: .cancel) {}
            
        } message: {
            switch value {
            case .certificate(let cert):
                Text("Do you want to delete `\(cert.commonName)` certificate?")
                
            case .template(let temp):
                Text("Do you want to delete `\(temp.name)` template?")
            }
        }
        .sheet(isPresented: $createCertificatePresented) {
            switch value {
            case .certificate:
                EmptyView()
                
            case .template(let temp):
                CertificateCreateView(model: model, type: .templateCertificate(temp))
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            switch value {
            case .certificate(let cert):
                certificateTitle(cert.commonName, signing: cert.signing)
                
            case .template(let temp):
                templateTitle(temp.name)
            }
            
            Spacer()
            
            deleteButton
        }
    }
    
    private var descriptionView: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch value {
            case .certificate(let cert):
                organizationNameText(cert.organizationName)
                createDateText(cert.createDate)
                validDateText(cert.expirationDate)
                signatureAlgorithmText(cert.algorithm)
                extensionsView(cert.extensions)
                
                if let info = cert.p12Info {
                    p12PasswordView(info.password)
                }
                
            case .template(let temp):
                organizationNameText(temp.organizationName)
                signatureAlgorithmText(temp.algorithm)
                extensionsView(temp.extensions)
                
                if case .required(let password) = temp.p12Info {
                    p12PasswordView(password)
                }
            }
        }
    }
    
    @ViewBuilder
    private var controlView: some View {
        switch value {
        case .certificate(let cert):
            downloadView(certUrl: cert.certUrl, keyUrl: cert.keyUrl, p12Url: cert.p12Info?.url)
            
        case .template:
            makeCertificateButton
        }
    }
    
    private func downloadView(certUrl: URL, keyUrl: URL, p12Url: URL?) -> some View {
        VStack {
            HStack {
                downloadButton(
                    .cert(url: certUrl),
                    title: ".crt",
                    image: "checkmark.seal.fill",
                    color: .green
                )
                
                downloadButton(
                    .key(url: keyUrl),
                    title: ".key",
                    image: "key.fill",
                    color: .yellow
                )
            }
            
            if let p12Url {
                downloadButton(
                    .p12(url: p12Url),
                    title: ".p12",
                    image: "shippingbox.fill",
                    color: .mint
                )
            }
        }
        .padding(.trailing)
    }
    
    private var makeCertificateButton: some View {
        Button("Make Certificate") {
            createCertificatePresented.toggle()
        }
    }
    
    private func certificateTitle(
        _ commonName: String,
        signing: TLSCertificate.Signing
    ) -> some View {
        Text(commonName + "  ")
            .font(.title2)
            .bold()
        + Text(signing.description)
            .font(.callout)
            .foregroundStyle(.gray)
    }
    
    private func templateTitle(_ name: String) -> some View {
        Text(name)
            .font(.title2)
            .bold()
    }
    
    private func organizationNameText(_ name: String) -> some View {
        Text("Organization Name: ")
            .font(.subheadline)
            .foregroundStyle(.gray)
        + Text(name)
            .font(.subheadline)
            .bold()
    }
    
    private var deleteButton: some View {
        Button {
            alertPresented = true
            
        } label: {
            Label("Delete", systemImage: "trash.fill")
                .foregroundStyle(.red.opacity(0.8))
        }
        .buttonStyle(.accessoryBar)
        .padding(.trailing)
    }
    
    private func createDateText(_ date: Date) -> some View {
        Text("Created: ")
            .font(.subheadline)
            .foregroundStyle(.gray)
        + Text(date.medium)
            .font(.subheadline)
            .bold()
    }
    
    private func validDateText(_ date: Date) -> some View {
        Text("Valid: ")
            .font(.subheadline)
            .foregroundStyle(.gray)
        + Text(date.medium)
            .font(.subheadline)
            .bold()
    }
    
    private func signatureAlgorithmText(
        _ algorithm: TLSCertificate.SignatureAlgorithm
    ) -> some View {
        Text("Signature Algorithm: ")
            .font(.subheadline)
            .foregroundStyle(.gray)
        + Text(algorithm.description)
            .font(.subheadline)
            .bold()
    }
    
    private func basicConstraintsText(
        _ basicConstraints: TLSCertificate.Extensions.BasicConstraints
    ) -> some View {
        Text("Basic Constraints: ")
            .font(.subheadline)
            .foregroundStyle(.gray)
        + Text(basicConstraints.description)
            .font(.subheadline)
            .bold()
    }
    
    private func extensionsView(_ extensions: TLSCertificate.Extensions) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            basicConstraintsText(extensions.basicConstraints)
            
            if !extensions.keyUsages.isEmpty {
                keyUsagesText(extensions.keyUsages)
            }

            if !extensions.extendedKeyUsages.isEmpty {
                extendedKeyUsagesText(extensions.extendedKeyUsages)
            }
            
            if extensions.subjectKeyIdentifierIncludes {
                subjectKeyIdentifierText
            }
            
            if extensions.authorityKeyIdentifierIncludes {
                authorityKeyIdentifierText
            }
            
            if !extensions.subjectAlternativeNames.isEmpty {
                subjectAlternativeNamesText(extensions.subjectAlternativeNames)
            }
        }
    }
    
    private func keyUsagesText(
        _ keyUsages: Set<TLSCertificate.Extensions.KeyUsage>
    ) -> some View {
        Text("Key Usage: ")
            .font(.subheadline)
            .foregroundStyle(.gray)
        + Text(keyUsages.description)
            .font(.subheadline)
            .bold()
    }
    
    private func extendedKeyUsagesText(
        _ extendedKeyUsages: Set<TLSCertificate.Extensions.ExtendedKeyUsage>
    ) -> some View {
        Text("Extended Key Usage: ")
            .font(.subheadline)
            .foregroundStyle(.gray)
        + Text(extendedKeyUsages.description)
            .font(.subheadline)
            .bold()
    }
    
    private var subjectKeyIdentifierText: some View {
        Text("Subject Key Identifier ☑️")
            .font(.subheadline)
            .foregroundStyle(.gray)
    }
    
    private var authorityKeyIdentifierText: some View {
        Text("Authority Key Identifier ☑️")
            .font(.subheadline)
            .foregroundStyle(.gray)
    }
    
    private func subjectAlternativeNamesText(
        _ subjectAlternativeNames: Set<TLSCertificate.Extensions.SubjectAlternativeName>
    ) -> some View {
        Text("Subject Alternative Names: ")
            .font(.subheadline)
            .foregroundStyle(.gray)
        + Text(subjectAlternativeNames.description)
            .font(.subheadline)
            .bold()
    }
    
    private func p12PasswordView(_ password: String) -> some View {
        HStack {
            Text("P12 Password: ")
                .font(.subheadline)
                .foregroundStyle(.gray)
            + Text(String(repeating: "•", count: password.count))
            
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(password, forType: .string)
                
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
    
    private func downloadButton(
        _ url: DownloadUrl,
        title: String,
        image: String,
        color: Color
    ) -> some View {
        Button {
            downloadFile = url
            downloadPresented = true
            
        } label: {
            Label {
                Text(title)
                
            } icon: {
                Image(systemName: image)
                    .foregroundStyle(color)
            }
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

private extension TLSCertificate.SignatureAlgorithm {
    var description: String {
        switch self {
        case let .rsa(keySize, hashFunction):
            return "RSA \(keySize.description) with \(hashFunction.description)"
            
        case let .ecdsa(hashFunction):
            return "ECDSA with \(hashFunction.description)"
            
        case .eddsaWithCurve25519:
            return "EdDSA with Curve25519"
        }
    }
}

private extension TLSCertificate.SignatureAlgorithm.HashFunction {
    var description: String {
        return switch self {
        case .sha256: "SHA 256"
        case .sha384: "SHA 384"
        case .sha512: "SHA 512"
        }
    }
}

private extension TLSCertificate.SignatureAlgorithm.RSAKeySize {
    var description: String {
        return switch self {
        case .bits2048: "2048 bits"
        case .bits3072: "3072 bits"
        case .bits4096: "4096 bits"
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
