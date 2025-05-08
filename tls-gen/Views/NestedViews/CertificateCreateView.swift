//
//  CertificateCreateView.swift
//  tls-gen
//
//  Created by Всеволод Донченко on 17.04.2025.
//

import SwiftUI
import Network

struct CertificateCreateView: View {
    enum CreateType: Equatable {
        case newCertificate
        case newTemplate
        case templateCertificate(TLSCertificateTemplate)
    }
    
    @ObservedObject private var model: ContentViewModel
    private let type: CreateType
    
    @State private var version: TLSCertificate.Version
    @State private var commonName = ""
    @State private var organizationName: String
    @State private var signing: Signing
    @State private var certAuthority: TLSCertificate? = nil
    @State private var lifetime: TimeInterval
    
    @State private var basicConstraints: BasicConstraints
    @State private var maxPathLength: BasicConstraints.MaxPathLength
    @State private var pathLength: Int
    
    @State private var includeKeyUsages: Bool
    @State private var keyUsages: Set<TLSCertificate.Extensions.KeyUsage>
    
    @State private var includeExtendedKeyUsages: Bool
    @State private var extendedKeyUsages: Set<TLSCertificate.Extensions.ExtendedKeyUsage>
    
    @State private var includeSubjectKeyIdentifier: Bool
    @State private var includeAuthorityKeyIdentifier: Bool
    
    @State private var subjectAlternativeNames: Set<TLSCertificate.Extensions.SubjectAlternativeName>
    @State private var subjectAlternativeNamePresented: Bool = false
    
    @State private var signature: SignatureAlgorithm
    @State private var keySize: TLSCertificate.SignatureAlgorithm.RSAKeySize
    @State private var hashFunction: TLSCertificate.SignatureAlgorithm.HashFunction
    
    @State private var p12Required: Bool
    @State private var p12Password: String
    
    @State private var isCreating = false
    @State private var alertPresented = false
    @State private var alertText: String? = nil
    
    @State private var editingDisabled: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    private let availableLifetimes = (1...10).map { Double($0) * TimeInterval.year }
    
    private var createDisabled: Bool {
        isCreating
        || subjectAlternativeNamePresented
        || (type != .newTemplate && commonName.isEmpty)
        || organizationName.isEmpty
        || (signing == .signedByCA && certAuthority == nil)
        || (p12Required && p12Password.isEmpty)
        || (includeKeyUsages && keyUsages.isEmpty)
        || (includeExtendedKeyUsages && extendedKeyUsages.isEmpty)
    }
    
    init(
        model: ContentViewModel,
        type: CreateType,
        signing: Signing = .selfSigned,
        basicConstraints: BasicConstraints = .notCertificateAuthority
    ) {
        switch type {
        case .newCertificate:
            self.init(type: type, model: model, signing: signing, basicConstraints: basicConstraints)
            
        case .newTemplate:
            self.init(type: type, model: model)
            
        case .templateCertificate(let template):
            self.init(
                type: type,
                model: model,
                version: template.version,
                organizationName: template.organizationName,
                lifetime: template.lifetime,
                basicConstraints: BasicConstraints.from(template.extensions.basicConstraints),
                maxPathLength: BasicConstraints.MaxPathLength.from(template.extensions.basicConstraints),
                pathLength: template.extensions.basicConstraints.pathLength ?? 0,
                includeKeyUsages: !template.extensions.keyUsages.isEmpty,
                keyUsages: template.extensions.keyUsages,
                includeExtendedKeyUsages: !template.extensions.extendedKeyUsages.isEmpty,
                extendedKeyUsages: template.extensions.extendedKeyUsages,
                includeSubjectKeyIdentifier: template.extensions.subjectKeyIdentifierIncludes,
                includeAuthorityKeyIdentifier: template.extensions.authorityKeyIdentifierIncludes,
                subjectAlternativeNames: template.extensions.subjectAlternativeNames,
                signature: SignatureAlgorithm.from(template.algorithm),
                keySize: template.algorithm.keySize ?? .bits2048,
                hashFunction: template.algorithm.hashFunction ?? .sha256,
                p12Required: template.p12Info.isRequired,
                p12Password: template.p12Info.password ?? "",
                editingDisabled: true
            )
        }
    }
    
