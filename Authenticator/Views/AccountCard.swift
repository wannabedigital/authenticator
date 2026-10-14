import SwiftUI

struct AccountCard: View {
    let account: OTPAccount
    let date: Date
    let isCopied: Bool
    let onCopy: () -> Void
    let onAdvanceCounter: () -> Void

    private let cornerRadius: CGFloat = 22

    var body: some View {
        let code = account.code(at: date)
        let expiresSoon = account.kind == .totp && account.secondsRemaining(at: date) <= 5

        HStack(spacing: 14) {
            Monogram(text: account.title)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.title)
                    .font(.headline)
                    .lineLimit(1)
                if let subtitle = account.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(OTPGenerator.grouped(code))
                    .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(expiresSoon ? Color.orange : Color.primary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: code)
                    .padding(.top, 4)
            }

            Spacer(minLength: 0)

            switch account.kind {
            case .totp:
                CountdownRing(period: account.period)
            case .hotp:
                Button("Следующий код", systemImage: "arrow.clockwise", action: onAdvanceCounter)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .help("Следующий код")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect(cornerRadius: cornerRadius))
        .onTapGesture(perform: onCopy)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.tint, lineWidth: 2)
                .opacity(isCopied ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.2), value: isCopied)
        .help("Нажмите, чтобы скопировать код")
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Скопировать код", onCopy)
    }
}

/// Кружок с первой буквой сервиса; цвет стабилен для одного и того же названия.
struct Monogram: View {
    let text: String
    var size: CGFloat = 40

    private static let palette: [Color] = [.blue, .indigo, .purple, .pink, .red, .orange, .teal, .green, .mint, .cyan]

    var body: some View {
        Text(text.first.map { String($0).uppercased() } ?? "?")
            .font(.system(size: size * 0.43, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: .circle)
    }

    private var color: Color {
        let sum = text.lowercased().unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return Self.palette[sum % Self.palette.count]
    }
}

private struct CountdownRing: View {
    let period: Int

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let period = Double(max(self.period, 1))
            let remaining = period - context.date.timeIntervalSince1970.truncatingRemainder(dividingBy: period)
            let tint = remaining <= 5 ? Color.orange : Color.accentColor

            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: remaining / period)
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(remaining.rounded(.up)))")
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 30, height: 30)
        }
        .accessibilityHidden(true)
    }
}
