import SwiftUI

struct AppShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let card = AppShadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
}
