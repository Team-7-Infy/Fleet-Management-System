import Combine
import SwiftUI

struct MyJobsView: View {
    @StateObject private var viewModel: MyJobsViewModel
    @ObservedObject private var navigation: TabNavigationState
    @Environment(\.scenePhase) private var scenePhase

    init(dependencies: AppDependencyContainer, navigation: TabNavigationState) {
        _viewModel = StateObject(wrappedValue: MyJobsViewModel(dependencies: dependencies))
        self.navigation = navigation
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                controls

                if viewModel.state.isLoading {
                    LoadingView(title: "Loading jobs")
                } else if viewModel.filteredOrders.isEmpty {
                    MPEmptyStateView(title: "No Ongoing Jobs", message: "You don't have any jobs currently in progress or paused.", systemImage: AppIcon.jobs)
                } else {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        ForEach(viewModel.filteredOrders) { onHoldOrder in
                            OnHoldWorkOrderCard(onHoldOrder: onHoldOrder) {
                                navigation.push(.completeWorkOrder(workOrderID: onHoldOrder.id))
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.large)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("On Going")
        .onAppear {
            Task {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load(isRefresh: true)
        }
        .onReceive(Timer.publish(every: 20, on: .main, in: .common).autoconnect()) { _ in
            Task {
                await viewModel.load(isRefresh: true)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await viewModel.load(isRefresh: true)
            }
        }
    }


    private var controls: some View {
        VStack(spacing: AppSpacing.medium) {
            MPSearchBar(text: $viewModel.searchText, placeholder: "Search ongoing jobs")
        }
    }

}

#Preview {
    NavigationStack {
        MyJobsView(dependencies: .mock(), navigation: TabNavigationState())
    }
}
