import CryptoKit
import XCTest
@testable import DiskPrune

final class LicenseTokenTests: XCTestCase {
    let device = "device-ada"
    var pair: TestTokens.Pair!
    var now: Date!

    override func setUp() {
        super.setUp()
        pair = TestTokens.pair()
        now = LicenseFixtures.t0
    }

    func testTOK01_validTokenVerifies() {
        let token = TestTokens.issue(privateKey: pair.privateKey, deviceId: device, now: now, ttl: 90 * LicenseFixtures.day)
        let result = LicenseToken.verify(token, deviceId: device, now: now, keys: pair.keys)
        guard case .success(let claims) = result else {
            return XCTFail("expected valid token")
        }
        XCTAssertTrue(claims.hasCleanup)
        XCTAssertEqual(claims.deviceId, device)
        XCTAssertEqual(claims.kid, "k1")
        XCTAssertEqual(claims.maxDevices, 3)
    }

    func testTOK02_bitFlippedSignatureRejected() {
        let token = TestTokens.issue(privateKey: pair.privateKey, deviceId: device, now: now, ttl: 90 * LicenseFixtures.day)
        let flipped = TestTokens.bitFlip(token)
        switch LicenseToken.verify(flipped, deviceId: device, now: now, keys: pair.keys) {
        case .failure(.invalidSignature): break
        default: XCTFail("tampered token must be invalidSignature")
        }
    }

    func testTOK03_unknownKid() {
        let token = TestTokens.issue(privateKey: pair.privateKey, kid: "k2", deviceId: device, now: now, ttl: 90 * LicenseFixtures.day)
        switch LicenseToken.verify(token, deviceId: device, now: now, keys: pair.keys) {
        case .failure(.unknownKid): break
        default: XCTFail("unknown kid")
        }
    }

    func testTOK04_wrongDevice() {
        let token = TestTokens.issue(privateKey: pair.privateKey, deviceId: device, now: now, ttl: 90 * LicenseFixtures.day)
        switch LicenseToken.verify(token, deviceId: "other-mac", now: now, keys: pair.keys) {
        case .failure(.deviceMismatch): break
        default: XCTFail("wrong device")
        }
    }

    func testTOK05_expiredToken() {
        let token = TestTokens.issue(privateKey: pair.privateKey, deviceId: device, now: now.addingTimeInterval(-20 * LicenseFixtures.day), ttl: 10 * LicenseFixtures.day)
        switch LicenseToken.verify(token, deviceId: device, now: now, keys: pair.keys) {
        case .failure(.expired): break
        default: XCTFail("expired")
        }
    }

    func testTOK06_k2TokenValidWithTwoKeyMap() {
        let k1 = TestTokens.pair(kid: "k1")
        let k2 = TestTokens.pair(kid: "k2")
        let token = TestTokens.issue(privateKey: k2.privateKey, kid: "k2", deviceId: device, now: now, ttl: 90 * LicenseFixtures.day)
        var keys = k1.keys
        keys["k2"] = k2.publicKey
        let result = LicenseToken.verify(token, deviceId: device, now: now, keys: keys)
        guard case .success(let claims) = result else {
            return XCTFail("k2 token should verify")
        }
        XCTAssertEqual(claims.kid, "k2")
    }

    func testTOK07_reorderedPayloadJSONStillValid() {
        let token = TestTokens.issue(privateKey: pair.privateKey, deviceId: device, now: now, ttl: 90 * LicenseFixtures.day, reversed: true)
        let result = LicenseToken.verify(token, deviceId: device, now: now, keys: pair.keys)
        guard case .success = result else {
            return XCTFail("signature is over transmitted bytes, key order must not matter")
        }
    }

    func testMalformedAndHeaderFailures() {
        switch LicenseToken.verify("only-one", deviceId: device, now: now, keys: pair.keys) {
        case .failure(.malformed): break
        default: XCTFail("malformed")
        }
        let header = Base64URL.encode("{\"alg\":\"none\",\"typ\":\"JWT\",\"kid\":\"k1\"}")
        let payload = Base64URL.encode(TestTokens.payload(deviceId: device, iat: 1, exp: 2))
        switch LicenseToken.verify("\(header).\(payload).sig", deviceId: device, now: now, keys: pair.keys) {
        case .failure(.invalidHeader): break
        default: XCTFail("invalid header")
        }
    }

    func testUnsupportedVersion() {
        let token = TestTokens.issue(privateKey: pair.privateKey, deviceId: device, now: now, ttl: 90 * LicenseFixtures.day, version: 2)
        switch LicenseToken.verify(token, deviceId: device, now: now, keys: pair.keys) {
        case .failure(.unsupportedVersion): break
        default: XCTFail("unsupported version")
        }
    }
}
