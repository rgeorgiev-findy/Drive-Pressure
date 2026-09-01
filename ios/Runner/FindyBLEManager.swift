import Foundation
import CoreBluetooth
import UserNotifications
import CommonCrypto

/// Native CBCentralManager for background BLE scanning and terminated-state app wake-up.
///
/// Supports two advertising formats:
///
/// NEW (firmware v2+) — Service Data (AD type 0x20, 32-bit UUID 0x54504D53), 22 bytes:
///   [0-4]   Nonce (5 B): 2B chip-salt + 3B counter
///   [5-17]  Ciphertext (13 B): AES-128-CCM encrypted payload
///   [18-21] Tag (4 B): CCM authentication tag
///   CCM IV (7 B): 0x54 0x50 ("TP") + nonce[0-4]
///   CCM AD (9 B): UUID LE (53 4D 50 54) + nonce[0-4]
///   Plaintext [0-5] MAC MSB first, [6-7] gauge pressure LE ×10 mbar, [8] temp raw-56,
///             [9] bat|tyre, [10-11] VIN, [12] flags
///
/// LEGACY (firmware v1) — Manufacturer Data (encrypted AES-128 ECB):
///   Manufacturer ID 0x0601 or 0x4C00 + Sensata MUX(0x06) + version + 16-byte ciphertext
///
/// iOS uses the service UUID to wake the app from a terminated state when a sensor
/// is detected. Force-quit by the user permanently disables this until next launch.
class FindyBLEManager: NSObject {
    static let shared = FindyBLEManager()
    private override init() { super.init() }

    /// 32-bit Service UUID "TPMS" (0x54504D53). Sensor embeds this in the
    /// Service Data 32-bit UUID field (AD type 0x20) of every advertisement.
    /// iOS uses it to wake the app from a terminated state when the sensor is found.
    static let serviceUUID = CBUUID(string: "54504D53")
    private static let restoreKey = "eu.findy.tpms.central"
    // Flutter's shared_preferences_foundation stores all keys with this prefix.
    private static let fp = "flutter."

    // Legacy Manufacturer Data constants
    private static let schraderMfrID: UInt16 = 0x0601
    private static let vendor2MfrID:  UInt16 = 0x4C00
    private static let sensataMux:    UInt8  = 0x06

    // AES-128 ECB keys (legacy format only)
    private let schraderKey: [UInt8] = hexBytes("4679846FC84A9DD013F601E16D40E350")
    private let vendor2Key:  [UInt8] = hexBytes("3ddf863dcc71c5273989cd77583cf70c")

    // AES-128-CCM key (firmware v2 service data format)
    private let tpmsV2Key: [UInt8] = hexBytes("D6C81D70443AAA96B0AB5914752CEB92")

    private let posNames = ["fl", "fr", "rl", "rr", "l", "r", "ml", "mr"]

    private var central: CBCentralManager?

    func start() {
        guard central == nil else { return }
        central = CBCentralManager(
            delegate: self,
            queue: DispatchQueue.global(qos: .background),
            options: [CBCentralManagerOptionRestoreIdentifierKey: Self.restoreKey]
        )
    }
}

// MARK: - CBCentralManagerDelegate
extension FindyBLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { startScan() }
    }

    func centralManager(_ central: CBCentralManager,
                        willRestoreState dict: [String: Any]) {
        // centralManagerDidUpdateState fires next and restarts scanning.
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi: NSNumber) {
        // Use only Service Data — iOS wakes the app for this UUID,
        // and the plaintext payload has everything needed for alarm checks.
        guard let svcDict = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: NSData],
              let nsData  = svcDict[Self.serviceUUID] else { return }
        parseServiceData(nsData)
    }

    private func startScan() {
        // AllowDuplicatesKey: true — deliver every advertisement so packets are
        // continuously forwarded to Flutter via nativeBleChannel. iOS automatically
        // ignores this in background/terminated state, so there is no extra battery
        // cost when the app is not in the foreground. With the service UUID filter
        // only our sensors are reported, keeping CPU load minimal.
        central?.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }
}

