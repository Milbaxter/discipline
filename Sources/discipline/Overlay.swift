import AppKit
import QuartzCore

// Ultra-instinct silver-blue. The aura blends this with white for the core line
// and particles, so keep it saturated here.
let focusBlue = NSColor(red: 0.62, green: 0.78, blue: 1.0, alpha: 1.0)

/// Soft radial glow dot used as the particle sprite.
private func makeGlowImage() -> CGImage? {
    let size = 32
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                                         CGColor(red: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
                                locations: [0, 1])
    else { return nil }
    let center = CGPoint(x: 16, y: 16)
    ctx.drawRadialGradient(grad, startCenter: center, startRadius: 0,
                           endCenter: center, endRadius: 16, options: [])
    return ctx.makeImage()
}

/// The aura: per-edge gradient glow, a bright core line, rising particle wisps,
/// and a slow breathing pulse. Entirely Core Animation, GPU-composited.
final class BorderView: NSView {
    var color: NSColor = focusBlue {
        didSet { if !color.isEqual(oldValue) { rebuild() } }
    }

    private var lastSize: NSSize = .zero

    override func layout() {
        super.layout()
        if bounds.size != lastSize { rebuild() }
    }

    private func rebuild() {
        guard bounds.width > 1, bounds.height > 1 else { return }
        lastSize = bounds.size
        wantsLayer = true
        guard let root = layer else { return }
        root.sublayers?.forEach { $0.removeFromSuperlayer() }
        root.masksToBounds = true

        let w = bounds.width
        let h = bounds.height
        let tint = color
        let glowDepth: CGFloat = 64

        let group = CALayer()
        group.frame = bounds

        // Glow bleeding inward from each edge.
        func gradient(_ frame: NSRect, from start: CGPoint, to end: CGPoint) -> CAGradientLayer {
            let g = CAGradientLayer()
            g.frame = frame
            g.colors = [tint.withAlphaComponent(0.40).cgColor,
                        tint.withAlphaComponent(0.10).cgColor,
                        tint.withAlphaComponent(0).cgColor]
            g.locations = [0, 0.45, 1]
            g.startPoint = start
            g.endPoint = end
            return g
        }
        group.addSublayer(gradient(NSRect(x: 0, y: h - glowDepth, width: w, height: glowDepth),
                                   from: CGPoint(x: 0.5, y: 1), to: CGPoint(x: 0.5, y: 0)))
        group.addSublayer(gradient(NSRect(x: 0, y: 0, width: w, height: glowDepth),
                                   from: CGPoint(x: 0.5, y: 0), to: CGPoint(x: 0.5, y: 1)))
        group.addSublayer(gradient(NSRect(x: 0, y: 0, width: glowDepth, height: h),
                                   from: CGPoint(x: 0, y: 0.5), to: CGPoint(x: 1, y: 0.5)))
        group.addSublayer(gradient(NSRect(x: w - glowDepth, y: 0, width: glowDepth, height: h),
                                   from: CGPoint(x: 1, y: 0.5), to: CGPoint(x: 0, y: 0.5)))

        // Bright silver core line at the very edge.
        let line = CALayer()
        line.frame = bounds.insetBy(dx: 1, dy: 1)
        line.borderWidth = 2
        line.borderColor = (tint.blended(withFraction: 0.6, of: .white) ?? tint)
            .withAlphaComponent(0.9).cgColor
        line.cornerRadius = 3
        group.addSublayer(line)

        // Rising energy wisps along each edge. Additive blending = energy look.
        if let glow = makeGlowImage() {
            func emitter(center: CGPoint, size: CGSize, angle: CGFloat) -> CAEmitterLayer {
                let e = CAEmitterLayer()
                e.frame = bounds
                e.emitterShape = .rectangle
                e.emitterMode = .volume
                e.emitterPosition = center
                e.emitterSize = size
                e.renderMode = .additive

                func cell(_ c: NSColor, alpha: CGFloat, rate: Float,
                          scale: CGFloat, speed: CGFloat) -> CAEmitterCell {
                    let cell = CAEmitterCell()
                    cell.contents = glow
                    cell.color = c.withAlphaComponent(alpha).cgColor
                    cell.birthRate = rate
                    cell.lifetime = 1.9
                    cell.lifetimeRange = 0.7
                    cell.velocity = speed
                    cell.velocityRange = speed * 0.6
                    cell.emissionLongitude = angle
                    cell.emissionRange = .pi / 5
                    cell.yAcceleration = 26 // everything drifts upward, flame-like
                    cell.scale = scale
                    cell.scaleRange = scale * 0.5
                    cell.scaleSpeed = -scale * 0.35
                    cell.alphaSpeed = -0.55
                    cell.spin = 0.6
                    cell.spinRange = 1.5
                    return cell
                }
                let rate = Float(max(size.width, size.height) / 55)
                e.emitterCells = [
                    cell(.white, alpha: 0.65, rate: rate, scale: 0.22, speed: 30),
                    cell(tint, alpha: 0.80, rate: rate * 1.4, scale: 0.34, speed: 24),
                ]
                return e
            }
            let inset: CGFloat = 6
            group.addSublayer(emitter(center: CGPoint(x: w / 2, y: inset),
                                      size: CGSize(width: w - 40, height: 4), angle: .pi / 2))
            group.addSublayer(emitter(center: CGPoint(x: w / 2, y: h - inset),
                                      size: CGSize(width: w - 40, height: 4), angle: -.pi / 2))
            group.addSublayer(emitter(center: CGPoint(x: inset, y: h / 2),
                                      size: CGSize(width: 4, height: h - 40), angle: 0))
            group.addSublayer(emitter(center: CGPoint(x: w - inset, y: h / 2),
                                      size: CGSize(width: 4, height: h - 40), angle: .pi))
        }

        // Breathing pulse over the whole aura.
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.55
        pulse.toValue = 1.0
        pulse.duration = 1.9
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        group.add(pulse, forKey: "pulse")

        root.addSublayer(group)
    }
}

