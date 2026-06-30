import SwiftUI

enum AppAnimation {
    static let standard = Animation.snappy(duration: AppConstants.defaultAnimationDuration)
    static let gentle = Animation.easeInOut(duration: 0.2)
}
