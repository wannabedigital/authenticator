import SwiftUI

/// Значок профиля: белый символ в цветном круге, как у списков в «Напоминаниях».
struct ProfileIcon: View {
    let symbol: String
    let color: ProfileColor
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.color.gradient, in: .circle)
            .accessibilityHidden(true)
    }
}

extension ProfileIcon {
    init(profile: Profile, size: CGFloat = 22) {
        self.init(symbol: profile.symbol, color: profile.color, size: size)
    }

    static let symbols = [
        "person.fill", "person.2.fill", "briefcase.fill", "building.2.fill", "house.fill", "graduationcap.fill", "heart.fill",
        "chevron.left.forwardslash.chevron.right", "terminal.fill", "server.rack", "cloud.fill", "globe", "envelope.fill", "bubble.left.fill",
        "cart.fill", "creditcard.fill", "banknote.fill", "bitcoinsign.circle.fill", "chart.line.uptrend.xyaxis", "gamecontroller.fill", "music.note",
        "camera.fill", "airplane", "car.fill", "pawprint.fill", "leaf.fill", "star.fill", "flag.fill",
        "lock.fill", "key.fill", "shield.fill", "wrench.and.screwdriver.fill", "hammer.fill", "bolt.fill", "flame.fill",
    ]
}

extension ProfileColor {
    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        case .gray: .gray
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .red: "Красный"
        case .orange: "Оранжевый"
        case .yellow: "Жёлтый"
        case .green: "Зелёный"
        case .mint: "Мятный"
        case .teal: "Бирюзовый"
        case .cyan: "Голубой"
        case .blue: "Синий"
        case .indigo: "Индиго"
        case .purple: "Фиолетовый"
        case .pink: "Розовый"
        case .brown: "Коричневый"
        case .gray: "Серый"
        }
    }
}
