import UIKit
import CarPlay

// Reachable from AppDelegate to forward Dart data
var carPlaySceneDelegate: CarPlaySceneDelegate?

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var bgViewController: UIViewController?
    private var bgView: CarPlayBodyView?
    private var vehicles: [[String: Any]] = []

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        carPlaySceneDelegate = self
        self.interfaceController = interfaceController

        // Dark background + vehicle body shape behind the grid template
        let vc = UIViewController()
        vc.view.backgroundColor = UIColor(r: 8, g: 17, b: 28)
        let bv = CarPlayBodyView(frame: scene.carPlayWindow.bounds)
        bv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        vc.view.addSubview(bv)
        bgView = bv
        bgViewController = vc
        scene.carPlayWindow.rootViewController = vc

        refreshTemplate()
    }

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        carPlaySceneDelegate = nil
        self.interfaceController = nil
        bgView = nil
        bgViewController = nil
    }

    // MARK: - Data from Dart

    func receiveVehicles(_ data: [String: Any]) {
        if let v = data["vehicles"] as? [[String: Any]] {
            vehicles = v
        } else {
            vehicles = []
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.bgView?.update(self.vehicles)
            self.refreshTemplate()
        }
    }

    // MARK: - Template

    private func refreshTemplate() {
        guard let ic = interfaceController else { return }

        let buttons = makeButtons()

        let template: CPTemplate
        if buttons.isEmpty {
            let item = CPListItem(text: "Open FindyTPMS on your phone",
                                  detailText: "Select a vehicle to see live data")
            template = CPListTemplate(title: "FindyTPMS",
                                       sections: [CPListSection(items: [item])])
        } else {
            template = CPGridTemplate(title: "FindyTPMS", gridButtons: buttons)
        }

        ic.setRootTemplate(template, animated: false, completion: nil)
    }

    private func makeButtons() -> [CPGridButton] {
        var buttons: [CPGridButton] = []
        for vehicle in vehicles {
            guard let type = vehicle["type"] as? String,
                  let tires = vehicle["tires"] as? [String: Any] else { continue }
            let name = vehicle["name"] as? String ?? ""
            for pos in positions(type) {
                let td = tires[pos] as? [String: Any]
                let img = CarPlayTile.render(pos: pos, vehicleName: name, data: td)
                let pressure = td?["pressure"] as? Double
                let title = pressure.map { "\(pos.uppercased()) · \(String(format: "%.2f", $0)) bar" }
                           ?? pos.uppercased()
                buttons.append(CPGridButton(
                    titleVariants: [title, pos.uppercased()],
                    image: img,
                    handler: { _ in }
                ))
            }
        }
        return buttons
    }

    private func positions(_ type: String) -> [String] {
        switch type {
        case "trailer2":            return ["l", "r"]
        case "trailer6":            return ["fl", "fr", "ml", "mr", "rl", "rr"]
        default /* car/trailer4 */: return ["fl", "fr", "rl", "rr"]
        }
    }
}

// MARK: - CarPlayBodyView

/// Draws the car / trailer body shape behind the grid tiles.
class CarPlayBodyView: UIView {
    private var vehicles: [[String: Any]] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    func update(_ vehicles: [[String: Any]]) {
        self.vehicles = vehicles
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard !vehicles.isEmpty else { return }

        if vehicles.count == 1 {
            drawBody(vehicles[0], in: rect)
        } else {
            drawBody(vehicles[0], in: CGRect(x: rect.minX, y: rect.minY,
                                               width: rect.width / 2, height: rect.height))
            // Separator
            UIColor(r: 30, g: 48, b: 64).withAlphaComponent(0.6).setFill()
            UIRectFill(CGRect(x: rect.midX - 0.5, y: rect.minY + 24,
                               width: 1, height: rect.height - 48))
            drawBody(vehicles[1], in: CGRect(x: rect.midX, y: rect.minY,
                                              width: rect.width / 2, height: rect.height))
        }
    }

