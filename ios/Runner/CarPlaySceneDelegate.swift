import UIKit
import CarPlay

var carPlaySceneDelegate: CarPlaySceneDelegate?

// MARK: - Scene delegate

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var vehicles: [[String: Any]] = []
    private var _alertPresenting = false

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        NSLog("🚗 CarPlay didConnect")
        carPlaySceneDelegate = self
        self.interfaceController = interfaceController
        let tmpl = buildTemplate()
        NSLog("🚗 CarPlay setRootTemplate: %@", String(describing: type(of: tmpl)))
        interfaceController.setRootTemplate(tmpl, animated: false, completion: nil)
        appCarPlayChannel?.invokeMethod("connected", arguments: nil)
    }

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        appCarPlayChannel?.invokeMethod("disconnected", arguments: nil)
        carPlaySceneDelegate = nil
        self.interfaceController = nil
        _alertPresenting = false
    }

    func showAlert(title: String, body: String) {
        guard let ic = interfaceController, !_alertPresenting else { return }
        _alertPresenting = true
        let dismiss = CPAlertAction(title: "OK", style: .cancel) { [weak self, weak ic] _ in
            ic?.dismissTemplate(animated: true, completion: nil)
            DispatchQueue.main.async { self?._alertPresenting = false }
        }
        let full  = body.isEmpty ? title : "\(title) — \(body)"
        let alert = CPAlertTemplate(titleVariants: [full, title], actions: [dismiss])
        ic.presentTemplate(alert, animated: true) { [weak self] success, _ in
            if !success { DispatchQueue.main.async { self?._alertPresenting = false } }
        }
    }

    func receiveVehicles(_ data: [String: Any]) {
        vehicles = (data["vehicles"] as? [[String: Any]]) ?? []
        DispatchQueue.main.async { [weak self] in
            guard let self, let ic = self.interfaceController else { return }
            ic.setRootTemplate(self.buildTemplate(), animated: false, completion: nil)
        }
    }

    // MARK: - Template building

    private func buildTemplate() -> CPTemplate {
        guard !vehicles.isEmpty else { return waitingTemplate() }
        if #available(iOS 26.0, *) {
            return cardListTemplate(vehicles: vehicles)
        }
        return gridTemplate(for: vehicles[0])
    }

    private func waitingTemplate() -> CPGridTemplate {
        let cfg = UIImage.SymbolConfiguration(pointSize: 64, weight: .medium)
        let icon = (UIImage(systemName: "antenna.radiowaves.left.and.right",
                            withConfiguration: cfg) ?? UIImage())
            .withTintColor(CPColor.cyan, renderingMode: .alwaysOriginal)
        let btn = CPGridButton(titleVariants: ["FindyTPMS"], image: icon) { _ in }
        return CPGridTemplate(title: "FindyTPMS — Waiting…", gridButtons: [btn])
    }

    // iOS 26+: 4 tires per row. Each vehicle gets its own CPListSection.
    // Car = 1 row of 4, trailer4 = 1 row of 4, trailer6 = 2 rows (4+2), trailer2 = 1 row of 2.
    @available(iOS 26.0, *)
    private func cardListTemplate(vehicles: [[String: Any]]) -> CPListTemplate {
        let raw = CPListImageRowItemCardElement.maximumFullHeightImageSize
        let tileSize = (raw.width > 10 && raw.height > 10) ? raw : CGSize(width: 160, height: 240)
        NSLog("🚗 maximumFullHeightImageSize: %.0f×%.0f", tileSize.width, tileSize.height)

        let multiVehicle = vehicles.count > 1
        var sections: [CPListSection] = []

        for vehicle in vehicles {
            let name  = vehicle["name"]  as? String        ?? "Vehicle"
            let tires = vehicle["tires"] as? [String: Any] ?? [:]
            let type  = vehicle["type"]  as? String        ?? "car"

            let positions = orderedPositions(for: type)
            // 4 tires per row — fills full content width
            let rows = stride(from: 0, to: positions.count, by: 4).map {
                Array(positions[$0 ..< min($0 + 4, positions.count)])
            }

            let rowItems: [CPListImageRowItem] = rows.map { row in
                let cards = row.map { pos -> CPListImageRowItemCardElement in
                    let tireData = tires[pos] as? [String: Any]
                    // All content (sparklines + value strip) is drawn inside the image.
                    // title/subtitle are nil to avoid overlapping with showsImageFullHeight.
                    let img = TireTile.render(pos: pos, data: tireData, size: tileSize)
                    return CPListImageRowItemCardElement(
                        image: img,
                        showsImageFullHeight: true,
                        title: nil,
                        subtitle: nil,
                        tintColor: nil
                    )
                }
                return CPListImageRowItem(text: nil, cardElements: cards,
                                          allowsMultipleLines: false)
            }

            sections.append(CPListSection(items: rowItems,
                                          header: multiVehicle ? name : nil,
                                          sectionIndexTitle: nil))
        }

        return CPListTemplate(title: nil, sections: sections)
    }

    // Canonical tire order per vehicle type (matches physical layout).
    private func orderedPositions(for type: String) -> [String] {
        switch type {
        case "trailer2":
            return ["l", "r"]
        case "trailer6":
            return ["fl", "fr", "ml", "mr", "rl", "rr"]
        default: // car, trailer4
            return ["fl", "fr", "rl", "rr"]
        }
    }

    // Fallback for iOS < 26 — shows first vehicle only (CPGridTemplate limit)
    private func gridTemplate(for vehicle: [String: Any]) -> CPGridTemplate {
        let name  = vehicle["name"]  as? String        ?? "Vehicle"
        let tires = vehicle["tires"] as? [String: Any] ?? [:]
        let type  = vehicle["type"]  as? String        ?? "car"
        let tileSize = CGSize(width: 320, height: 240)
        let buttons = orderedPositions(for: type).prefix(8).map { pos -> CPGridButton in
            let img = TireTile.render(pos: pos, data: tires[pos] as? [String: Any], size: tileSize)
            return CPGridButton(titleVariants: [pos.uppercased()], image: img) { _ in }
        }
        return CPGridTemplate(title: name, gridButtons: Array(buttons))
    }
}

