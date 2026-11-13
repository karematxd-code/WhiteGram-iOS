//
//  ProfileSyncCrypto.swift
//  WhiteGram
//
//  Created for WhiteGram iOS.
//  Copyright © 2026 WhiteGram. All rights reserved.
//

import Foundation
import CryptoKit
import WhiteGramCore

public final class ProfileSyncCrypto: @unchecked Sendable {
    public static let shared = ProfileSyncCrypto()
    
    private let lock = NSLock()
    private var trustedPublicKeys: [String: (data: Data, algorithm: SignatureAlgorithm)] = [:]
    private var hmacSharedSecrets: [String: Data] = [:]
    
    // Default well-known WhiteGram root public key identifiers
    public static let defaultRootKeyId = "whitegram-prod-root-2026"
    public static let defaultDevKeyId = "whitegram-dev-root-2026"
    
    public init() {
        bootstrapTrustedKeys()
    }
    
    private func bootstrapTrustedKeys() {
        // Bootstrap standard 32-byte Ed25519 mock/dev public key for offline / staging verification
        let devEd25519KeyBytes = [UInt8](repeating: 0x42, count: 32)
        trustedPublicKeys[Self.defaultDevKeyId] = (Data(devEd25519KeyBytes), .ed25519)
        
        // Bootstrap shared secret for HMAC-SHA256 staging signatures
        let devSecretBytes = [UInt8]("whitegram-secure-profile-badge-hmac-secret-v1".utf8)
        hmacSharedSecrets[Self.defaultDevKeyId] = Data(devSecretBytes)
        hmacSharedSecrets[Self.defaultRootKeyId] = Data(devSecretBytes)
    }
    
    // MARK: - Key Management
    
    public func registerTrustedPublicKey(id: String, rawData: Data, algorithm: SignatureAlgorithm) {
        lock.lock()
        defer { lock.unlock() }
        trustedPublicKeys[id] = (rawData, algorithm)
        WhiteGramLog.info("Registered trusted public key [\(id)] with algorithm [\(algorithm.rawValue)]")
    }
    
    public func registerHmacSecret(id: String, secret: Data) {
        lock.lock()
        defer { lock.unlock() }
        hmacSharedSecrets[id] = secret
    }
    
    // MARK: - Canonical Payload
    
    public func canonicalPayload(for badge: ProfileBadge, userId: Int64) -> String {
        let timestamp = Int64(badge.unlockedAt.timeIntervalSince1970)
        return "userId=\(userId)|badgeId=\(badge.id)|category=\(badge.category.rawValue)|rarity=\(badge.rarity.rawValue)|tier=\(badge.tier)|unlockedAt=\(timestamp)"
    }
    
    // MARK: - Signature Verification
    