// MARK: - Service Data Parser (AD type 0x20, 32-bit UUID 0x54504D53)
extension FindyBLEManager {
    /// Decrypts and parses the 22-byte Service Data value delivered by iOS after stripping the UUID.
    ///
    /// Wire layout:
    ///   [0-4]   Nonce (5 B)
    ///   [5-17]  Ciphertext (13 B, AES-128-CCM)
    ///   [18-21] Tag (4 B)
    ///
    /// Plaintext (13 B) after decryption:
    ///   [0-5]   MAC MSB first
    ///   [6-7]   Gauge pressure LE uint16, bar = raw × 10 / 1000
    ///   [8]     Temperature uint8, °C = raw − 56
    ///   [9]     bits[7:4]=battery capacity 0-10, bits[3:0]=tyre slot
    ///   [10-11] VIN LE uint16
    ///   [12]    Flags: bits[1:0]=wake reason, bit[2]=sensor_err, bit[3]=low_bat,
    ///                  bit[4]=low_pressure_SSP, bit[5]=high_pressure_SSP
    private func parseServiceData(_ nsData: NSData) {
        guard nsData.length >= 22 else { return }
        var raw = [UInt8](repeating: 0, count: nsData.length)
        nsData.getBytes(&raw, length: nsData.length)

        let nonce5  = Array(raw[0..<5])
        let ctBytes = Array(raw[5..<18])
        let tagBytes = Array(raw[18..<22])

        // CCM IV (7 B): "TP" + nonce
        let nonce7: [UInt8] = [0x54, 0x50] + nonce5
        // AD (9 B): UUID in LE wire order + nonce
        let ad: [UInt8] = [0x53, 0x4D, 0x50, 0x54] + nonce5

        guard let p = ccmDecrypt(key: tpmsV2Key, nonce7: nonce7, ad: ad,
                                 ciphertext: ctBytes, tag: tagBytes) else { return }

        let mac = (0...5).map { String(format: "%02X", p[$0]) }.joined(separator: ":")

        let pressureRaw = Int(p[6]) | (Int(p[7]) << 8)
        let pressureBar = pressureRaw != 0xFFFF ? Double(pressureRaw) * 10.0 / 1000.0 : -1.0

        let tempC = Int(p[8]) - 56
        let capacity = Int((p[9] >> 4) & 0x0F)

        let flags    = p[12]
        let battLow  = (flags & 0x08) != 0  // bit 3
        let hasFault = (flags & 0x04) != 0  // bit 2 = sensor error

        // Always forward to Flutter — pairing screen needs to see unpaired sensors too.
        let args: [String: Any] = [
            "mac": mac, "pressure": pressureBar,
            "temp": tempC, "battLow": battLow,
            "fault": hasFault, "battCapacity": capacity
        ]
        DispatchQueue.main.async {
            nativeBleChannel?.invokeMethod("packet", arguments: args)
        }

        // Cache and alarm-check only for already-paired sensors.
        guard let pos = positionFor(mac: mac) else { return }
        cacheReading(pos: pos, pressureBar: pressureBar, tempC: tempC,
                     battLow: battLow, hasFault: hasFault, batteryCapacity: capacity)
        checkAndNotify(mac: mac, pos: pos, pressureBar: pressureBar,
                       tempC: tempC, battLow: battLow, hasFault: hasFault,
                       batteryCapacity: capacity)
    }