    private func drawBody(_ vehicle: [String: Any], in rect: CGRect) {
        let type = vehicle["type"] as? String ?? "car"
        let name = vehicle["name"] as? String ?? ""

        // Phone layout dimensions per vehicle type (from vehicle_screen.dart)
        // (layoutW × layoutH, bodyW × bodyH)
        let phW: CGFloat, phH: CGFloat   // phone total layout size
        let bW: CGFloat,  bH: CGFloat    // phone body size
        let isTrailer: Bool
        let isCar: Bool

        switch type {
        case "car":
            // SizedBox(width:340, height:392), body 120×272
            phW = 340; phH = 392; bW = 120; bH = 272
            isTrailer = false; isCar = true
        case "trailer2":
            // Row layout: TireSlot(96) + gap(10) + body(100) + gap(10) + TireSlot(96)
            // Total ≈ 312×107. We treat the body as a HORIZONTAL box.
            phW = 312; phH = 107; bW = 100; bH = 107
            isTrailer = true; isCar = false
        case "trailer4":
            // SizedBox(width:340, height:300), body 120×200
            phW = 340; phH = 300; bW = 120; bH = 200
            isTrailer = true; isCar = false
        case "trailer6":
            // SizedBox(width:340, height:460), body 120×370
            phW = 340; phH = 460; bW = 120; bH = 370
            isTrailer = true; isCar = false
        default:
            phW = 340; phH = 392; bW = 120; bH = 272
            isTrailer = false; isCar = true
        }

        let scale = min(rect.width / phW, rect.height / phH) * 0.90
        let lW = phW * scale, lH = phH * scale
        let ox = rect.minX + (rect.width  - lW) / 2
        let oy = rect.minY + (rect.height - lH) / 2

        // Vehicle name label
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor(r: 130, g: 160, b: 178),
            .kern: 2.0 as AnyObject
        ]
        let nameStr = name.uppercased() as NSString
        let nSize = nameStr.size(withAttributes: nameAttrs)
        nameStr.draw(at: CGPoint(x: rect.midX - nSize.width / 2,
                                  y: oy - 20), withAttributes: nameAttrs)

        let scaledBodyW = bW * scale
        let scaledBodyH = bH * scale
        let bodyX = ox + (lW - scaledBodyW) / 2
        let bodyY = oy + (lH - scaledBodyH) / 2

