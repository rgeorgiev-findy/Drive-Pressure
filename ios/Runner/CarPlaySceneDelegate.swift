import UIKit
import CarPlay

// Reachable from AppDelegate to forward Dart data
var carPlaySceneDelegate: CarPlaySceneDelegate?

// MARK: - CarPlaySceneDelegate

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var vehicles: [[String: Any]] = []

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        carPlaySceneDelegate = self
        self.interfaceController = interfaceController
        interfaceController.setRootTemplate(buildTemplate(), animated: false, completion: nil)
    }

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        carPlaySceneDelegate = nil
        self.interfaceController = nil
    }

    func receiveVehicles(_ data: [String: Any]) {
        vehicles = (data["vehicles"] as? [[String: Any]]) ?? []
        DispatchQueue.main.async { [weak self] in
            guard let self, let ic = self.interfaceController else { return }
            ic.setRootTemplate(self.buildTemplate(), animated: false, completion: nil)
        }
    }

    // MARK: - Template builder

    private func buildTemplate() -> CPTemplate {
        guard !vehicles.isEmpty else { return waitingTemplate() }
        if vehicles.count >= 2 {
            let tabs = Array(vehicles.prefix(5)).map { gridTemplate(for: $0) }
            return CPTabBarTemplate(templates: tabs)
        }
        return gridTemplate(for: vehicles[0])
    }

    private func waitingTemplate() -> CPGridTemplate {
        let cfg = UIImage.SymbolConfiguration(pointSize: 64, weight: .medium)
        let icon = (UIImage(systemName: "antenna.radiowaves.left.and.right", withConfiguration: cfg)
            ?? UIImage()).withTintColor(AppColor.cyan, renderingMode: .alwaysOriginal)
        let btn = CPGridButton(titleVariants: ["Open FindyTPMS on your phone"], image: icon) { _ in }
        return CPGridTemplate(title: "FindyTPMS", gridButtons: [btn])
    }

    private func gridTemplate(for vehicle: [String: Any]) -> CPGridTemplate {
        let name  = vehicle["name"]  as? String        ?? "Vehicle"
        let type  = vehicle["type"]  as? String        ?? "car"
        let tires = vehicle["tires"] as? [String: Any] ?? [:]

        let buttons = tirePositions(for: type).map { pos -> CPGridButton in
            let img = renderTile(pos: pos, data: tires[pos] as? [String: Any])
            return CPGridButton(titleVariants: [pos.uppercased()], image: img) { _ in }
        }
        return CPGridTemplate(title: name, gridButtons: buttons)
    }

    private func tirePositions(for type: String) -> [String] {
        switch type {
        case "trailer2": return ["l", "r"]
        case "trailer6": return ["fl", "ml", "rl", "fr", "mr", "rr"]
        default:         return ["fl", "fr", "rl", "rr"]
        }
    }

    // Renders one tile to UIImage using the same Core Graphics logic as CarPlayTile
    private func renderTile(pos: String, data: [String: Any]?) -> UIImage {
        let side = CGFloat(300)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
            .image { _ in
                CarPlayTile.draw(pos: pos, data: data,
                                 in: CGRect(x: 0, y: 0, width: side, height: side))
            }
            .withRenderingMode(.alwaysOriginal)
    }
}

// MARK: - CarPlayTile  (draws directly into the current Core Graphics context)

enum CarPlayTile {

    static func draw(pos: String, data: [String: Any]?, in rect: CGRect) {
        let pressure  = data?["pressure"]        as? Double
        let temp      = (data?["temp"] as? Int) ?? (data?["temp"] as? Double).map { Int($0) }
        let isLow     = data?["isLow"]           as? Bool ?? false
        let connected = data?["connected"]       as? Bool ?? false
        let pHist     = data?["pressureHistory"] as? [Double] ?? []
        let tHist     = data?["tempHistory"]     as? [Double] ?? []

        let accent = isLow ? AppColor.red : AppColor.cyan
        let W = rect.width, H = rect.height

        // ── Background ─────────────────────────────────────────────────────────
        let cornerR = max(8, H * 0.06)
        UIColor(r: 10, g: 20, b: 32).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: cornerR).fill()

