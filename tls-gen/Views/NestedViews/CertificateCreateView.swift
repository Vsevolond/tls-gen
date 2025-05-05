//
//  CertificateCreateView.swift
//  tls-gen
//
//  Created by Всеволод Донченко on 17.04.2025.
//

import SwiftUI
import Network

struct CertificateCreateView: View {
    enum Signing: String, CaseIterable, Identifiable {
        case selfSigned = "Self-Signed"
        case signedByCA = "Signed by CA"
        
        var id: String { rawValue }
    }
    
    enum BasicConstraints: String, CaseIterable, Identifiable {
        case isCertificateAuthority = "Is Certificate Authority"
        case notCertificateAuthority = "Not Certificate Authority"
        
        var id: String { rawValue }
    }
    
    enum MaxPathLength: String, CaseIterable, Identifiable {
        case limited = "Limited"
        case unlimited = "Unlimited"
        
        var id: String { rawValue }
    }
    
    enum SignatureAlgorithm: String, CaseIterable, Identifiable {
        case rsa = "RSA"
        case ecdsa = "ECDSA"
        case eddsaWithCurve25519 = "EdDSA with Curve25519"
        
        var id: String { rawValue }
    }
    
    @ObservedObject var model: ContentViewModel
    
    @State private var version: TLSCertificate.Version = .v3
    @State private var commonName = ""
    @State private var signing: Signing = .selfSigned
    @State private var certAuthority: TLSCertificate? = nil
    @State private var lifetime = TimeInterval.year
    
    @State private var basicConstraints: BasicConstraints = .notCertificateAuthority
    @State private var maxPathLength: MaxPathLength = .unlimited
    @State private var pathLength = 0
    
    @State private var includeKeyUsages = false
    @State private var keyUsages = Set<TLSCertificate.Extensions.KeyUsage>()
    
    @State private var includeExtendedKeyUsages = false
    @State private var extendedKeyUsages = Set<TLSCertificate.Extensions.ExtendedKeyUsage>()
    
    @State private var includeSubjectKeyIdentifier = false
    @State private var includeAuthorityKeyIdentifier = false
    
    @State private var subjectAlternativeNames = Set<TLSCertificate.Extensions.SubjectAlternativeName>()
    @State private var subjectAlternativeNamePresented = false
    
    @State private var signature: SignatureAlgorithm = .rsa
    @State private var keySize: TLSCertificate.SignatureAlgorithm.RSAKeySize = .bits2048
    @State private var hashFunction: TLSCertificate.SignatureAlgorithm.HashFunction = .sha256
    
    @State private var needP12Container = false
    @State private var p12Password = ""
    
    @State private var isCreating = false
    @State private var alertPresented = false
    @State private var alertText = ""
    
    @Environment(\.dismiss) private var dismiss
    
    private let availableLifetimes = (1...10).map { Double($0) * TimeInterval.year }
    
    private var createDisabled: Bool {
        isCreating
        || subjectAlternativeNamePresented
        || commonName.isEmpty
        || (signing == .signedByCA && certAuthority == nil)
        || (needP12Container && p12Password.isEmpty)
        || (includeKeyUsages && keyUsages.isEmpty)
        || (includeExtendedKeyUsages && extendedKeyUsages.isEmpty)
    }
    
