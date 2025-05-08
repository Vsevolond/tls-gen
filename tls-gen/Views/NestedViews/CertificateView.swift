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
    
    @State private var certRepresentationSize: CGFloat = 12
    @State private var keyRepresentationSize: CGFloat = 12
    
    @State private var certRepresentation: String? = nil
    @State private var keyRepresentation: String? = nil
    
    var body: some View {
        List {
            Section {
                if let certRepresentation {
                    Text(certRepresentation)
                        .font(.system(size: certRepresentationSize))
                        .monospaced()
                    
                } else {
                    if isLoading {
                        ProgressView()
                        
                    } else {
                        ContentUnavailableView(
                            "Can't load certificate representation",
                            systemImage: "xmark.octagon.fill"
                        )
                    }
                }
                
            } header: {
                HStack {
                    Text("Certificate")
                    Spacer()
                    
                    Stepper("", value: $certRepresentationSize, in: 8...16)
                }
                .padding(.trailing)
            }
            
            Section {
                if let keyRepresentation {
                    Text(keyRepresentation)
                        .font(.system(size: keyRepresentationSize))
                        .monospaced()
                    
                } else {
                    if isLoading {
                        ProgressView()
                        
                    } else {
                        ContentUnavailableView(
                            "Can't load private key representation",
                            systemImage: "xmark.octagon.fill"
                        )
                    }
                }
                
            } header: {
                HStack {
                    Text("Private Key")
                    Spacer()
                    
                    Stepper("", value: $keyRepresentationSize, in: 8...16)
                }
                .padding(.trailing)
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .onAppear {
            model.loadRepresentation(of: cert) { certString, keyString in
                certRepresentation = certString
                keyRepresentation = keyString
                
                isLoading = false
            }
        }
    }
}
