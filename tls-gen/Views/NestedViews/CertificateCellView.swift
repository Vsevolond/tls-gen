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

private extension Date {
    
    var medium: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }
}
