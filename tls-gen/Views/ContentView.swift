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
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .allCertificates: "square.stack.3d.up.fill"
            case .selfSignedCA: "shield.lefthalf.filled"
            case .intermediateCA: "shield.pattern.checkered"
            case .nonCACertificates: "shield.lefthalf.filled.slash"
            case .leafCertificates: "leaf.fill"
            }
        }
    }
    
    @StateObject private var model = ContentViewModel()
    
    @State private var currentSection: CertificatesSection = .allCertificates
    @State private var createCertPresented = false
    
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
                certificatesList(certs: model.certs)
                
            case .selfSignedCA:
                certificatesList(certs: model.selfSignedCertAuthorites)
                
            case .intermediateCA:
                certificatesList(certs: model.intermediateCertAuthorities)
                
            case .nonCACertificates:
                certificatesList(certs: model.nonCertAuthorities)
                
            case .leafCertificates:
                certificatesList(certs: model.leafCertificates)
            }
            
        } detail: {
            EmptyView()
        }
        .navigationTitle(currentSection.rawValue)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createCertPresented.toggle()
                    
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $createCertPresented) {
            CertificateCreateView(model: model)
        }
        .onAppear {
            model.loadCertificates()
        }
    }
    
    private func certificatesList(certs: [TLSCertificate]) -> some View {
        List(certs, id: \.id) { cert in
            NavigationLink {
                CertificateView(cert: cert, model: model)
                    .id(cert.id)
                
            } label: {
                CertificateCellView(cert: cert, model: model)
            }
        }
    }
}

#Preview {
    ContentView()
}