// MARK: - Tile image renderer

enum TireTile {

    static func render(pos: String, data: [String: Any]?, size: CGSize) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 2
        return UIGraphicsImageRenderer(size: size, format: fmt)
            .image { _ in draw(pos: pos, data: data, in: CGRect(origin: .zero, size: size)) }
            .withRenderingMode(.alwaysOriginal)
    }

    static func draw(pos: String, data: [String: Any]?, in r: CGRect) {
        let pressure  = data?["pressure"]        as? Double
        let temp      = (data?["temp"] as? Int) ?? (data?["temp"] as? Double).map { Int($0) }
        let isLow     = data?["isLow"]           as? Bool ?? false
        let connected = data?["connected"]       as? Bool ?? false
        let pHist     = data?["pressureHistory"] as? [Double] ?? []
        let tHist     = data?["tempHistory"]     as? [Double] ?? []

        let accent = isLow ? CPColor.red : CPColor.cyan
        let W = r.width, H = r.height
        let pad: CGFloat = 5

        // Layout (top→bottom):
        //   value strip  ~22% of H  ← pos label centred, pressure left, temp right
        //   pressure sparkline  ~39% of H
        //   temperature sparkline ~39% of H
        let valH:  CGFloat = H * 0.22
        let spkH:  CGFloat = (H - valH) * 0.50
        let valY   = r.minY
        let pSpkY  = r.minY + valH
        let tSpkY  = pSpkY + spkH

        // ── Background ───────────────────────────────────────────────────────
        UIColor(r: 8, g: 12, b: 16).setFill()
        UIBezierPath(rect: r).fill()

        // Value strip — slightly lighter background
        UIColor(r: 13, g: 16, b: 22).setFill()
        UIBezierPath(rect: CGRect(x: r.minX, y: valY, width: W, height: valH)).fill()

        // Outer border
        accent.withAlphaComponent(isLow ? 0.80 : 0.25).setStroke()
        UIBezierPath(rect: r.insetBy(dx: 1.5, dy: 1.5)).do { $0.lineWidth = 3; $0.stroke() }

        // Divider between value strip and sparklines
        accent.withAlphaComponent(0.18).setStroke()
        let div = UIBezierPath()
        div.move(to: CGPoint(x: r.minX + 4, y: pSpkY))
        div.addLine(to: CGPoint(x: r.maxX - 4, y: pSpkY))
        div.lineWidth = 1; div.stroke()

        // Mid divider between the two sparklines
        UIColor(white: 1, alpha: 0.07).setStroke()
        let mid = UIBezierPath()
        mid.move(to: CGPoint(x: r.minX + 6, y: tSpkY))
        mid.addLine(to: CGPoint(x: r.maxX - 6, y: tSpkY))
        mid.lineWidth = 0.5; mid.stroke()

        // ── Pressure sparkline ───────────────────────────────────────────────
        drawSparkline(pHist,
                      in: CGRect(x: r.minX + pad, y: pSpkY + pad,
                                 width: W - 2 * pad, height: spkH - 2 * pad),
                      color: accent)

        // ── Temperature sparkline ────────────────────────────────────────────
        drawSparkline(tHist,
                      in: CGRect(x: r.minX + pad, y: tSpkY + pad,
                                 width: W - 2 * pad, height: spkH - 2 * pad),
                      color: CPColor.amber)

        // ── Value strip: pressure left · position centre · temperature right ──
        let valMidY  = valY + valH * 0.50
        let fontSize = valH * 0.50

        // Pressure value — left
        let pStr: String
        let pColor: UIColor
        if connected, let p = pressure {
            pStr   = String(format: "%.2f", p)
            pColor = isLow ? CPColor.red : .white
        } else {
            pStr   = "—"
            pColor = UIColor(white: 1, alpha: 0.25)
        }
        let pFont = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold)
        let pSz   = pStr.size(withAttributes: [.font: pFont])
        pStr.draw(at: CGPoint(x: r.minX + W * 0.05, y: valMidY - pSz.height / 2),
                  withAttributes: [.font: pFont, .foregroundColor: pColor])

        // "bar" unit — small, right of pressure number
        let uFont = UIFont.systemFont(ofSize: fontSize * 0.52, weight: .regular)
        let uSz   = "bar".size(withAttributes: [.font: uFont])
        "bar".draw(at: CGPoint(x: r.minX + W * 0.05 + pSz.width + 2,
                               y: valMidY - uSz.height / 2 + pSz.height * 0.14),
                   withAttributes: [.font: uFont,
                                    .foregroundColor: accent.withAlphaComponent(0.55)])

        // Position label — centred
        let posFont = UIFont.systemFont(ofSize: fontSize * 0.85, weight: .black)
        let posStr  = pos.uppercased()
        let posSz   = posStr.size(withAttributes: [.font: posFont])
        posStr.draw(at: CGPoint(x: r.minX + (W - posSz.width) / 2, y: valMidY - posSz.height / 2),
                    withAttributes: [.font: posFont,
                                     .foregroundColor: accent.withAlphaComponent(0.75)])

        // Temperature value — right
        let tStr: String
        let tColor: UIColor
        if connected, let t = temp {
            tStr   = "\(t)°"
            tColor = CPColor.amber
        } else {
            tStr   = "—"
            tColor = UIColor(white: 1, alpha: 0.25)
        }
        let tFont = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let tSz   = tStr.size(withAttributes: [.font: tFont])
        tStr.draw(at: CGPoint(x: r.maxX - W * 0.05 - tSz.width, y: valMidY - tSz.height / 2),
                  withAttributes: [.font: tFont, .foregroundColor: tColor])
    }

    // MARK: - Drawing helpers

    private static func drawArc(_ c: CGPoint, _ r: CGFloat,
                                  _ from: CGFloat, _ to: CGFloat,
                                  _ lw: CGFloat, _ color: UIColor) {
        let p = UIBezierPath()
        p.addArc(withCenter: c, radius: r, startAngle: from, endAngle: to, clockwise: true)
        p.lineWidth = lw; p.lineCapStyle = .round
        color.setStroke(); p.stroke()
    }

    static func drawSparkline(_ data: [Double], in r: CGRect, color: UIColor) {
        guard r.height > 2, r.width > 4 else { return }
        guard data.count >= 2 else {
            let flat = UIBezierPath()
            flat.move(to: CGPoint(x: r.minX, y: r.midY))
            flat.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            flat.lineWidth = 1; color.withAlphaComponent(0.14).setStroke(); flat.stroke()
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
        fill.addLine(to: CGPoint(x: px(data.count - 1), y: r.maxY))
        fill.addLine(to: CGPoint(x: px(0), y: r.maxY)); fill.close()
        color.withAlphaComponent(0.18).setFill(); fill.fill()
        let line = UIBezierPath()
        line.move(to: CGPoint(x: px(0), y: py(data[0])))
        for i in 1..<data.count { line.addLine(to: CGPoint(x: px(i), y: py(data[i]))) }
        line.lineWidth = 2.5; line.lineCapStyle = .round; line.lineJoinStyle = .round
        color.setStroke(); line.stroke()
        let last = data.count - 1
        color.setFill()
        UIBezierPath(ovalIn: CGRect(x: px(last) - 3.5, y: py(data[last]) - 3.5,
                                     width: 7, height: 7)).fill()
    }

    private static func drawLabel(_ str: String, at c: CGPoint, font: UIFont, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let sz = str.size(withAttributes: attrs)
        str.draw(at: CGPoint(x: c.x - sz.width/2, y: c.y - sz.height/2), withAttributes: attrs)
    }
}

