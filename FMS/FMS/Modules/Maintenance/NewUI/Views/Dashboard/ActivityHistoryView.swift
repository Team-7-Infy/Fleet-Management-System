import SwiftUI

struct ActivityHistoryView: View {
    @StateObject private var viewModel: ActivityHistoryViewModel
    @State private var showFlaggedOnly = false

    init(dependencies: AppDependencyContainer) {
        _viewModel = StateObject(wrappedValue: ActivityHistoryViewModel(dependencies: dependencies))
    }

    private var filteredActivities: [Activity] {
        if showFlaggedOnly {
            return viewModel.activities.filter { $0.status == .fake }
        }
        return viewModel.activities
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
                let filtered = filteredActivities
                if filtered.isEmpty {
                    MPEmptyStateView(title: "No Flagged Items", message: "There are no flagged work orders.", systemImage: "flag.slash")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.groupedActivities(for: filtered), id: \.header) { group in
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
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("Activity History")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showFlaggedOnly.toggle()
                    }
                } label: {
                    Label("Flagged", systemImage: showFlaggedOnly ? "flag.fill" : "flag")
                        .symbolEffect(.bounce, value: showFlaggedOnly)
                        .foregroundStyle(showFlaggedOnly ? .red : .secondary)
                }
            }
        }
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