    /// AES-128-CCM decryption (RFC 3610).
    /// nonce7 is 7 bytes → N=7, L=15-7=8, t=4.
    /// Returns plaintext if tag verifies, nil otherwise.
    private func ccmDecrypt(key: [UInt8], nonce7: [UInt8], ad: [UInt8],
                            ciphertext: [UInt8], tag: [UInt8]) -> [UInt8]? {
        guard nonce7.count == 7, key.count == 16,
              tag.count == 4, !ciphertext.isEmpty else { return nil }

        func encBlock(_ input: [UInt8]) -> [UInt8]? {
            var out = [UInt8](repeating: 0, count: 16)
            var outLen = 0
            let st = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES128),
                             CCOptions(kCCOptionECBMode),
                             key, kCCKeySizeAES128, nil,
                             input, 16, &out, 16, &outLen)
            return st == kCCSuccess ? out : nil
        }

        let msgLen = ciphertext.count
        // N=7 → L=8: counter field is 8 bytes, flags = L-1 = 7
        let L = 8
        let Lm1 = UInt8(L - 1)  // = 7 = 0x07

        // --- CTR decrypt (counter starts at 1; counter 0 reserved for tag) ---
        var plain = [UInt8](repeating: 0, count: msgLen)
        let numBlocks = (msgLen + 15) / 16
        for bn in 1...numBlocks {
            // Counter block: [L-1=7][nonce7][counter in L=8 bytes BE]
            var ctr = [UInt8](repeating: 0, count: 16)
            ctr[0] = Lm1
            for j in 0..<7 { ctr[1 + j] = nonce7[j] }
            // 8-byte counter occupies ctr[8..15]; bn fits in last 2 bytes for realistic msg sizes
            ctr[14] = UInt8((bn >> 8) & 0xFF)
            ctr[15] = UInt8(bn & 0xFF)
            guard let stream = encBlock(ctr) else { return nil }
            let offset = (bn - 1) * 16
            let blockLen = min(16, msgLen - offset)
            for j in 0..<blockLen { plain[offset + j] = ciphertext[offset + j] ^ stream[j] }
        }

        // --- CBC-MAC ---
        // B0: flags | nonce7 (7B) | msgLen in L=8 bytes BE
        // flags = (Adata=1<<6) | (M'=(t-2)/2=1 <<3) | (L'=L-1=7)
        //       = 0b01001111 = 0x4F
        var b0 = [UInt8](repeating: 0, count: 16)
        b0[0] = 0x4F
        for j in 0..<7 { b0[1 + j] = nonce7[j] }
        // msgLen in 8 bytes BE at b0[8..15]; msgLen=13 → only last byte is non-zero
        b0[15] = UInt8(msgLen & 0xFF)
        guard var cbc = encBlock(b0) else { return nil }

        // Encode AD: 2-byte length prefix + AD bytes, padded to 16
        var adEnc: [UInt8] = [UInt8((ad.count >> 8) & 0xFF), UInt8(ad.count & 0xFF)]
        adEnc.append(contentsOf: ad)
        let adPad = (16 - (adEnc.count % 16)) % 16
        adEnc.append(contentsOf: [UInt8](repeating: 0, count: adPad))

        for i in stride(from: 0, to: adEnc.count, by: 16) {
            let xored = (0..<16).map { cbc[$0] ^ adEnc[i + $0] }
            guard let next = encBlock(xored) else { return nil }
            cbc = next
        }

        // Plaintext blocks padded to 16
        var ptPad = plain
        ptPad.append(contentsOf: [UInt8](repeating: 0, count: (16 - (plain.count % 16)) % 16))
        for i in stride(from: 0, to: ptPad.count, by: 16) {
            let xored = (0..<16).map { cbc[$0] ^ ptPad[i + $0] }
            guard let next = encBlock(xored) else { return nil }
            cbc = next
        }
        let cbcTag = Array(cbc.prefix(4))

        // A0: [L-1=7][nonce7][0x00…0x00] — encrypt to mask tag
        var a0 = [UInt8](repeating: 0, count: 16)
        a0[0] = Lm1
        for j in 0..<7 { a0[1 + j] = nonce7[j] }
        guard let a0enc = encBlock(a0) else { return nil }

        // Verify tag
        var diff: UInt8 = 0
        for i in 0..<4 { diff |= (cbcTag[i] ^ a0enc[i]) ^ tag[i] }
        guard diff == 0 else { return nil }

        return plain
    }
}