        drawCarBody(in: CGRect(x: bodyX, y: bodyY, width: scaledBodyW, height: scaledBodyH),
                    isTrailer: isTrailer, isCar: isCar)
    }

    private func drawCarBody(in r: CGRect, isTrailer: Bool, isCar: Bool = false) {
        let topR: CGFloat = isCar ? r.width * 0.48 : r.width * 0.15
        let botR: CGFloat = isCar ? r.width * 0.43 : r.width * 0.15

        let path = roundedRectPath(rect: r, topRadius: topR, bottomRadius: botR)

        // White semi-transparent fill (matches phone gradient)
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.saveGState()

        let colors = [UIColor.white.withAlphaComponent(0.10).cgColor,
                      UIColor.white.withAlphaComponent(0.03).cgColor] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: colors,
                                   locations: [0, 1])!
        ctx.addPath(path.cgPath)
        ctx.clip()
        ctx.drawLinearGradient(gradient,
                                start: CGPoint(x: r.midX, y: r.minY),
                                end:   CGPoint(x: r.midX, y: r.maxY),
                                options: [])
        ctx.restoreGState()

        // Border
        UIColor.white.withAlphaComponent(0.15).setStroke()
        path.lineWidth = 1.0
        path.stroke()

        if isCar {
            // Windshield
            let wH = r.height * 0.21
            let wPath = UIBezierPath(roundedRect: CGRect(
                x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.04,
                width: r.width * 0.76, height: wH),
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: wH * 0.5, height: wH * 0.5))
            let wColors = [AppColor.cyan.withAlphaComponent(0.14).cgColor,
                           AppColor.cyan.withAlphaComponent(0.03).cgColor] as CFArray
            let wGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: wColors, locations: [0, 1])!
            ctx.saveGState()
            ctx.addPath(wPath.cgPath)
            ctx.clip()
            ctx.drawLinearGradient(wGrad,
                                    start: CGPoint(x: r.midX, y: r.minY + r.height * 0.04),
                                    end:   CGPoint(x: r.midX, y: r.minY + r.height * 0.04 + wH),
                                    options: [])
            ctx.restoreGState()
            UIColor.white.withAlphaComponent(0.12).setStroke()
            wPath.lineWidth = 0.75
            wPath.stroke()

            // Roof
            let roofPath = UIBezierPath(roundedRect: CGRect(
                x: r.minX + r.width * 0.13, y: r.minY + r.height * 0.30,
                width: r.width * 0.74, height: r.height * 0.26),
                cornerRadius: r.width * 0.10)
            UIColor.white.withAlphaComponent(0.04).setFill()
            roofPath.fill()
            UIColor.white.withAlphaComponent(0.10).setStroke()
            roofPath.lineWidth = 0.75
            roofPath.stroke()
        }
    }

    private func roundedRectPath(rect r: CGRect,
                                  topRadius tR: CGFloat,
                                  bottomRadius bR: CGFloat) -> UIBezierPath {
        let p = UIBezierPath()
        p.move(to:    CGPoint(x: r.minX + tR, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - tR, y: r.minY))
        p.addArc(withCenter: CGPoint(x: r.maxX - tR, y: r.minY + tR),
                 radius: tR, startAngle: -.pi/2, endAngle: 0, clockwise: true)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - bR))
        p.addArc(withCenter: CGPoint(x: r.maxX - bR, y: r.maxY - bR),
                 radius: bR, startAngle: 0, endAngle: .pi/2, clockwise: true)
        p.addLine(to: CGPoint(x: r.minX + bR, y: r.maxY))
        p.addArc(withCenter: CGPoint(x: r.minX + bR, y: r.maxY - bR),
                 radius: bR, startAngle: .pi/2, endAngle: .pi, clockwise: true)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + tR))
        p.addArc(withCenter: CGPoint(x: r.minX + tR, y: r.minY + tR),
                 radius: tR, startAngle: .pi, endAngle: -.pi/2, clockwise: true)
        p.close()
        return p
    }
}

// MARK: - CarPlayTile  (tile image renderer)

enum CarPlayTile {