    var body: some View {
        VStack {
            Form {
                versionPicker
                commonNameField
                
                VStack(spacing: 16) {
                    signingPicker
                    
                    if signing == .signedByCA {
                        Picker("Certificate Authority", selection: $certAuthority) {
                            ForEach(model.availableCertAuthorities, id: \.id) { authority in
                                Text(authority.commonName)
                                    .tag(authority)
                            }
                            .id(certAuthority?.id)
                        }
                    }
                }
                
                lifetimePicker
                algorithmPicker
                
                VStack(spacing: 16) {
                    makeP12Toggle
                    
                    if needP12Container {
                        p12PasswordField
                    }
                }
                
                
                Section("Extensions") {
                    VStack(spacing: 16) {
                        basicConstraintsPicker
                        
                        if basicConstraints == .isCertificateAuthority {
                            maxPathLengthPicker
                            
                            if maxPathLength == .limited {
                                pathLengthPicker
                            }
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        keyUsagesToggle
                        
                        if includeKeyUsages {
                            keyUsagesCheckList
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        extendedKeyUsagesToggle
                        
                        if includeExtendedKeyUsages {
                            extendedKeyUsagesCheckList
                        }
                    }
                    
                    subjectKeyIdentifierToggle
                    authorityKeyIdentifierToggle
                    
                    VStack(alignment: .leading) {
                        subjectAlternativeNameAddButton
                        subjectAlternativeNamesList
                    }
                }
            }
            .formStyle(.grouped)
            
            controlView
        }
        .sheet(isPresented: $subjectAlternativeNamePresented) {
            SANCreateView { subjectAlternativeName in
                subjectAlternativeNames.insert(subjectAlternativeName)
            }
        }
        .alert("Error", isPresented: $alertPresented, actions: {
            Button("OK", role: .cancel) {}
            
        }, message: {
            Text(alertText)
        })
        .padding()
    }
    
    private var versionPicker: some View {
        Picker("Version", selection: $version) {
            ForEach(TLSCertificate.Version.allCases, id: \.self) { certVersion in
                Text(certVersion.rawValue)
                    .tag(certVersion)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var commonNameField: some View {
        TextField("Common Name", text: $commonName)
            .textFieldStyle(.roundedBorder)
    }
    
    private var signingPicker: some View {
        Picker("Signing", selection: $signing) {
            ForEach(Signing.allCases) { type in
                Text(type.rawValue)
                    .tag(type)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var lifetimePicker: some View {
        Picker("Lifetime", selection: $lifetime) {
            ForEach(availableLifetimes, id: \.self) { time in
                let number = Int(time / TimeInterval.year)
                
                Text("\(number) \(number == 1 ? "year" : "years")")
                    .tag(time)
            }
        }
    }
    
    private var algorithmPicker: some View {
        VStack(spacing: 16) {
            Picker("Signature Algorithm", selection: $signature) {
                ForEach(SignatureAlgorithm.allCases) { algorithm in
                    Text(algorithm.rawValue)
                        .tag(algorithm)
                }
            }
            
            if signature == .rsa {
                Picker("Key Size", selection: $keySize) {
                    ForEach(TLSCertificate.SignatureAlgorithm.RSAKeySize.allCases, id: \.self) { size in
                        Text(size.description)
                            .tag(size)
                    }
                }
                
            }
            
            if signature == .rsa || signature == .ecdsa {
                Picker("Hash Function", selection: $hashFunction) {
                    ForEach(TLSCertificate.SignatureAlgorithm.HashFunction.allCases, id: \.self) { function in
                        Text(function.description)
                            .tag(function)
                    }
                }
            }
        }
    }
    
    private var makeP12Toggle: some View {
        Toggle("Make P12 Container", isOn: $needP12Container)
            .toggleStyle(.switch)
    }
    
    private var p12PasswordField: some View {
        TextField("P12 Password", text: $p12Password)
            .textFieldStyle(.roundedBorder)
    }
    
    private var basicConstraintsPicker: some View {
        Picker("Basic Constraints", selection: $basicConstraints) {
            ForEach(BasicConstraints.allCases) { constraints in
                Text(constraints.rawValue)
                    .tag(constraints)
            }
        }
    }
    
    private var maxPathLengthPicker: some View {
        Picker("Max Path Length", selection: $maxPathLength) {
            ForEach(MaxPathLength.allCases) { length in
                Text(length.rawValue)
                    .tag(length)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var pathLengthPicker: some View {
        Picker("Path Length", selection: $pathLength) {
            ForEach(0...10, id: \.self) { length in
                Text("\(length)")
                    .tag(length)
            }
        }
    }
    
    private var keyUsagesToggle: some View {
        Toggle("Key Usages", isOn: $includeKeyUsages)
            .toggleStyle(.switch)
    }
    
    private var keyUsagesCheckList: some View {
        ForEach(TLSCertificate.Extensions.KeyUsage.allCases, id: \.self) { usage in
            Toggle(
                usage.description,
                isOn: Binding<Bool>(
                    get: {
                        keyUsages.contains(usage)
                    },
                    set: { isOn in
                        if isOn {
                            keyUsages.insert(usage)
                            
                        } else {
                            keyUsages.remove(usage)
                        }
                    }
                )
            )
            .toggleStyle(.checkbox)
        }
    }
    
    private var extendedKeyUsagesToggle: some View {
        Toggle("Extended Key Usages", isOn: $includeExtendedKeyUsages)
            .toggleStyle(.switch)
    }
    
    private var extendedKeyUsagesCheckList: some View {
        ForEach(TLSCertificate.Extensions.ExtendedKeyUsage.allCases, id: \.self) { usage in
            Toggle(
                usage.description,
                isOn: Binding<Bool>(
                    get: {
                        extendedKeyUsages.contains(usage)
                    },
                    set: { isOn in
                        if isOn {
                            extendedKeyUsages.insert(usage)
                            
                        } else {
                            extendedKeyUsages.remove(usage)
                        }
                    }
                )
            )
            .toggleStyle(.checkbox)
        }
    }
    
    private var subjectKeyIdentifierToggle: some View {
        Toggle("Subject Key Identifier", isOn: $includeSubjectKeyIdentifier)
            .toggleStyle(.switch)
    }
    
    private var authorityKeyIdentifierToggle: some View {
        Toggle("Authority Key Identifier", isOn: $includeAuthorityKeyIdentifier)
            .toggleStyle(.switch)
    }
    
    private var subjectAlternativeNameAddButton: some View {
        LabeledContent("Subject Alternative Names") {
            Button {
                subjectAlternativeNamePresented.toggle()
                
            } label: {
                Image(systemName: "plus")
            }
        }
    }
    
    private var subjectAlternativeNamesList: some View {
        ForEach(Array(subjectAlternativeNames), id: \.self) { san in
            HStack {
                Button {
                    subjectAlternativeNames.remove(san)
                    
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                
                Text(san.description)
            }
            .padding(4)
        }
    }
    
    private var controlView: some View {
        HStack {
            Spacer()
            
            Button("Create") {
                isCreating = true
                
                let certSigning = makeCertificateSigning()
                let certBasicConstraints = makeBasicConstraints()
                
                let extensions = TLSCertificate.Extensions(
                    basicConstraints: certBasicConstraints,
                    keyUsages: keyUsages,
                    extendedKeyUsages: extendedKeyUsages,
                    subjectKeyIdentifierIncludes: includeSubjectKeyIdentifier,
                    authorityKeyIdentifierIncludes: includeAuthorityKeyIdentifier,
                    subjectAlternativeNames: subjectAlternativeNames
                )
                
                let algorithm = makeSignatureAlgorithm()
                let password = needP12Container ? p12Password : nil
                
                model.createCertificate(
                    version: version,
                    commonName: commonName,
                    signing: certSigning,
                    lifetime: lifetime,
                    extensions: extensions,
                    algorithm: algorithm,
                    p12Password: password
                ) { result in
                    switch result {
                    case .success:
                        dismiss()
                        
                    case .failed(let error):
                        alertText = error
                        alertPresented.toggle()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(createDisabled)
            .keyboardShortcut(.defaultAction)
            .popover(isPresented: $isCreating) {
                ProgressView()
            }
            
            Button("Cancel") {
                dismiss()
            }
        }
        .padding(.trailing)
    }
    
    private func makeCertificateSigning() -> TLSCertificate.Signing {
        switch signing {
        case .selfSigned:
            return .selfSigned
            
        case .signedByCA:
            guard let certAuthority else { return .selfSigned }
            return .signedByCA(issuerId: certAuthority.id, issuerName: certAuthority.commonName)
        }
    }
    
    private func makeBasicConstraints() -> TLSCertificate.Extensions.BasicConstraints {
        switch basicConstraints {
        case .isCertificateAuthority:
            if maxPathLength == .unlimited {
                return .isCertificateAuthority(maxPathLength: .unlimited)
                
            } else {
                return .isCertificateAuthority(maxPathLength: .limited(count: pathLength))
            }
            
        case .notCertificateAuthority:
            return .notCertificateAuthority
        }
    }
    
    private func makeSignatureAlgorithm() -> TLSCertificate.SignatureAlgorithm {
        switch signature {
        case .rsa:
            return .rsa(keySize, hashFunction)
            
        case .ecdsa:
            return .ecdsa(hashFunction)
            
        case .eddsaWithCurve25519:
            return .eddsaWithCurve25519
        }
    }
}

private struct SANCreateView: View {
    enum SANType: String, CaseIterable, Identifiable {
        case dnsName = "DNS Name"
        case ipAddress = "IP Address"
        
        var id: String { rawValue }
    }
    
    var completion: (TLSCertificate.Extensions.SubjectAlternativeName) -> Void
    
    @State private var sanType: SANType = .dnsName
    @State private var text = ""
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Form {
                Picker("SAN Type", selection: $sanType) {
                    ForEach(SANType.allCases) { type in
                        Text(type.rawValue)
                            .tag(type)
                    }
                }
                
                TextField(sanType.rawValue, text: $text)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Spacer()
                
                Button("Add") {
                    switch sanType {
                    case .dnsName:
                        completion(.dnsName(text))
                        
                    case .ipAddress:
                        guard let ipv4 = IPv4Address(text) else { return }
                        completion(.ipAddress(ipv4))
                    }
                    
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(text.isEmpty)
                
                Button("Cancel") {
                    dismiss()
                }
            }
            .padding(.top)
        }
        .padding()
    }
}

private extension TLSCertificate.Extensions.KeyUsage {
    var description: String {
        return switch self {
        case .digitalSignature: "Digital Signature"
        case .keyEncipherment: "Key Encipherment"
        case .keyAgreement: "Key Agreement"
        case .keyCertSign: "Key Cert Sign"
        case .cRLSign: "CRL Sign"
        }
    }
}

private extension TLSCertificate.Extensions.ExtendedKeyUsage {
    var description: String {
        return switch self {
        case .serverAuth: "Server Auth"
        case .clientAuth: "Client Auth"
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

private extension TLSCertificate.SignatureAlgorithm.HashFunction {
    var description: String {
        return switch self {
        case .sha256: "SHA 256"
        case .sha384: "SHA 384"
        case .sha512: "SHA 512"
        }
    }
}

private extension TLSCertificate.Extensions.SubjectAlternativeName {
    var description: String {
        return switch self {
        case .dnsName(let dns): "DNS: \(dns)"
        case .ipAddress(let ipv4): "IP: \(ipv4.debugDescription)"
        }
    }
}
