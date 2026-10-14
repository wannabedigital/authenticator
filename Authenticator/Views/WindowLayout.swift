import CoreGraphics

/// Размеры главного окна, согласованные между собой.
enum WindowLayout {
    static let cardMinWidth: CGFloat = 260
    static let cardSpacing: CGFloat = 16
    static let gridPadding: CGFloat = 20
    static let sidebarMaxWidth: CGFloat = 260

    /// Одна колонка карточек с полями: 300.
    static let detailMinWidth = cardMinWidth + gridPadding * 2
    /// 560 — рядом с панелью максимальной ширины остаётся место на одну колонку.
    static let minWidth = sidebarMaxWidth + detailMinWidth
    static let minHeight: CGFloat = 400
}
