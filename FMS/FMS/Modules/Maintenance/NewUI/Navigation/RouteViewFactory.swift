import SwiftUI

enum RouteViewFactory {
    @ViewBuilder
    static func view(for route: AppRoute, dependencies: AppDependencyContainer, navigation: TabNavigationState) -> some View {
        switch route {
        case .activityHistory:
            ActivityHistoryView(dependencies: dependencies)
        case .jobSummary(let workOrderID):
            JobSummaryView(workOrderID: workOrderID, dependencies: dependencies, navigation: navigation)
        case .completeWorkOrder(let workOrderID):
            CompleteWorkOrderView(workOrderID: workOrderID, dependencies: dependencies, navigation: navigation)
        case .workOrderSuccess(let workOrderID, let elapsedTime, let parts, let laborCost):
            WorkOrderSuccessView(workOrderID: workOrderID, elapsedTime: elapsedTime, parts: parts, laborCost: laborCost, dependencies: dependencies, navigation: navigation)
        case .upcomingMaintenanceList:
            UpcomingMaintenanceListView(dependencies: dependencies, navigation: navigation)
        case .allUpcomingWorkOrders:
            AllUpcomingWorkOrdersView(dependencies: dependencies, navigation: navigation)
        case .allUnfinishedWorkOrders:
            AllUnfinishedWorkOrdersView(dependencies: dependencies, navigation: navigation)
        case .allHistoryWorkOrders:
            AllHistoryWorkOrdersView(dependencies: dependencies, navigation: navigation)
        case .vehicleDetails(let vehicleID):
            if let uuid = UUID(uuidString: vehicleID) {
                VehicleDetailsView(vehicleID: uuid, dependencies: dependencies, navigation: navigation)
            } else {
                EmptyView()
            }
        case .pastWorkOrderDetails(let workOrderID):
            PastWorkOrderDetailsView(workOrderID: workOrderID, dependencies: dependencies, navigation: navigation)
        }
    }
}