/// Transparent, click-through, always-on-top window drawing the aura around the
/// visible desktop area of one screen (excludes menu bar and Dock).
final class BorderWindow: NSWindow {
    let borderView = BorderView()

    init(screen: NSScreen) {
        super.init(contentRect: screen.visibleFrame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = borderView
        setFrame(screen.visibleFrame, display: true)
        orderFrontRegardless()
    }
}

/// Small countdown pill pinned to the bottom-right of the main screen, with an
/// "unblock" button that ends the session. Non-activating: clicking it never
/// steals focus from whatever you're working in.
final class TimerWindow: NSPanel {
    private let label: NSTextField
    var onUnblock: (() -> Void)?

    init() {
        label = NSTextField(labelWithString: "00:00")
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        label.textColor = NSColor(red: 0.78, green: 0.88, blue: 1.0, alpha: 0.95)
        label.alignment = .left

        let size = NSSize(width: 172, height: 30)
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false // NSPanel default is true; would vanish when the app loses focus

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
        container.layer?.cornerRadius = 8

        label.frame = NSRect(x: 12, y: 6, width: 74, height: 18)
        container.addSubview(label)

        let button = NSButton(title: "", target: self, action: #selector(unblockClicked))
        button.isBordered = false
        button.attributedTitle = NSAttributedString(
            string: "unblock",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor(white: 1.0, alpha: 0.55),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ])
        button.frame = NSRect(x: size.width - 66, y: 5, width: 56, height: 20)
        container.addSubview(button)

        contentView = container
        reposition()
        orderFrontRegardless()
    }

    @objc private func unblockClicked() {
        onUnblock?()
    }

    func reposition() {
        guard let screen = NSScreen.main else { return }
        let v = screen.visibleFrame
        let margin: CGFloat = 14
        setFrameOrigin(NSPoint(x: v.maxX - frame.width - margin, y: v.minY + margin))
    }

    func update(text: String) {
        label.stringValue = text
    }
}

func formatInterval(_ seconds: Int) -> String {
    let s = max(0, seconds)
    if s >= 3600 {
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
    return String(format: "%02d:%02d", s / 60, s % 60)
}