// MARK: - Dashboard compositor

enum TireDashboard {

    /// Renders all tires for one vehicle into a single image the size of the full CarPlay card.
    /// 2-column grid, centered, gaps are minimal so tiles are as large as possible.
    static func render(positions: [String], tires: [String: Any], size: CGSize) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2
        return UIGraphicsImageRenderer(size: size, format: fmt)
            .image { _ in draw(positions: positions, tires: tires, in: CGRect(origin: .zero, size: size)) }
            .withRenderingMode(.alwaysOriginal)
    }

    private static func draw(positions: [String], tires: [String: Any], in r: CGRect) {
        UIColor(r: 8, g: 12, b: 16).setFill()
        UIBezierPath(rect: r).fill()

        let cols  = 2
        let rows  = (positions.count + cols - 1) / cols
        let gap: CGFloat = 6
        let pad: CGFloat = 6

        let tileW = (r.width  - 2 * pad - CGFloat(cols - 1) * gap) / CGFloat(cols)
        let tileH = (r.height - 2 * pad - CGFloat(rows - 1) * gap) / CGFloat(rows)

        // Full grid dimensions (used for centering)
        let gridW = CGFloat(cols) * tileW + CGFloat(cols - 1) * gap
        let gridH = CGFloat(rows) * tileH + CGFloat(rows - 1) * gap
        let originX = r.minX + (r.width  - gridW) / 2
        let originY = r.minY + (r.height - gridH) / 2

        for (i, pos) in positions.enumerated() {
            let col = CGFloat(i % cols)
            let row = CGFloat(i / cols)

            // If last tile is alone in its row, center it horizontally
            var x = originX + col * (tileW + gap)
            if positions.count % cols != 0 && i == positions.count - 1 {
                x = r.minX + (r.width - tileW) / 2
            }
            let y = originY + row * (tileH + gap)

            TireTile.draw(pos: pos,
                          data: tires[pos] as? [String: Any],
                          in: CGRect(x: x, y: y, width: tileW, height: tileH))
        }
    }
}

// MARK: - Colors & extensions

enum CPColor {
    static let cyan  = UIColor(r: 255, g: 106, b: 24)   // orange #FF6A18 (matches app theme)
    static let amber = UIColor(r: 255, g: 176, b: 46)
    static let red   = UIColor(r: 255, g: 84,  b: 112)
}

extension UIColor {
    convenience init(r: Int, g: Int, b: Int) {
        self.init(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
    }
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

extension UIBezierPath {
    @discardableResult func `do`(_ b: (UIBezierPath) -> Void) -> UIBezierPath { b(self); return self }
}
