import CoreGraphics

/// Размеры главного окна, согласованные между собой.
///
/// В самом узком окне сетка должна держать одинаковое число колонок и с боковой панелью,
/// и без неё — иначе при показе панели карточки перестраиваются рывком.
enum WindowLayout {
    static let cardMinWidth: CGFloat = 260
    static let cardSpacing: CGFloat = 16
    static let gridPadding: CGFloat = 20
    static let sidebarMaxWidth: CGFloat = 260

    /// Две колонки карточек с промежутком и полями: 576.
    static let detailMinWidth = cardMinWidth * 2 + cardSpacing + gridPadding * 2
    /// 836 — без панели сетке достаётся вся ширина, но для третьей колонки нужно 852,
    /// так что колонок остаётся две.
    static let minWidth = sidebarMaxWidth + detailMinWidth
    static let minHeight: CGFloat = 400
}
