import CryptoKit
import Foundation

enum GiftCode {
    private static let publicDigest = "4f6bfd4b67d451e570dfe8de78b09e0cf7cdf6a15ae5611bd8eeb4a4e92e485f"

    static func accepts(_ input: String, defaults: UserDefaults = .standard) -> Bool {
        guard !input.isEmpty else { return false }
        if input == defaults.string(forKey: "privateGiftCode") { return true }

        let digest = SHA256.hash(data: Data(("FurElise.gift." + input).utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return digest == publicDigest || digest == defaults.string(forKey: "privateGiftCodeDigest")
    }
}
