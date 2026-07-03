import SwiftUI

struct AppRootView: View {
    let dependencies: AppDependencyContainer
    let notificationViewModel: NotificationViewModel

    var body: some View {
        RootTabView(dependencies: dependencies, notificationViewModel: notificationViewModel)
            .tint(AppColor.brand)
    }
}

#Preview {
    AppRootView(
        dependencies: .mock(),
        notificationViewModel: NotificationViewModel(
            notificationService: NotificationService(supabase: SupabaseService()),
            recipientId: nil
        )
    )
}
