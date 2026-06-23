import UIKit
import CarPlay

// Reachable from AppDelegate to forward Dart data
var carPlaySceneDelegate: CarPlaySceneDelegate?

// MARK: - CarPlaySceneDelegate

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var dashboardVC: CarPlayDashboardViewController?
    private var vehicles: [[String: Any]] = []
    private var windowBounds = CGRect(x: 0, y: 0, width: 800, height: 480)

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        carPlaySceneDelegate = self
        self.interfaceController = interfaceController
        windowBounds = scene.carWindow.bounds.isEmpty
            ? CGRect(x: 0, y: 0, width: 800, height: 480)
            : scene.carWindow.bounds

        // Full-screen custom dashboard as carWindow content
        let vc = CarPlayDashboardViewController()
        scene.carWindow.rootViewController = vc
        dashboardVC = vc

        // CPMapTemplate: its "map area" is our rootVC view; only the nav bar overlays on top
        let map = CPMapTemplate()
        map.mapButtons = []
        interfaceController.setRootTemplate(map, animated: false, completion: nil)

        if !vehicles.isEmpty { vc.update(vehicles, in: windowBounds) }
    }

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        carPlaySceneDelegate = nil
        self.interfaceController = nil
        dashboardVC = nil
    }

    func receiveVehicles(_ data: [String: Any]) {
        vehicles = (data["vehicles"] as? [[String: Any]]) ?? []
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            dashboardVC?.update(vehicles, in: windowBounds)
        }
    }
}

// MARK: - CarPlayDashboardViewController

class CarPlayDashboardViewController: UIViewController {
    private let board = CarPlayDashboardView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(r: 8, g: 17, b: 28)
        board.frame = view.bounds
        board.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(board)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        let top = view.safeAreaInsets.top
        board.topInset = top > 4 ? top : 56  // fallback: standard CarPlay nav bar ~56pt
        board.setNeedsDisplay()
    }

    func update(_ vehicles: [[String: Any]], in bounds: CGRect) {
        board.update(vehicles, in: bounds)
    }
}

// MARK: - CarPlayDashboardView
// Draws the full CarPlay screen: dark background, vehicle body silhouette, and tile tiles.

class CarPlayDashboardView: UIView {

    var topInset: CGFloat = 56   // reserved for the CarPlay nav bar overlay

    private var vehicles: [[String: Any]] = []
    private var windowBounds = CGRect(x: 0, y: 0, width: 800, height: 480)

