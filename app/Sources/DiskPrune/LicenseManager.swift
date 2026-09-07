import Foundation
import Security

class LicenseManager {
    static let shared = LicenseManager()
    
    func activate(licenseKey: String) async throws -> Bool {
        let url = URL(string: "https://api.lemonsqueezy.com/v1/licenses/activate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["license_key": licenseKey]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let valid = json["valid"] as? Bool {
            if valid {
                saveKeyToKeychain(licenseKey)
            }
            return valid
        }
        return false
    }
    
    private func saveKeyToKeychain(_ key: String) {
        let keyData = key.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "DiskPruneLicense",
            kSecValueData as String: keyData
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
