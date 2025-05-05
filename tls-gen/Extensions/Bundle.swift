//
//  Bundle.swift
//  tls-gen
//
//  Created by Всеволод Донченко on 15.04.2025.
//

import Foundation

extension Bundle {
    
    var appId: String {
        bundleIdentifier ?? "com.vsevolond.tls-gen"
    }
}