    var body: some View {
        VStack {
            if case .templateCertificate = type {
                editingButton
            }
            
            Form {
                if case .newTemplate = type {
                    templateNameField
                }
                
                versionPicker
                
                if case .newTemplate = type {
                    organizationNameField
                    
                } else {
                    VStack(spacing: 16) {
                        commonNameField
                        organizationNameField
                    }
                    
                    VStack(spacing: 16) {
                        signingPicker
                        
                        if signing == .signedByCA {
                            certAuthorityPicker
                        }
                    }
                }
                
                lifetimePicker
                algorithmPicker
                
                VStack(spacing: 16) {
                    p12RequirementToggle
                    
                    if p12Required {
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
            Button("OK", role: .cancel) {
                alertText = nil
            }
            
        }, message: {
            Text(alertText ?? "Unknown")
        })
        .padding()
    }
    
    private var editingButton: some View {
        HStack {
            Spacer()
            
            Button {
                editingDisabled.toggle()
                
            } label: {
                Image(systemName: editingDisabled ? "lock.fill" : "lock.open")
            }
            .buttonStyle(.plain)
        }
    }
    
    private var versionPicker: some View {
        Picker("Version", selection: $version) {
            ForEach(TLSCertificate.Version.allCases, id: \.self) { certVersion in
                Text(certVersion.rawValue)
                    .tag(certVersion)
            }
        }
        .pickerStyle(.segmented)
        .disabled(editingDisabled)
    }
    
    private var commonNameField: some View {
        TextField("Common Name", text: $commonName)
            .textFieldStyle(.roundedBorder)
    }
    
    private var templateNameField: some View {
        TextField("Template Name", text: $commonName)
            .textFieldStyle(.roundedBorder)
    }
    
    private var organizationNameField: some View {
        TextField("Organization Name", text: $organizationName)
            .textFieldStyle(.roundedBorder)
            .disabled(editingDisabled)
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
    
    private var certAuthorityPicker: some View {
        Picker("Certificate Authority", selection: $certAuthority) {
            ForEach(model.availableCertAuthorities, id: \.id) { authority in
                Text(authority.commonName)
                    .tag(authority)
            }
            .id(certAuthority?.id)
        }
    }
    
    private var lifetimePicker: some View {
        Picker("Lifetime", selection: $lifetime) {
            ForEach(availableLifetimes, id: \.self) { time in
                let number = Int(time / TimeInterval.year)
                
                Text("\(number) \(number == 1 ? "year" : "years")")
                    .tag(time)
            }
        }
        .disabled(editingDisabled)
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
        .disabled(editingDisabled)
    }
    
    private var p12RequirementToggle: some View {
        Toggle("Make P12 Container", isOn: $p12Required)
            .toggleStyle(.switch)
            .disabled(editingDisabled)
    }
    
    private var p12PasswordField: some View {
        TextField("P12 Password", text: $p12Password)
            .textFieldStyle(.roundedBorder)
            .disabled(editingDisabled)
    }
    
    private var basicConstraintsPicker: some View {
        Picker("Basic Constraints", selection: $basicConstraints) {
            ForEach(BasicConstraints.allCases) { constraints in
                Text(constraints.rawValue)
                    .tag(constraints)
            }
        }
        .disabled(editingDisabled)
    }
    
    private var maxPathLengthPicker: some View {
        Picker("Max Path Length", selection: $maxPathLength) {
            ForEach(BasicConstraints.MaxPathLength.allCases) { length in
                Text(length.rawValue)
                    .tag(length)
            }
        }
        .pickerStyle(.segmented)
        .disabled(editingDisabled)
    }
    
    private var pathLengthPicker: some View {
        Picker("Path Length", selection: $pathLength) {
            ForEach(0...10, id: \.self) { length in
                Text("\(length)")
                    .tag(length)
            }
        }
        .disabled(editingDisabled)
    }
    
    private var keyUsagesToggle: some View {
        Toggle("Key Usages", isOn: $includeKeyUsages)
            .toggleStyle(.switch)
            .disabled(editingDisabled)
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
        .disabled(editingDisabled)
    }
    
    private var extendedKeyUsagesToggle: some View {
        Toggle("Extended Key Usages", isOn: $includeExtendedKeyUsages)
            .toggleStyle(.switch)
            .disabled(editingDisabled)
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
        .disabled(editingDisabled)
    }
    
    private var subjectKeyIdentifierToggle: some View {
        Toggle("Subject Key Identifier", isOn: $includeSubjectKeyIdentifier)
            .toggleStyle(.switch)
            .disabled(editingDisabled)
    }
    
    private var authorityKeyIdentifierToggle: some View {
        Toggle("Authority Key Identifier", isOn: $includeAuthorityKeyIdentifier)
            .toggleStyle(.switch)
            .disabled(editingDisabled)
    }
    
    private var subjectAlternativeNameAddButton: some View {
        LabeledContent("Subject Alternative Names") {
            Button {
                subjectAlternativeNamePresented.toggle()
                
            } label: {
                Image(systemName: "plus")
            }
        }
        .disabled(editingDisabled)
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
        .disabled(editingDisabled)
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
                let password = p12Required ? p12Password : nil
                
                if case .newTemplate = type {
                    model.createTemplate(
                        name: commonName,
                        version: version,
                        organizationName: organizationName,
                        lifetime: lifetime,
                        extensions: extensions,
                        algorithm: algorithm,
                        p12Password: password) { result in
                            handleResult(result)
                        }
                    
                } else {
                    model.createCertificate(
                        version: version,
                        commonName: commonName,
                        organizationName: organizationName,
                        signing: certSigning,
                        lifetime: lifetime,
                        extensions: extensions,
                        algorithm: algorithm,
                        p12Password: password
                    ) { result in
                        handleResult(result)
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
    
    private func handleResult(_ result: CreateCertificateResult) {
        switch result {
        case .success:
            dismiss()
            
        case .failed(let error):
            alertText = error
            alertPresented.toggle()
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

extension CertificateCreateView {
    enum Signing: String, CaseIterable, Identifiable {
        case selfSigned = "Self-Signed"
        case signedByCA = "Signed by CA"
        
        var id: String { rawValue }
    }
    
    enum BasicConstraints: String, CaseIterable, Identifiable {
        fileprivate enum MaxPathLength: String, CaseIterable, Identifiable {
            case limited = "Limited"
            case unlimited = "Unlimited"
            
            var id: String { rawValue }
        }
        
        case isCertificateAuthority = "Is Certificate Authority"
        case notCertificateAuthority = "Not Certificate Authority"
        
        var id: String { rawValue }
    }
    
    fileprivate enum SignatureAlgorithm: String, CaseIterable, Identifiable {
        case rsa = "RSA"
        case ecdsa = "ECDSA"
        case eddsaWithCurve25519 = "EdDSA with Curve25519"
        
        var id: String { rawValue }
    }
    
    private init(
        type: CreateType,
        model: ContentViewModel,
        version: TLSCertificate.Version = .v3,
        organizationName: String = "",
        signing: Signing = .selfSigned,
        lifetime: TimeInterval = .year,
        basicConstraints: BasicConstraints = .notCertificateAuthority,
        maxPathLength: BasicConstraints.MaxPathLength = .unlimited,
        pathLength: Int = 0,
        includeKeyUsages: Bool = false,
        keyUsages: Set<TLSCertificate.Extensions.KeyUsage> = .init(),
        includeExtendedKeyUsages: Bool = false,
        extendedKeyUsages: Set<TLSCertificate.Extensions.ExtendedKeyUsage> = .init(),
        includeSubjectKeyIdentifier: Bool = false,
        includeAuthorityKeyIdentifier: Bool = false,
        subjectAlternativeNames: Set<TLSCertificate.Extensions.SubjectAlternativeName> = .init(),
        signature: SignatureAlgorithm = .rsa,
        keySize: TLSCertificate.SignatureAlgorithm.RSAKeySize = .bits2048,
        hashFunction: TLSCertificate.SignatureAlgorithm.HashFunction = .sha256,
        p12Required: Bool = false,
        p12Password: String = "",
        editingDisabled: Bool = false
    ) {
        self.model = model
        self.type = type
        self.version = version
        self.organizationName = organizationName
        self.signing = signing
        self.lifetime = lifetime
        self.basicConstraints = basicConstraints
        self.maxPathLength = maxPathLength
        self.pathLength = pathLength
        self.includeKeyUsages = includeKeyUsages
        self.keyUsages = keyUsages
        self.includeExtendedKeyUsages = includeExtendedKeyUsages
        self.extendedKeyUsages = extendedKeyUsages
        self.includeSubjectKeyIdentifier = includeSubjectKeyIdentifier
        self.includeAuthorityKeyIdentifier = includeAuthorityKeyIdentifier
        self.subjectAlternativeNames = subjectAlternativeNames
        self.signature = signature
        self.keySize = keySize
        self.hashFunction = hashFunction
        self.p12Required = p12Required
        self.p12Password = p12Password
        self.editingDisabled = editingDisabled
    }
}

private extension CertificateCreateView.BasicConstraints {
    static func from(_ basicConstraints: TLSCertificate.Extensions.BasicConstraints) -> Self {
        return switch basicConstraints {
        case .isCertificateAuthority: .isCertificateAuthority
        case .notCertificateAuthority: .notCertificateAuthority
        }
    }
}

private extension CertificateCreateView.BasicConstraints.MaxPathLength {
    static func from(_ basicConstraints: TLSCertificate.Extensions.BasicConstraints) -> Self {
        switch basicConstraints {
        case .isCertificateAuthority(let maxPathLength):
            return switch maxPathLength {
            case .limited: .limited
            case .unlimited: .unlimited
            }
            
        case .notCertificateAuthority:
            return .unlimited
        }
    }
}

private extension TLSCertificate.Extensions.BasicConstraints {
    var pathLength: Int? {
        switch self {
        case .isCertificateAuthority(let maxPathLength):
            switch maxPathLength {
            case .limited(let count):
                return count
                
            case .unlimited:
                return nil
            }
            
        case .notCertificateAuthority:
            return nil
        }
    }
}

private extension CertificateCreateView.SignatureAlgorithm {
    static func from(_ algorithm: TLSCertificate.SignatureAlgorithm) -> Self {
        return switch algorithm {
        case .ecdsa: .ecdsa
        case .rsa: .rsa
        case .eddsaWithCurve25519: .eddsaWithCurve25519
        }
    }
}

private extension TLSCertificate.SignatureAlgorithm {
    var keySize: RSAKeySize? {
        switch self {
        case .rsa(let keySize, _):
            return keySize
            
        case .eddsaWithCurve25519, .ecdsa:
            return nil
        }
    }
    
    var hashFunction: HashFunction? {
        switch self {
        case .ecdsa(let hashFunction), .rsa(_, let hashFunction):
            return hashFunction
            
        case .eddsaWithCurve25519:
            return nil
        }
    }
}

private extension TLSCertificateTemplate.P12Info {
    var isRequired: Bool {
        return switch self {
        case .notRequired: false
        case .required: true
        }
    }
    
    var password: String? {
        switch self {
        case .notRequired:
            return nil
            
        case .required(let password):
            return password
        }
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