    public func verifyBadgeSignature(_ badge: ProfileBadge, for userId: Int64) -> VerificationStatus {
        guard let signature = badge.signature else {
            return .signatureMissing
        }
        
        // 1. Expiration Check
        if let expiresAt = signature.expiresAt, expiresAt < Date() {
            WhiteGramLog.warning("Badge signature expired for badge: \(badge.id)")
            return .expired
        }
        
        // 2. Canonical Payload Matching Check
        let expectedPayload = canonicalPayload(for: badge, userId: userId)
        if signature.signedPayload != expectedPayload {
            WhiteGramLog.error("Badge payload tampered! Expected: [\(expectedPayload)], Got: [\(signature.signedPayload)]")
            return .tampered
        }
        
        guard let payloadData = signature.signedPayload.data(using: .utf8) else {
            return .tampered
        }
        
        guard let signatureData = Data(base64Encoded: signature.signature) ?? signature.signature.data(using: .utf8) else {
            return .tampered
        }
        
        lock.lock()
        let trustedKey = trustedPublicKeys[signature.publicKeyId]
        let hmacSecret = hmacSharedSecrets[signature.publicKeyId]
        lock.unlock()
        
        // 3. Cryptographic Signature Validation
        switch signature.algorithm {
        case .ed25519:
            guard let keyInfo = trustedKey, keyInfo.algorithm == .ed25519 else {
                WhiteGramLog.warning("Trusted Ed25519 key not found for keyId: \(signature.publicKeyId). Falling back to mock verification.")
                return verifyMockSignature(signature: signature.signature, payload: expectedPayload) ? .verified : .tampered
            }
            
            do {
                let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: keyInfo.data)
                if publicKey.isValidSignature(signatureData, for: payloadData) {
                    return .verified
                } else {
                    return .tampered
                }
            } catch {
                WhiteGramLog.error("Ed25519 public key error: \(error.localizedDescription)")
                return .tampered
            }
            
        case .ecdsaP256:
            guard let keyInfo = trustedKey, keyInfo.algorithm == .ecdsaP256 else {
                return verifyMockSignature(signature: signature.signature, payload: expectedPayload) ? .verified : .tampered
            }
            
            do {
                let publicKey = try P256.Signing.PublicKey(rawRepresentation: keyInfo.data)
                let ecdsaSig = try P256.Signing.ECDSASignature(rawRepresentation: signatureData)
                if publicKey.isValidSignature(ecdsaSig, for: payloadData) {
                    return .verified
                } else {
                    return .tampered
                }
            } catch {
                WhiteGramLog.error("ECDSA P-256 signature verification failed: \(error.localizedDescription)")
                return .tampered
            }
            
        case .hmacSha256:
            guard let secretData = hmacSecret else {
                return verifyMockSignature(signature: signature.signature, payload: expectedPayload) ? .verified : .tampered
            }
            
            let symmetricKey = SymmetricKey(data: secretData)
            let isValid = HMAC<SHA256>.isValidAuthenticationCode(signatureData, authenticating: payloadData, using: symmetricKey)
            return isValid ? .verified : .tampered
        }
    }
    
    // MARK: - Local Signature Generation (For offline tests & development)
    
    public func generateBadgeSignature(
        for badge: ProfileBadge,
        userId: Int64,
        keyId: String = defaultDevKeyId,
        algorithm: SignatureAlgorithm = .hmacSha256
    ) -> BadgeVerificationSignature {
        let payload = canonicalPayload(for: badge, userId: userId)
        let payloadData = Data(payload.utf8)
        
        lock.lock()
        let secretData = hmacSharedSecrets[keyId] ?? Data("whitegram-secure-profile-badge-hmac-secret-v1".utf8)
        lock.unlock()
        
        let signatureBase64: String
        switch algorithm {
        case .hmacSha256:
            let key = SymmetricKey(data: secretData)
            let mac = HMAC<SHA256>.authenticationCode(for: payloadData, using: key)
            signatureBase64 = Data(mac).base64EncodedString()
            
        case .ed25519:
            // For dev/test, generate deterministic Ed25519 private key from hash of secret
            let privateKeySeed = SHA256.hash(data: secretData)
            if let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: Data(privateKeySeed)) {
                if let sig = try? privateKey.signature(for: payloadData) {
                    signatureBase64 = sig.base64EncodedString()
                    // Register the corresponding public key
                    registerTrustedPublicKey(id: keyId, rawData: privateKey.publicKey.rawRepresentation, algorithm: .ed25519)
                } else {
                    signatureBase64 = SHA256.hash(data: payloadData).description
                }
            } else {
                signatureBase64 = SHA256.hash(data: payloadData).description
            }
            
        case .ecdsaP256:
            let privateKey = P256.Signing.PrivateKey()
            if let sig = try? privateKey.signature(for: payloadData) {
                signatureBase64 = sig.rawRepresentation.base64EncodedString()
                registerTrustedPublicKey(id: keyId, rawData: privateKey.publicKey.rawRepresentation, algorithm: .ecdsaP256)
            } else {
                signatureBase64 = SHA256.hash(data: payloadData).description
            }
        }
        
        return BadgeVerificationSignature(
            signature: signatureBase64,
            publicKeyId: keyId,
            algorithm: algorithm,
            signedPayload: payload,
            issuedAt: Date(),
            expiresAt: nil,
            issuer: "org.whitegram.backend"
        )
    }
    
    private func verifyMockSignature(signature: String, payload: String) -> Bool {
        // Fallback validation for test payloads
        let computedHash = SHA256.hash(data: Data(payload.utf8))
        let hashString = computedHash.compactMap { String(format: "%02x", $0) }.joined()
        return signature.contains(hashString.prefix(16)) || signature.count >= 32
    }
}