    func update(_ vehicles: [[String: Any]], in bounds: CGRect) {
        self.vehicles = vehicles
        windowBounds = bounds
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        UIColor(r: 8, g: 17, b: 28).setFill()
        UIRectFill(rect)

        guard !vehicles.isEmpty else {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: max(14, rect.height * 0.04), weight: .medium),
                .foregroundColor: UIColor(r: 130, g: 160, b: 178)
            ]
            let s = "Open FindyTPMS on your phone" as NSString
            let sz = s.size(withAttributes: attrs)
            s.draw(at: CGPoint(x: rect.midX - sz.width/2, y: rect.midY - sz.height/2),
                   withAttributes: attrs)
            return
        }

        if vehicles.count == 1 {
            drawVehicle(vehicles[0], in: rect)
        } else {
            let half = rect.width / 2
            drawVehicle(vehicles[0], in: CGRect(x: rect.minX, y: rect.minY, width: half, height: rect.height))
            // Separator between car and trailer
            UIColor(r: 30, g: 48, b: 64).withAlphaComponent(0.6).setFill()
            UIRectFill(CGRect(x: rect.minX + half - 0.5, y: rect.minY + topInset,
                               width: 1, height: rect.height - topInset - 16))
            drawVehicle(vehicles[1], in: CGRect(x: rect.minX + half, y: rect.minY, width: half, height: rect.height))
        }
    }

    // MARK: - Vehicle section

    private func drawVehicle(_ v: [String: Any], in r: CGRect) {
        let type  = v["type"]  as? String ?? "car"
        let name  = v["name"]  as? String ?? ""
        let tires = v["tires"] as? [String: Any] ?? [:]

        // Content area begins below the CarPlay nav bar
        let contentY = r.minY + topInset
        let contentH = r.height - topInset

        // Vehicle name label, drawn just inside the content area at top
        var labelH: CGFloat = 0
        if !name.isEmpty {
            let a: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: max(10, contentH * 0.042), weight: .medium),
                .foregroundColor: UIColor(r: 130, g: 160, b: 178),
                .kern: 1.5 as AnyObject
            ]
            let ns = name.uppercased() as NSString
            let nSz = ns.size(withAttributes: a)
            labelH = nSz.height + 10
            ns.draw(at: CGPoint(x: r.midX - nSz.width/2, y: contentY + 4), withAttributes: a)
        }

        let tileR = CGRect(x: r.minX, y: contentY + labelH,
                            width: r.width, height: contentH - labelH)

        switch type {
        case "trailer2": drawLayout2(tires, in: tileR)
        case "trailer6": drawLayout6(tires, in: tileR)
        default:         drawLayout4(tires, in: tileR, type: type)
        }
    }

    // MARK: - Tile layouts

    /// car / trailer4 —  FL │ body │ FR
    ///                   RL │      │ RR
    private func drawLayout4(_ tires: [String: Any], in r: CGRect, type: String) {
        let gap  = max(6, r.width  * 0.014)
        let tW   = r.width  * 0.26
        let tH   = r.height * 0.46
        let bW   = r.width  - 2*tW - 4*gap
        let bH   = r.height - 2*gap

        let lx   = r.minX + gap
        let rx   = r.maxX - gap - tW
        let bx   = r.minX + tW + 2*gap
        let topY = r.minY + gap
        let botY = r.maxY - gap - tH
        let bY   = r.midY - bH/2

        CarPlayTile.draw(pos: "fl", data: tires["fl"] as? [String:Any],
                          in: CGRect(x:lx, y:topY, width:tW, height:tH))
        CarPlayTile.draw(pos: "fr", data: tires["fr"] as? [String:Any],
                          in: CGRect(x:rx, y:topY, width:tW, height:tH))
        CarPlayTile.draw(pos: "rl", data: tires["rl"] as? [String:Any],
                          in: CGRect(x:lx, y:botY, width:tW, height:tH))
        CarPlayTile.draw(pos: "rr", data: tires["rr"] as? [String:Any],
                          in: CGRect(x:rx, y:botY, width:tW, height:tH))
        drawBodyShape(type: type, in: CGRect(x:bx, y:bY, width:bW, height:bH))
    }

    /// trailer2 —  L │ body │ R
    private func drawLayout2(_ tires: [String: Any], in r: CGRect) {
        let gap = max(6, r.width  * 0.014)
        let tW  = r.width  * 0.28
        let tH  = r.height * 0.65
        let bW  = r.width  - 2*tW - 4*gap
        let bH  = r.height * 0.55

        let lx  = r.minX + gap
        let rx  = r.maxX - gap - tW
        let bx  = r.minX + tW + 2*gap

        CarPlayTile.draw(pos: "l", data: tires["l"] as? [String:Any],
                          in: CGRect(x:lx, y:r.midY - tH/2, width:tW, height:tH))
        CarPlayTile.draw(pos: "r", data: tires["r"] as? [String:Any],
                          in: CGRect(x:rx, y:r.midY - tH/2, width:tW, height:tH))
        drawBodyShape(type: "trailer2", in: CGRect(x:bx, y:r.midY - bH/2, width:bW, height:bH))
    }

    /// trailer6 —  FL │      │ FR
    ///             ML │ body │ MR
    ///             RL │      │ RR
    private func drawLayout6(_ tires: [String: Any], in r: CGRect) {
        let gap = max(6, r.width  * 0.012)
        let tW  = r.width  * 0.24
        let tH  = (r.height - 4*gap) / 3
        let bW  = r.width  - 2*tW - 4*gap
        let bH  = r.height - 2*gap

        let lx  = r.minX + gap
        let rx  = r.maxX - gap - tW
        let bx  = r.minX + tW + 2*gap

        for (row, pair) in [("fl","fr"), ("ml","mr"), ("rl","rr")].enumerated() {
            let y = r.minY + CGFloat(row) * (tH + gap)
            CarPlayTile.draw(pos: pair.0, data: tires[pair.0] as? [String:Any],
                              in: CGRect(x:lx, y:y, width:tW, height:tH))
            CarPlayTile.draw(pos: pair.1, data: tires[pair.1] as? [String:Any],
                              in: CGRect(x:rx, y:y, width:tW, height:tH))
        }
        drawBodyShape(type: "trailer6", in: CGRect(x:bx, y:r.midY - bH/2, width:bW, height:bH))
    }

    // MARK: - Vehicle body silhouette

    private func drawBodyShape(type: String, in r: CGRect) {
        let isCar = (type == "car")
        let topR: CGFloat = isCar ? r.width * 0.48 : r.width * 0.15
        let botR: CGFloat = isCar ? r.width * 0.43 : r.width * 0.15
        let path = bodyPath(rect: r, topRadius: topR, bottomRadius: botR)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Gradient fill
        let fc = [UIColor.white.withAlphaComponent(0.10).cgColor,
                  UIColor.white.withAlphaComponent(0.03).cgColor] as CFArray
        if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: fc, locations: [0, 1]) {
            ctx.saveGState()
            ctx.addPath(path.cgPath); ctx.clip()
            ctx.drawLinearGradient(grad,
                                    start: CGPoint(x: r.midX, y: r.minY),
                                    end:   CGPoint(x: r.midX, y: r.maxY),
                                    options: [])
            ctx.restoreGState()
        }

        // Outline
        UIColor.white.withAlphaComponent(0.15).setStroke()
        path.lineWidth = 1.0; path.stroke()

        if isCar {
            let wH = r.height * 0.21
            let wPath = UIBezierPath(roundedRect: CGRect(
                x: r.minX + r.width * 0.12,
                y: r.minY + r.height * 0.04,
                width: r.width * 0.76, height: wH),
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: wH * 0.5, height: wH * 0.5))

            let wc = [AppColor.cyan.withAlphaComponent(0.14).cgColor,
                      AppColor.cyan.withAlphaComponent(0.03).cgColor] as CFArray
            if let wg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: wc, locations: [0, 1]) {
                ctx.saveGState()
                ctx.addPath(wPath.cgPath); ctx.clip()
                ctx.drawLinearGradient(wg,
                                        start: CGPoint(x: r.midX, y: r.minY + r.height * 0.04),
                                        end:   CGPoint(x: r.midX, y: r.minY + r.height * 0.04 + wH),
                                        options: [])
                ctx.restoreGState()
            }
            UIColor.white.withAlphaComponent(0.12).setStroke()
            wPath.lineWidth = 0.75; wPath.stroke()

            // Roof
            let roofPath = UIBezierPath(roundedRect: CGRect(
                x: r.minX + r.width * 0.13,
                y: r.minY + r.height * 0.30,
                width: r.width * 0.74, height: r.height * 0.26),
                cornerRadius: r.width * 0.10)
            UIColor.white.withAlphaComponent(0.04).setFill(); roofPath.fill()
            UIColor.white.withAlphaComponent(0.10).setStroke()
            roofPath.lineWidth = 0.75; roofPath.stroke()
        }
    }

    private func bodyPath(rect r: CGRect, topRadius tR: CGFloat, bottomRadius bR: CGFloat) -> UIBezierPath {
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
