import SpriteKit
import AppKit

/// Варежка или лопата рядом с курсором — когда он у снега.
/// Системный курсор над чужими окнами фоновое приложение поменять не может,
/// поэтому инструмент «держится» у курсора: появляется у снега и исчезает вдали от него.
final class CursorBadge {
    let node = SKNode()
    private var built: Tool?
    private var alpha: CGFloat = 0
    private var t: CGFloat = 0
    private var sway: CGFloat = 0

    init() {
        node.zPosition = 3.5
        node.alpha = 0
        node.isHidden = true
    }

    /// cursor — позиция курсора в сцене; show — курсор у снега; speed — скорость курсора.
    func update(dt: CGFloat, tool: Tool, cursor: CGPoint?, show: Bool, speed: CGFloat) {
        if built != tool {
            node.removeAllChildren()
            switch tool {
            case .mitten: node.addChild(CursorBadge.mitten())
            case .shovel: node.addChild(CursorBadge.shovel())
            case .none: break
            }
            built = tool
        }
        let want: CGFloat = (show && tool != .none && cursor != nil) ? 1 : 0
        alpha += (want - alpha) * min(1, dt * 10)
        node.alpha = alpha
        node.isHidden = alpha < 0.02
        guard let c = cursor else { return }
        // Правее и ниже кончика стрелки — как будто курсор держит инструмент.
        node.position = CGPoint(x: c.x + 17, y: c.y - 19)
        // Покачивается, когда им машут.
        t += dt
        let target = min(1, speed / 700) * sin(t * 16) * 0.35
        sway += (target - sway) * min(1, dt * 12)
        node.zRotation = sway
    }

    private static func shape(_ path: CGPath, _ fill: NSColor, stroke: NSColor? = nil, width: CGFloat = 1, z: CGFloat,
                              in parent: SKNode) {
        let n = SKShapeNode(path: path)
        n.fillColor = fill
        n.strokeColor = stroke ?? .clear
        n.lineWidth = stroke == nil ? 0 : width
        n.lineCap = .round
        n.lineJoin = .round
        n.zPosition = z
        parent.addChild(n)
    }

    /// Красная вязаная варежка с белой манжетой и узором.
    private static func mitten() -> SKNode {
        let n = SKNode()
        let red = NSColor(calibratedRed: 0.86, green: 0.15, blue: 0.18, alpha: 1)
        let outline = NSColor(calibratedRed: 0.45, green: 0.05, blue: 0.08, alpha: 1)
        let thumb = CGMutablePath()
        thumb.addEllipse(in: CGRect(x: -3, y: -4.5, width: 6, height: 10))
        let thumbNode = SKNode()
        thumbNode.position = CGPoint(x: -7, y: 3)
        thumbNode.zRotation = 0.6
        shape(thumb, red, stroke: outline, width: 1, z: 0, in: thumbNode)
        n.addChild(thumbNode)
        shape(CGPath(roundedRect: CGRect(x: -6.5, y: -3, width: 13, height: 18), cornerWidth: 6.5, cornerHeight: 6.5, transform: nil),
              red, stroke: outline, width: 1, z: 0.1, in: n)
        // Узор: белая полоска и «снежинки»-точки.
        shape(CGPath(rect: CGRect(x: -6.3, y: 6, width: 12.6, height: 1.6), transform: nil), .white, z: 0.2, in: n)
        for (x, y) in [(-2.5, 10.0), (2.5, 10.0), (0.0, 12.5), (-2.5, 2.5), (2.5, 2.5)] as [(CGFloat, CGFloat)] {
            shape(CGPath(ellipseIn: CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6), transform: nil), .white, z: 0.2, in: n)
        }
        shape(CGPath(roundedRect: CGRect(x: -7.5, y: -6, width: 15, height: 6.5), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil),
              NSColor(calibratedWhite: 0.97, alpha: 1), stroke: NSColor(calibratedWhite: 0.6, alpha: 1), width: 0.8, z: 0.3, in: n)
        n.zRotation = -0.25
        return n
    }

    /// Снеговая лопата: деревянный черенок с ручкой и широкий синий ковш.
    private static func shovel() -> SKNode {
        let n = SKNode()
        let wood = NSColor(calibratedRed: 0.62, green: 0.42, blue: 0.22, alpha: 1)
        let dark = NSColor(calibratedRed: 0.30, green: 0.18, blue: 0.08, alpha: 1)
        let handle = CGMutablePath()
        handle.move(to: CGPoint(x: 6, y: 16))
        handle.addLine(to: CGPoint(x: -1, y: -3))
        shape(handle, .clear, stroke: dark, width: 3.6, z: 0, in: n)
        shape(handle, .clear, stroke: wood, width: 2.2, z: 0.01, in: n)
        let grip = CGMutablePath()
        grip.move(to: CGPoint(x: 2.5, y: 17.5))
        grip.addLine(to: CGPoint(x: 9.5, y: 15))
        shape(grip, .clear, stroke: dark, width: 3.6, z: 0.02, in: n)
        shape(grip, .clear, stroke: wood, width: 2.2, z: 0.03, in: n)
        let blade = CGMutablePath()
        blade.move(to: CGPoint(x: -6.5, y: -1))
        blade.addLine(to: CGPoint(x: 4, y: -4.5))
        blade.addLine(to: CGPoint(x: 1, y: -15))
        blade.addQuadCurve(to: CGPoint(x: -12, y: -11), control: CGPoint(x: -6, y: -15.5))
        blade.closeSubpath()
        shape(blade, NSColor(calibratedRed: 0.22, green: 0.48, blue: 0.85, alpha: 1),
              stroke: NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.45, alpha: 1), width: 1, z: 0.1, in: n)
        // Снег на ковше.
        let snow = CGMutablePath()
        snow.move(to: CGPoint(x: -11, y: -11.5))
        snow.addQuadCurve(to: CGPoint(x: 0.5, y: -14), control: CGPoint(x: -5, y: -9))
        snow.addQuadCurve(to: CGPoint(x: -11, y: -11.5), control: CGPoint(x: -6, y: -15))
        shape(snow, NSColor(calibratedWhite: 0.98, alpha: 1), z: 0.2, in: n)
        return n
    }
}
