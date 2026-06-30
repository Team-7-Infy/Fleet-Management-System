import SwiftUI

struct AppRootView: View {
    let dependencies: AppDependencyContainer

    var body: some View {
        RootTabView(dependencies: dependencies)
            .tint(AppColor.brand)
    }
}

#Preview {
    AppRootView(dependencies: .mock())
}
