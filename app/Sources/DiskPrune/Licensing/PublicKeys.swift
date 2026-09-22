import CryptoKit
import Foundation

/// Ed25519 public keys only. The matching PKCS#8 private keys are Wrangler
/// secrets and must never exist in this target, the app bundle, or the repository.
enum PublicKeys {
    /// Raw 32-byte Ed25519 public key, standard base64.
    /// Must equal `worker/wrangler.toml` `[vars] LICENSE_SIGNING_PUB_K1` (CI job 9).
    /// Production k1 from `9d1259fe`. The matching PKCS#8 private key is the
    /// Wrangler secret `LICENSE_SIGNING_KEY_K1` and must never enter this target.
    static let k1Base64 = "bwDWn1ibch4eF1MY64LX4pgFIxaGhrOM9dPtS5LtTEU="

    static let byKid: [String: Curve25519.Signing.PublicKey] = {
        var map: [String: Curve25519.Signing.PublicKey] = [:]
        if let k1 = key(fromStandardBase64: k1Base64) {
            map["k1"] = k1
        }
        return map
    }()

    static func key(fromStandardBase64 value: String) -> Curve25519.Signing.PublicKey? {
        guard let data = Data(base64Encoded: value) else { return nil }
        return try? Curve25519.Signing.PublicKey(rawRepresentation: data)
    }
}
