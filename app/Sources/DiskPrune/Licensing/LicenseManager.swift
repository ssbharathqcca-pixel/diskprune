import CryptoKit
import Foundation

protocol LicenseTalking: AnyObject {
    func post(path: String, body: [String: Any]) async throws -> (status: Int, json: [String: Any])
}

final class LiveLicenseAPI: LicenseTalking {
    var baseURL: URL
    var session: URLSession

    init(baseURL: URL = URL(string: "https://api.diskprune.com")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func post(path: String, body: [String: Any]) async throws -> (status: Int, json: [String: Any]) {
        var url = baseURL
        for part in path.split(separator: "/") {
            url.appendPathComponent(String(part))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return (status, json)
    }
}

struct SeatDevice: Equatable, Identifiable {
    var id: String { deviceId }
    var deviceId: String
    var deviceName: String?
    var lastSeen: Date?
}

enum LicenseStatus: Equatable {
    case notActivated
    case active
    case expired
    case releasedExpired
    case needsOnlineCheck
}

/// Entitlement comes only from a verified DPL token. Keychain presence grants nothing.
@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published private(set) var entitlements: Set<String> = []
    @Published private(set) var status: LicenseStatus = .notActivated
    @Published private(set) var clockWarning: String?
    @Published private(set) var seatLimitDevices: [SeatDevice] = []
    @Published private(set) var lastUserMessage: String?
    @Published private(set) var maxDevices: Int = 0
    @Published private(set) var busy = false

    var canClean: Bool { entitlements.contains("cleanup") }

    let store: KeychainStore
    let api: LicenseTalking
    var clock: () -> Date
    var keys: [String: Curve25519.Signing.PublicKey]
    var refreshInterval: TimeInterval = 24 * 3600

    private var pendingKey: String?
    private let nbfSkew: TimeInterval = 24 * 3600

    init(
        store: KeychainStore = .standard,
        api: LicenseTalking = LiveLicenseAPI(),
        clock: @escaping () -> Date = Date.init,
        keys: [String: Curve25519.Signing.PublicKey] = PublicKeys.byKid
    ) {
        self.store = store
        self.api = api
        self.clock = clock
        self.keys = keys
        evaluate()
    }

    func start() {
        evaluate()
        guard !VisualQARuntime.isEnabled else { return }
        Task { await refreshIfDue() }
    }

    var deviceId: String { DeviceIdentity.current(store: store) }

    var hasStoredToken: Bool { store.string(.token) != nil }

    var cleanupBlockedMessage: String {
        switch status {
        case .releasedExpired:
            return "This Mac was released. Activate it again in Settings → Licence."
        case .expired, .needsOnlineCheck:
            return "DiskPrune needs to check your license. Connect to the internet."
        case .notActivated:
            return "Activate DiskPrune in Settings → Licence to move items to Trash."
        case .active:
            return ""
        }
    }

    var statusLabel: String {
        switch status {
        case .active: return "Active"
        case .expired, .needsOnlineCheck: return "Needs a connection"
        case .releasedExpired: return "Released"
        case .notActivated: return "Not activated"
        }
    }

    func evaluate() {
        let instant = clock()
        updateClock(now: instant)

        if let deadline = store.date(.requiresOnlineCheckBy), instant >= deadline {
            let last = store.date(.lastOnline) ?? Date.distantPast
            if last < deadline {
                entitlements = []
                status = .needsOnlineCheck
                lastUserMessage = "DiskPrune needs to check your license. Connect to the internet."
                return
            }
        }

        applyStoredToken(now: instant)
    }

    func activate(licenseKey: String) async {
        lastUserMessage = nil
        seatLimitDevices = []
        let key = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        pendingKey = key
        busy = true
        defer { busy = false }
        do {
            let body: [String: Any] = [
                "license_key": key,
                "device_id": deviceId,
                "device_name": Host.current().localizedName ?? "Mac"
            ]
            let (code, json) = try await api.post(path: "v1/licenses/activate", body: body)
            switch code {
            case 200:
                guard let token = json["token"] as? String else {
                    lastUserMessage = "DiskPrune needs to check your license. Connect to the internet."
                    return
                }
                acceptIssuedToken(token, licenseKey: key)
            case 409:
                if (json["error"] as? String) == "SEAT_LIMIT" {
                    seatLimitDevices = Self.parseDevices(json["devices"])
                    lastUserMessage = "This licence is active on the maximum number of Macs. Release one to continue."
                    return
                }
                lastUserMessage = "This licence can’t be activated right now. Try again later or email support."
            case 403:
                lastUserMessage = "This licence can’t be activated. Email support@diskprune.com."
            case 404:
                lastUserMessage = "No licence matches that key."
            case 400:
                lastUserMessage = "Check the key and try again."
            case 429:
                lastUserMessage = "Too many attempts. Try again in an hour."
            default:
                lastUserMessage = "DiskPrune needs to check your license. Connect to the internet."
            }
        } catch {
            lastUserMessage = "DiskPrune needs to check your license. Connect to the internet."
        }
    }

    func refreshIfDue(force: Bool = false) async {
        guard hasStoredToken else { return }
        let instant = clock()
        if !force, let last = store.date(.lastOnline), instant.timeIntervalSince(last) < refreshInterval {
            return
        }
        await refresh()
    }

    func refresh() async {
        guard let token = store.string(.token) else { return }
        do {
            let (code, json) = try await api.post(path: "v1/licenses/refresh", body: ["token": token])
            switch code {
            case 200:
                if let next = json["token"] as? String {
                    acceptIssuedToken(next, licenseKey: store.string(.licenseKey))
                }
            case 403:
                let err = json["error"] as? String
                if err == "DEVICE_RELEASED" {
                    store.set(.pendingEndReason, string: "released")
                } else if err == "LICENSE_REVOKED" {
                    store.set(.pendingEndReason, string: "revoked")
                }
                applyStoredToken(now: clock())
            default:
                break
            }
        } catch {
            // Network failure: existing token remains authoritative.
        }
    }

    func release(deviceId target: String? = nil) async {
        let key = pendingKey ?? store.string(.licenseKey)
        guard let key else {
            lastUserMessage = "Activate with your licence key before releasing a Mac."
            return
        }
        busy = true
        defer { busy = false }
        do {
            let (code, _) = try await api.post(
                path: "v1/licenses/release",
                body: ["license_key": key, "device_id": target ?? deviceId]
            )
            if code == 200 {
                if target == nil || target == deviceId {
                    store.set(.pendingEndReason, string: "released")
                    applyStoredToken(now: clock())
                }
                seatLimitDevices.removeAll { $0.deviceId == (target ?? deviceId) }
            }
        } catch {
            lastUserMessage = "DiskPrune needs to check your license. Connect to the internet."
        }
    }

    private func acceptIssuedToken(_ token: String, licenseKey: String?) {
        let instant = clock()
        switch LicenseToken.verify(token, deviceId: deviceId, now: instant, keys: keys, nbfSkew: nbfSkew) {
        case .success(let claims):
            store.set(.token, string: token)
            store.set(.verifiedToken, string: token)
            if let licenseKey, !licenseKey.isEmpty {
                store.set(.licenseKey, string: licenseKey)
            }
            store.set(.lastOnline, date: instant)
            store.remove(.requiresOnlineCheckBy)
            store.remove(.pendingEndReason)
            clockWarning = nil
            pendingKey = nil
            if claims.hasCleanup {
                entitlements = Set(claims.entitlements)
                status = .active
                maxDevices = claims.maxDevices
            } else {
                entitlements = []
                status = .notActivated
            }
            lastUserMessage = nil
            seatLimitDevices = []
        case .failure:
            lastUserMessage = "DiskPrune needs to check your license. Connect to the internet."
        }
    }

    private func applyStoredToken(now instant: Date) {
        guard let compact = store.string(.token) else {
            entitlements = []
            status = .notActivated
            return
        }
        switch LicenseToken.verify(compact, deviceId: deviceId, now: instant, keys: keys, nbfSkew: nbfSkew) {
        case .success(let claims):
            store.set(.verifiedToken, string: compact)
            if claims.hasCleanup {
                entitlements = Set(claims.entitlements)
                status = .active
                maxDevices = claims.maxDevices
            } else {
                entitlements = []
                status = .notActivated
            }
        case .failure(.expired):
            entitlements = []
            if store.string(.pendingEndReason) == "released" {
                status = .releasedExpired
            } else {
                status = .expired
            }
        case .failure(.unknownKid):
            if let previous = store.string(.verifiedToken), previous != compact,
               case .success(let claims) = LicenseToken.verify(previous, deviceId: deviceId, now: instant, keys: keys, nbfSkew: nbfSkew),
               claims.hasCleanup {
                entitlements = Set(claims.entitlements)
                status = .active
                maxDevices = claims.maxDevices
            } else {
                entitlements = []
                status = .needsOnlineCheck
            }
        case .failure(.invalidSignature), .failure(.deviceMismatch):
            store.remove(.token)
            entitlements = []
            status = .notActivated
        case .failure(.notYetValid):
            entitlements = []
            status = .needsOnlineCheck
        default:
            entitlements = []
            status = .notActivated
        }
    }

    private func updateClock(now instant: Date) {
        let storedMax = store.date(.maxSeenTime) ?? instant
        if instant < storedMax.addingTimeInterval(-nbfSkew) {
            clockWarning = "Your Mac's clock appears to be incorrect"
            if store.date(.requiresOnlineCheckBy) == nil {
                store.set(.requiresOnlineCheckBy, date: storedMax.addingTimeInterval(7 * 24 * 3600))
            }
        } else {
            store.set(.maxSeenTime, date: max(storedMax, instant))
        }
    }

    private static func parseDevices(_ raw: Any?) -> [SeatDevice] {
        guard let rows = raw as? [[String: Any]] else { return [] }
        return rows.compactMap { row in
            guard let id = row["device_id"] as? String else { return nil }
            let seen: Date?
            if let n = jsonInt64(row["last_seen"]) {
                seen = Date(timeIntervalSince1970: TimeInterval(n))
            } else {
                seen = nil
            }
            return SeatDevice(deviceId: id, deviceName: row["device_name"] as? String, lastSeen: seen)
        }
    }
}
