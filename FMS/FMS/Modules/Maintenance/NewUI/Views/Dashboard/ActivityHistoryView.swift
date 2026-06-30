import SwiftUI

struct ActivityHistoryView: View {
    @StateObject private var viewModel: ActivityHistoryViewModel

    init(dependencies: AppDependencyContainer) {
        _viewModel = StateObject(wrappedValue: ActivityHistoryViewModel(dependencies: dependencies))
    }

    var body: some View {
        List {
            if viewModel.state.isLoading {
                LoadingView(title: "Loading activity")
                    .listRowBackground(Color.clear)
            } else if viewModel.activities.isEmpty {
                MPEmptyStateView(title: "No Activity", message: "Maintenance updates will appear here.", systemImage: AppIcon.activity)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.groupedActivities, id: \.header) { group in
                    Section {
                        ForEach(group.activities) { activity in
                            ActivityRow(activity: activity)
                                .padding(.vertical, AppSpacing.small)
                        }
                    } header: {
                        Text(group.header)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("Activity History")
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        ActivityHistoryView(dependencies: .mock())
    }
}