        accent.withAlphaComponent(0.28).setStroke()
        let border = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: cornerR - 1)
        border.lineWidth = 1.5; border.stroke()

        // ── Position label ─────────────────────────────────────────────────────
        label(pos.uppercased(),
              at: CGPoint(x: rect.minX + W/2, y: rect.minY + H * 0.09),
              font: .systemFont(ofSize: max(9, H * 0.065), weight: .medium),
              color: UIColor(r: 130, g: 160, b: 178))

        // ── Tire circle ────────────────────────────────────────────────────────
        let cr  = min(W * 0.38, H * 0.32)
        let cc  = CGPoint(x: rect.minX + W/2, y: rect.minY + H * 0.42)
        let gPd = cr * 0.11

        accent.withAlphaComponent(0.08).setFill()
        UIBezierPath(ovalIn: CGRect(x: cc.x - cr - gPd, y: cc.y - cr - gPd,
                                     width: (cr+gPd)*2, height: (cr+gPd)*2)).fill()
        UIColor(r: 8, g: 17, b: 28).setFill()
        UIBezierPath(ovalIn: CGRect(x: cc.x - cr, y: cc.y - cr, width: cr*2, height: cr*2)).fill()
        accent.setStroke()
        let ring = UIBezierPath(ovalIn: CGRect(x: cc.x - cr, y: cc.y - cr, width: cr*2, height: cr*2))
        ring.lineWidth = max(1.5, cr * 0.046); ring.stroke()

        // ── Values ─────────────────────────────────────────────────────────────
        if connected, let p = pressure {
            let pStr = isLow ? String(format: "⚠ %.1f", p) : String(format: "%.2f", p)
            label(pStr,
                  at: CGPoint(x: cc.x, y: cc.y - cr * 0.13),
                  font: .monospacedDigitSystemFont(ofSize: max(10, cr * 0.30), weight: .bold),
                  color: accent)
            label("bar",
                  at: CGPoint(x: cc.x, y: cc.y + cr * 0.28),
                  font: .systemFont(ofSize: max(7, cr * 0.16), weight: .medium),
                  color: accent.withAlphaComponent(0.65))
        } else {
            label("—", at: cc,
                  font: .systemFont(ofSize: max(14, cr * 0.38), weight: .medium),
                  color: UIColor(r: 82, g: 96, b: 111))
        }

        // ── Temperature ────────────────────────────────────────────────────────
        if connected, let t = temp {
            label("\(t)°C",
                  at: CGPoint(x: rect.minX + W/2, y: rect.minY + H * 0.79),
                  font: .systemFont(ofSize: max(8, H * 0.055), weight: .medium),
                  color: AppColor.amber)
        }

        // ── Sparklines ─────────────────────────────────────────────────────────
        let sX = rect.minX + W * 0.07
        let sW = W * 0.86
        let sH = max(6, H * 0.055)
        sparkline(pHist, in: CGRect(x: sX, y: rect.minY + H * 0.855, width: sW, height: sH), color: accent)
        sparkline(tHist, in: CGRect(x: sX, y: rect.minY + H * 0.920, width: sW, height: sH), color: AppColor.amber)
    }

    private static func sparkline(_ data: [Double], in r: CGRect, color: UIColor) {
        guard data.count >= 2 else {
            let flat = UIBezierPath()
            flat.move(to: CGPoint(x: r.minX, y: r.midY))
            flat.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            flat.lineWidth = 1
            color.withAlphaComponent(0.18).setStroke(); flat.stroke()
            return
        }

        let minV = data.min()!, maxV = data.max()!, range = maxV - minV
        func px(_ i: Int) -> CGFloat { r.minX + CGFloat(i) / CGFloat(data.count - 1) * r.width }
        func py(_ v: Double) -> CGFloat {
            guard range > 0.001 else { return r.midY }
            return r.maxY - CGFloat((v - minV) / range) * r.height
        }

        let fill = UIBezierPath()
        fill.move(to: CGPoint(x: px(0), y: py(data[0])))
        for i in 1..<data.count { fill.addLine(to: CGPoint(x: px(i), y: py(data[i]))) }
        fill.addLine(to: CGPoint(x: px(data.count-1), y: r.maxY))
        fill.addLine(to: CGPoint(x: px(0), y: r.maxY)); fill.close()
        color.withAlphaComponent(0.14).setFill(); fill.fill()

        let line = UIBezierPath()
        line.move(to: CGPoint(x: px(0), y: py(data[0])))
        for i in 1..<data.count { line.addLine(to: CGPoint(x: px(i), y: py(data[i]))) }
        line.lineWidth = 2.0; line.lineCapStyle = .round; line.lineJoinStyle = .round
        color.setStroke(); line.stroke()

        let last = data.count - 1
        color.setFill()
        UIBezierPath(ovalIn: CGRect(x: px(last) - 2.5, y: py(data[last]) - 2.5, width: 5, height: 5)).fill()
    }

    private static func label(_ str: String, at center: CGPoint, font: UIFont, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let sz = str.size(withAttributes: attrs)
        str.draw(at: CGPoint(x: center.x - sz.width/2, y: center.y - sz.height/2),
                 withAttributes: attrs)
    }
}

// MARK: - Color helpers

enum AppColor {
    static let cyan  = UIColor(r: 52,  g: 227, b: 255)
    static let amber = UIColor(r: 255, g: 176, b: 46)
    static let red   = UIColor(r: 255, g: 84,  b: 112)
}

extension UIColor {
    convenience init(r: Int, g: Int, b: Int) {
        self.init(red: CGFloat(r) / 255,
                  green: CGFloat(g) / 255,
                  blue: CGFloat(b) / 255,
                  alpha: 1)
    }
}
