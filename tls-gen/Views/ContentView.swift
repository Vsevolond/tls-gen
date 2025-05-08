//
//  ContentView.swift
//  tls-gen
//
//  Created by Всеволод Донченко on 11.04.2025.
//

import SwiftUI

struct ContentView: View {
    enum CertificatesSection: String, CaseIterable, Identifiable {
        case allCertificates = "All Certificates"
        case selfSignedCA = "Self-Signed CA"
        case intermediateCA = "Intermediate CA"
        case nonCACertificates = "Non-CA Certificates"
        case leafCertificates = "Leaf Certificates"
        case templates = "Templates"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .allCertificates: "square.stack.3d.up.fill"
            case .selfSignedCA: "shield.lefthalf.filled"
            case .intermediateCA: "shield.pattern.checkered"
            case .nonCACertificates: "shield.lefthalf.filled.slash"
            case .leafCertificates: "leaf.fill"
            case .templates: "list.bullet.rectangle.fill"
            }
        }
    }
    
    @StateObject private var model = ContentViewModel()
    
    @State private var currentSection: CertificatesSection = .allCertificates
    @State private var createCertificatePresented = false
    
    var body: some View {
        NavigationSplitView {
            List(CertificatesSection.allCases, selection: $currentSection) { section in
                NavigationLink(value: section) {
                    Label(section.rawValue, systemImage: section.icon)
                }
            }
            .listStyle(.sidebar)
            
        } content: {
            switch currentSection {
            case .allCertificates:
                certificatesList(certs: model.certificates)
                
            case .selfSignedCA:
                certificatesList(certs: model.selfSignedCertAuthorites)
                
            case .intermediateCA:
                certificatesList(certs: model.intermediateCertAuthorities)
                
            case .nonCACertificates:
                certificatesList(certs: model.nonCertAuthorities)
                
            case .leafCertificates:
                certificatesList(certs: model.leafCertificates)
                
            case .templates:
                templatesList(temps: model.templates)
            }
            
        } detail: {
            EmptyView()
        }
        .navigationTitle(currentSection.rawValue)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createCertificatePresented.toggle()
                    
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $createCertificatePresented) {
            switch currentSection {
            case .allCertificates:
                CertificateCreateView(model: model, type: .newCertificate)
                
            case .selfSignedCA:
                CertificateCreateView(
                    model: model,
                    type: .newCertificate,
                    basicConstraints: .isCertificateAuthority
                )
                
            case .intermediateCA:
                CertificateCreateView(
                    model: model,
                    type: .newCertificate,
                    signing: .signedByCA,
                    basicConstraints: .isCertificateAuthority
                )
                
            case .nonCACertificates:
                CertificateCreateView(
                    model: model,
                    type: .newCertificate,
                    signing: .signedByCA,
                    basicConstraints: .notCertificateAuthority
                )
                
            case .leafCertificates:
                CertificateCreateView(
                    model: model,
                    type: .newCertificate,
                    basicConstraints: .notCertificateAuthority
                )
                
            case .templates:
                CertificateCreateView(model: model, type: .newTemplate)
            }
        }
        .onAppear {
            model.loadCertificatesAndTemplates()
        }
    }
    
    private func certificatesList(certs: [TLSCertificate]) -> some View {
        List(certs, id: \.id) { cert in
            NavigationLink {
                CertificateView(cert: cert, model: model)
                    .id(cert.id)
                
            } label: {
                CertificateCellView(model: model, value: .certificate(cert))
            }
        }
    }
    
    private func templatesList(temps: [TLSCertificateTemplate]) -> some View {
        List(temps, id: \.id) { temp in
            CertificateCellView(model: model, value: .template(temp))
        }
    }
}

#Preview {
    ContentView()
}
