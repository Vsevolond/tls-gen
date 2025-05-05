//
//  Storage.swift
//  tls-gen
//
//  Created by Всеволод Донченко on 14.04.2025.
//

import Foundation
import RealmSwift
import os

enum StorageError: Error {
    case fetchingFailed
    case savingFailed
    case deletingFailed
    case noObjectWithId(id: UUID)
}

final class Storage {
    private lazy var logger = os.Logger(subsystem: Bundle.main.appId, category: "Storage")
    
    init() {
        Realm.Configuration.defaultConfiguration = Realm.Configuration(deleteRealmIfMigrationNeeded: true)
    }
    
    func fetch() async throws -> [TLSCertificate] {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let store = try Realm()
                let objects = store.objects(TLSCertificateObject.self).toArray()
                
                let certs = try objects.map { try TLSCertificate(from: $0) }
                continuation.resume(returning: certs)
                
            } catch let err {
                error("objects fetching error: \(err)")
                continuation.resume(throwing: StorageError.fetchingFailed)
            }
        }
    }
    
    func save(cert: TLSCertificate) async throws {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let store = try Realm()
                let object = try TLSCertificateObject(from: cert)
                
                try store.write { store.add(object) }
                continuation.resume()
                
            } catch let err {
                error("object saving error: \(err)")
                continuation.resume(throwing: StorageError.savingFailed)
            }
        }
    }
    
    func delete(cert: TLSCertificate) async throws {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let store = try Realm()
                
                if let object = store.object(ofType: TLSCertificateObject.self, forPrimaryKey: cert.id) {
                    try store.write {
                        store.delete(object)
                    }
                    
                    continuation.resume()
                    
                } else {
                    error("no object with id: \(cert.id)")
                    continuation.resume(throwing: StorageError.noObjectWithId(id: cert.id))
                }
                
            } catch let err {
                error("object deleting error: \(err)")
                continuation.resume(throwing: StorageError.deletingFailed)
            }
        }
    }
    
    private func log(_ message: String) {
        logger.log("💿 Storage: \(message)")
    }
    
    private func error(_ message: String) {
        logger.error("💿 Storage: \(message)")
    }
}

private extension Results {
    
    func toArray() -> [Element] { Array(self) }
}
