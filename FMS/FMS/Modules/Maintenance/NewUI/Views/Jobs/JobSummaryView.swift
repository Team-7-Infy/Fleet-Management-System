import SwiftUI

struct JobSummaryView: View {
    @StateObject private var viewModel: JobSummaryViewModel
    @ObservedObject private var navigation: TabNavigationState

    init(workOrderID: WorkOrder.ID, dependencies: AppDependencyContainer, navigation: TabNavigationState) {
        _viewModel = StateObject(wrappedValue: JobSummaryViewModel(workOrderID: workOrderID, dependencies: dependencies))
        self.navigation = navigation
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                if viewModel.state.isLoading {
                    LoadingView(title: "Loading job")
                } else if let workOrder = viewModel.workOrder {
                    jobHero(workOrder)
                    jobDetails(workOrder)
                    descriptionCard(workOrder.description)
                    PrimaryButton(title: "View Details", systemImage: AppIcon.workOrder) {
                        navigation.push(.completeWorkOrder(workOrderID: workOrder.id))
                    }
                } else {
                    MPEmptyStateView(title: "Job Unavailable", message: "This assigned job could not be loaded.", systemImage: AppIcon.jobs)
                }
            }
            .padding(AppSpacing.large)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("Job Summary")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    private func jobHero(_ workOrder: WorkOrder) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text(workOrder.id.uuidString.prefix(8).uppercased())
                        .font(AppTypography.largeTitle)
                        .minimumScaleFactor(0.75)
                    Text(workOrder.title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: AppSpacing.small) {
                    PriorityBadge(priority: workOrder.priority)
                    MPStatusBadge(status: workOrder.status)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
    }

    private func jobDetails(_ workOrder: WorkOrder) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            MPSectionHeader(title: "Assignment")
            DetailRow(title: "Due Date", value: workOrder.dueDate.shortDateTime, systemImage: "calendar")
            Divider()
            DetailRow(title: "Status", value: workOrder.status.title, systemImage: "info.circle")
        }
        .appCardStyle()
    }

    private func descriptionCard(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            MPSectionHeader(title: "Description")
            Text(description)
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
    }
}

#Preview {
    NavigationStack {
        JobSummaryView(workOrderID: PreviewData.workOrders[0].id, dependencies: .mock(), navigation: TabNavigationState())
    }
}
