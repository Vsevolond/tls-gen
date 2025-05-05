//
//  CertificateView.swift
//  tls-gen
//
//  Created by Всеволод Донченко on 05.05.2025.
//

import SwiftUI

struct CertificateView: View {
    let cert: TLSCertificate
    @ObservedObject var model: ContentViewModel
    
    @State private var isLoading = true
    
    @State private var certRepresentation: String? = nil
    @State private var keyRepresentation: String? = nil
    
    var body: some View {
        List {
            Section("Certificate") {
                if let certRepresentation {
                    Text(certRepresentation)
                        .monospaced()
                    
                } else {
                    if isLoading {
                        ProgressView()
                        
                    } else {
                        ContentUnavailableView("Can't load certificate representation", systemImage: "xmark.octagon.fill")
                    }
                }
            }
            
            Section("Private Key") {
                if let keyRepresentation {
                    Text(keyRepresentation)
                        .monospaced()
                    
                } else {
                    if isLoading {
                        ProgressView()
                        
                    } else {
                        ContentUnavailableView("Can't load private key representation", systemImage: "xmark.octagon.fill")
                    }
                }
            }
        }
        .listStyle(.plain)
        .onAppear {
            model.loadRepresentation(of: cert) { certString, keyString in
                certRepresentation = certString
                keyRepresentation = keyString
                
                isLoading = false
            }
        }
    }
}
