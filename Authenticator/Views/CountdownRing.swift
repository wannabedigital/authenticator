import AppKit
import SwiftUI

/// Кольцо отсчёта до смены кода.
///
/// Кольцо рисует SwiftUI, как и всю карточку, а убывающую дугу открывает маска, которую анимирует
/// Core Animation в процессе отрисовки macOS: приложение запускает эту анимацию один раз и дальше
/// не тратит на неё процессорное время. Цифра в центре обновляется вместе с кодом — секундным
/// таймером карточки.
struct CountdownRing: View {
    let period: Int
    let date: Date

    var body: some View {
        let period = TimeInterval(max(self.period, 1))
        let remaining = period - date.timeIntervalSince1970.truncatingRemainder(dividingBy: period)
        let lineWidth = CountdownArcView.lineWidth
        ZStack {
            Circle().stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .stroke(remaining <= 5 ? Color.orange : Color.accentColor, lineWidth: lineWidth)
                .mask {
                    // Дуга лежит на окружности кольца и, как его линия, выходит за рамку на половину толщины.
                    CountdownArc(period: period, date: date)
                        .padding(-lineWidth / 2)
                }
            Text("\(Int(remaining.rounded(.up)))")
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }
}

private struct CountdownArc: NSViewRepresentable {
    let period: TimeInterval
    /// Секундный тик: с ним дуга заодно сверяется с часами.
    let date: Date

    func makeNSView(context: Context) -> CountdownArcView {
        CountdownArcView()
    }

    func updateNSView(_ view: CountdownArcView, context: Context) {
        view.update(period: period)
    }
}

/// Дуга от «12 часов» по часовой стрелке. Убывает от полной окружности до нуля за период
/// и начинается заново — ровно на границе периода по часам.
final class CountdownArcView: NSView {
    static let lineWidth: CGFloat = 3
    private static let animationKey = "countdown"

    private var arc: CAShapeLayer { layer as! CAShapeLayer }
    private var period: TimeInterval = 30
    /// Разница между часами и временем Core Animation, с которой запущена анимация.
    /// Меняется, только если перевели часы или Mac спал, — тогда анимацию надо запустить заново.
    private var clockOffset: TimeInterval?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        arc.fillColor = nil
        // Дуга служит маской, поэтому важна только непрозрачность: цвет кольцу задаёт SwiftUI.
        arc.strokeColor = .black
        arc.lineWidth = Self.lineWidth
        arc.lineCap = .round
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Вызывается каждую секунду. Анимацию запускает заново, только если она разошлась с часами.
    func update(period: TimeInterval) {
        if period != self.period || !isAnimationInSync {
            self.period = period
            startAnimation()
        }
    }

    override func makeBackingLayer() -> CALayer {
        CAShapeLayer()
    }

    // Кольцо — только оформление: щелчки проходят к карточке.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updatePath()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { startAnimation() }
    }

    private var currentClockOffset: TimeInterval {
        Date.now.timeIntervalSince1970 - CACurrentMediaTime()
    }

    private var isAnimationInSync: Bool {
        guard let clockOffset, arc.animation(forKey: Self.animationKey) != nil else { return false }
        return abs(currentClockOffset - clockOffset) < 0.25
    }

    private func startAnimation() {
        let offset = currentClockOffset
        let mediaTime = CACurrentMediaTime()
        let elapsed = (mediaTime + offset).truncatingRemainder(dividingBy: period)
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 1
        animation.toValue = 0
        animation.duration = period
        animation.repeatCount = .infinity
        animation.beginTime = arc.convertTime(mediaTime, from: nil) - elapsed
        // За кадр дуга сдвигается на доли пикселя, частые кадры ей не нужны.
        animation.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 30, preferred: 15)
        arc.add(animation, forKey: Self.animationKey)
        clockOffset = offset
    }

    private func updatePath() {
        let side = min(bounds.width, bounds.height) - Self.lineWidth
        guard side > 0 else { return }
        let path = CGMutablePath()
        path.addArc(
            center: CGPoint(x: bounds.midX, y: bounds.midY), radius: side / 2,
            startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true
        )
        arc.path = path
    }
}