// MARK: - Legacy Manufacturer Data Parser (AES-128 ECB)
extension FindyBLEManager {
    private func parseLegacyPayload(_ payload: [UInt8]) {
        let pressureRaw = Int(payload[0]) | (Int(payload[1]) << 8)
        guard pressureRaw != 0 && pressureRaw != 0xFFFF else { return }
        let pressureBar = Double(pressureRaw) * 10.0 / 1000.0

        let tempC    = Int(payload[2]) - 56
        let status   = Int(payload[3]) | (Int(payload[4]) << 8)
        let hasFault = ((status >> 5) & 0x01) == 1
        let battByte = payload[6]
        let battLow  = ((battByte >> 1) & 0x01) == 1
        let capacity = Int((battByte >> 4) & 0x0F)

        // Extract MAC from payload bytes [7-12] reversed (iOS hides real MAC)
        let mac = (7...12).map { payload[$0] }.reversed()
            .map { String(format: "%02X", $0) }.joined(separator: ":")

        guard let pos = positionFor(mac: mac) else { return }
        checkAndNotify(mac: mac, pos: pos, pressureBar: pressureBar, tempC: tempC,
                       battLow: battLow, hasFault: hasFault, batteryCapacity: capacity)
    }

    private func parseSensata(_ raw: [UInt8], key: [UInt8]) -> [UInt8]? {
        guard raw.count >= 18, raw[0] == Self.sensataMux else { return nil }
        let cipher = Array(raw[2..<18])
        switch raw[1] {
        case 0x01: return cipher
        case 0x02: return aesDecrypt(cipher, key: key)
        default:   return nil
        }
    }

    private func aesDecrypt(_ input: [UInt8], key: [UInt8]) -> [UInt8]? {
        guard input.count == 16, key.count == 16 else { return nil }
        var output = [UInt8](repeating: 0, count: 16)
        var outLen = 0
        let status = CCCrypt(
            CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES128),
            CCOptions(kCCOptionECBMode),
            key, kCCKeySizeAES128,
            nil,
            input, input.count,
            &output, output.count,
            &outLen
        )
        return status == kCCSuccess ? output : nil
    }
}

// MARK: - Pairing Lookup
extension FindyBLEManager {
    private func positionFor(mac: String) -> String? {
        let d = UserDefaults.standard
        let p = Self.fp
        for pos in posNames {
            if d.string(forKey: "\(p)paired_mac_\(pos)") == mac { return pos }
        }
        for vid in d.stringArray(forKey: "\(p)vs_vehicle_ids") ?? [] {
            for pos in posNames {
                if d.string(forKey: "\(p)vs_mac_\(vid)_\(pos)") == mac { return pos }
            }
        }
        return nil
    }

    private func vehicleNameFor(mac: String) -> String? {
        let d = UserDefaults.standard
        let p = Self.fp
        for vid in d.stringArray(forKey: "\(p)vs_vehicle_ids") ?? [] {
            for pos in posNames {
                if d.string(forKey: "\(p)vs_mac_\(vid)_\(pos)") == mac {
                    return d.string(forKey: "\(p)vs_name_\(vid)")
                }
            }
        }
        return nil
    }
}

// MARK: - Cache latest reading for Flutter to pick up on foreground
extension FindyBLEManager {
    /// Writes the freshest sensor reading to UserDefaults so Flutter can read it
    /// via SharedPreferences when the app comes to the foreground.
    /// Keys use the flutter. prefix: "flutter.sensor_cache_{pos}_{field}"
    private func cacheReading(pos: String, pressureBar: Double, tempC: Int,
                               battLow: Bool, hasFault: Bool, batteryCapacity: Int) {
        let d = UserDefaults.standard
        let base = "\(Self.fp)sensor_cache_\(pos)_"
        d.set(pressureBar,      forKey: "\(base)pressure")
        d.set(tempC,            forKey: "\(base)temp")
        d.set(battLow,          forKey: "\(base)batt_low")
        d.set(batteryCapacity,  forKey: "\(base)batt_capacity")
        d.set(hasFault,         forKey: "\(base)fault")
        d.set(Date().timeIntervalSince1970, forKey: "\(base)ts")
    }
}