    static func render(pos: String, vehicleName: String, data: [String: Any]?) -> UIImage {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(pos: pos, data: data, in: CGRect(origin: .zero, size: size))
        }
    }

    private static func draw(pos: String, data: [String: Any]?, in rect: CGRect) {
        let pressure  = data?["pressure"]        as? Double
        let temp      = data?["temp"]            as? Int
        let isLow     = data?["isLow"]           as? Bool ?? false
        let connected = data?["connected"]       as? Bool ?? false
        let pHist     = data?["pressureHistory"] as? [Double] ?? []
        let tHist     = data?["tempHistory"]     as? [Double] ?? []

        let accent = isLow ? AppColor.red : AppColor.cyan
        let amber  = AppColor.amber

        // ── Background ────────────────────────────────────────────────────────
        UIColor(r: 10, g: 20, b: 32).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 14).fill()

        // Border
        accent.withAlphaComponent(0.28).setStroke()
        let border = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 13)
        border.lineWidth = 1.5
        border.stroke()

        // ── Position label ────────────────────────────────────────────────────
        text(pos.uppercased(),
             center: CGPoint(x: 100, y: 20),
             font: .systemFont(ofSize: 12, weight: .medium),
             color: UIColor(r: 130, g: 160, b: 178))

        // ── Tire circle ───────────────────────────────────────────────────────
        let cc = CGPoint(x: 100, y: 90), cr: CGFloat = 54

        // Soft glow
        accent.withAlphaComponent(0.08).setFill()
        UIBezierPath(ovalIn: CGRect(x: cc.x - cr - 6, y: cc.y - cr - 6,
                                     width: (cr + 6) * 2, height: (cr + 6) * 2)).fill()

        // Fill
        UIColor(r: 8, g: 17, b: 28).setFill()
        UIBezierPath(ovalIn: CGRect(x: cc.x - cr, y: cc.y - cr,
                                     width: cr * 2, height: cr * 2)).fill()

        // Ring
        accent.setStroke()
        let ring = UIBezierPath(ovalIn: CGRect(x: cc.x - cr, y: cc.y - cr,
                                                width: cr * 2, height: cr * 2))
        ring.lineWidth = 2.5
        ring.stroke()

        // ── Values inside circle ──────────────────────────────────────────────
        if connected, let p = pressure {
            let pStr = isLow
                ? String(format: "⚠ %.1f", p)
                : String(format: "%.2f", p)
            text(pStr,
                 center: CGPoint(x: 100, y: 82),
                 font: .monospacedDigitSystemFont(ofSize: 16, weight: .bold),
                 color: accent)
            text("bar",
                 center: CGPoint(x: 100, y: 103),
                 font: .systemFont(ofSize: 9, weight: .medium),
                 color: accent.withAlphaComponent(0.65))
        } else {
            text("—",
                 center: CGPoint(x: 100, y: 90),
                 font: .systemFont(ofSize: 20, weight: .medium),
                 color: UIColor(r: 82, g: 96, b: 111))
        }

        // ── Temperature ───────────────────────────────────────────────────────
        if connected, let t = temp {
            text("\(t)°C",
                 center: CGPoint(x: 100, y: 156),
                 font: .systemFont(ofSize: 11, weight: .medium),
                 color: amber)
        }

        // ── Sparklines ────────────────────────────────────────────────────────
        let sW: CGFloat = 168, sX: CGFloat = 16
        sparkline(pHist, in: CGRect(x: sX, y: 168, width: sW, height: 12), color: accent)
        sparkline(tHist, in: CGRect(x: sX, y: 183, width: sW, height: 12), color: amber)
    }

    // ── Sparkline ─────────────────────────────────────────────────────────────

    private static func sparkline(_ data: [Double], in rect: CGRect, color: UIColor) {
        guard data.count >= 2 else {
            let flat = UIBezierPath()
            flat.move(to:    CGPoint(x: rect.minX, y: rect.midY))
            flat.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            flat.lineWidth = 1
            color.withAlphaComponent(0.18).setStroke()
            flat.stroke()
            return
        }

        let minV = data.min()!, maxV = data.max()!
        let range = maxV - minV

        func px(_ i: Int) -> CGFloat {
            rect.minX + CGFloat(i) / CGFloat(data.count - 1) * rect.width
        }
        func py(_ v: Double) -> CGFloat {
            guard range > 0.001 else { return rect.midY }
            return rect.maxY - CGFloat((v - minV) / range) * rect.height
        }

        // Fill
        let fill = UIBezierPath()
        fill.move(to: CGPoint(x: px(0), y: py(data[0])))
        for i in 1..<data.count { fill.addLine(to: CGPoint(x: px(i), y: py(data[i]))) }
        fill.addLine(to: CGPoint(x: px(data.count - 1), y: rect.maxY))
        fill.addLine(to: CGPoint(x: px(0), y: rect.maxY))
        fill.close()
        color.withAlphaComponent(0.14).setFill()
        fill.fill()

        // Line
        let line = UIBezierPath()
        line.move(to: CGPoint(x: px(0), y: py(data[0])))
        for i in 1..<data.count { line.addLine(to: CGPoint(x: px(i), y: py(data[i]))) }
        line.lineWidth = 2.0
        line.lineCapStyle  = .round
        line.lineJoinStyle = .round
        color.setStroke()
        line.stroke()

        // Endpoint dot
        let dot = UIBezierPath(ovalIn: CGRect(x: px(data.count - 1) - 2.5,
                                               y: py(data.last!) - 2.5,
                                               width: 5, height: 5))
        color.setFill()
        dot.fill()
    }

    // ── Text helper ───────────────────────────────────────────────────────────

    private static func text(_ str: String, center p: CGPoint,
                               font: UIFont, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let sz = str.size(withAttributes: attrs)
        str.draw(at: CGPoint(x: p.x - sz.width / 2, y: p.y - sz.height / 2),
                 withAttributes: attrs)
    }
}

// MARK: - Color helpers

private enum AppColor {
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