// MARK: - Alarm Check + Notification
extension FindyBLEManager {
    private func checkAndNotify(mac: String, pos: String,
                                pressureBar: Double, tempC: Int,
                                battLow: Bool, hasFault: Bool,
                                batteryCapacity: Int) {
        let d = UserDefaults.standard
        let p = Self.fp

        let minP   = d.object(forKey: "\(p)lim_min_pressure")   != nil ? d.double(forKey: "\(p)lim_min_pressure")  : 2.0
        let maxP   = d.object(forKey: "\(p)lim_max_pressure")   != nil ? d.double(forKey: "\(p)lim_max_pressure")  : 2.8
        let maxT   = d.object(forKey: "\(p)lim_max_temp")       != nil ? d.integer(forKey: "\(p)lim_max_temp")     : 70
        let alarmP = d.object(forKey: "\(p)lim_alarm_pressure") != nil ? d.bool(forKey: "\(p)lim_alarm_pressure")  : true
        let alarmT = d.object(forKey: "\(p)lim_alarm_temp")     != nil ? d.bool(forKey: "\(p)lim_alarm_temp")      : true
        let alarmB = d.object(forKey: "\(p)lim_alarm_battery")  != nil ? d.bool(forKey: "\(p)lim_alarm_battery")   : true

        let posIdx = posNames.firstIndex(of: pos) ?? 0
        let vName  = vehicleNameFor(mac: mac)
        let prefix = vName != nil ? "\(vName!) — \(pos.uppercased())" : posLabel(pos)

        // Collect alarm bodies to show ONE combined CarPlay alert (prevents
        // CPInterfaceController crash when multiple alarms fire from one packet).
        var carPlayBodies: [String] = []

        if alarmP && pressureBar >= 0 && pressureBar < minP {
            let b = String(format: "Low pressure: %.2f bar  ·  min %.1f bar", pressureBar, minP)
            notify(id: posIdx * 10 + 0, title: prefix, body: b)
            carPlayBodies.append(b)
        } else if alarmP && pressureBar >= 0 && pressureBar > maxP {
            let b = String(format: "High pressure: %.2f bar  ·  max %.1f bar", pressureBar, maxP)
            notify(id: posIdx * 10 + 1, title: prefix, body: b)
            carPlayBodies.append(b)
        }
        if alarmT && tempC > maxT {
            let b = "High temperature: \(tempC)°C  ·  limit \(maxT)°C"
            notify(id: posIdx * 10 + 2, title: prefix, body: b)
            carPlayBodies.append(b)
        }
        if alarmB && battLow {
            notify(id: posIdx * 10 + 3, title: prefix, body: "Battery low")
            carPlayBodies.append("Battery low")
        }
        if hasFault {
            notify(id: posIdx * 10 + 4, title: prefix, body: "Sensor fault detected")
            carPlayBodies.append("Sensor fault")
        }

        if !carPlayBodies.isEmpty {
            let summary = carPlayBodies.joined(separator: "  ·  ")
            DispatchQueue.main.async {
                carPlaySceneDelegate?.showAlert(title: prefix, body: summary)
            }
        }
    }

    // Notification IDs match Flutter scheme: pos.index * 10 + alertType.index
    private func notify(id: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }
        let req = UNNotificationRequest(identifier: "\(id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    private func posLabel(_ pos: String) -> String {
        ["fl": "Front Left", "fr": "Front Right", "rl": "Rear Left",
         "rr": "Rear Right", "l": "Left",         "r": "Right",
         "ml": "Middle Left","mr": "Middle Right"][pos] ?? pos.uppercased()
    }
}

// MARK: - Hex utility
private func hexBytes(_ hex: String) -> [UInt8] {
    stride(from: 0, to: hex.count, by: 2).map { i -> UInt8 in
        let s = hex.index(hex.startIndex, offsetBy: i)
        let e = hex.index(s, offsetBy: 2)
        return UInt8(hex[s..<e], radix: 16)!
    }
}
