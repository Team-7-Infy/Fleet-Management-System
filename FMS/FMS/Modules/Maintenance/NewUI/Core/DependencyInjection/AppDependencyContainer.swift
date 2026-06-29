import Foundation
import Supabase

final class AppDependencyContainer {
    let vehicleService: any VehicleServicing
    let workOrderService: any WorkOrderServicing
    let activityService: any ActivityServicing
    let authService: any AuthServicing
    let notificationService: any NotificationServicing
    let apiClient: APIClient

    let sessionManager: SessionManager
    let featureFlagManager: FeatureFlagManager

    init(
        vehicleService: any VehicleServicing,
        workOrderService: any WorkOrderServicing,
        activityService: any ActivityServicing,
        authService: any AuthServicing,
        notificationService: any NotificationServicing,
        apiClient: APIClient = APIClient(),
        sessionManager: SessionManager = SessionManager(),
        featureFlagManager: FeatureFlagManager = FeatureFlagManager()
    ) {
        self.vehicleService = vehicleService
        self.workOrderService = workOrderService
        self.activityService = activityService
        self.authService = authService
        self.notificationService = notificationService
        self.apiClient = apiClient

        self.sessionManager = sessionManager
        self.featureFlagManager = featureFlagManager
    }

    static func mock() -> AppDependencyContainer {
        AppDependencyContainer(
            vehicleService: MockVehicleService(),
            workOrderService: MockWorkOrderService(),
            activityService: MockActivityService(),
            authService: MockAuthService(),
            notificationService: MockNotificationService()
        )
    }
    
    static func supabase(client: SupabaseClient? = nil) -> AppDependencyContainer {
        let apiClient = APIClient()
        let supabaseClient = client ?? SupabaseClient(
            supabaseURL: EnvironmentConfig.supabaseURL,
            supabaseKey: EnvironmentConfig.supabaseAnonKey
        )
        return AppDependencyContainer(
            vehicleService: SupabaseVehicleService(apiClient: apiClient),
            workOrderService: SupabaseWorkOrderService(apiClient: apiClient, client: supabaseClient),
            activityService: SupabaseActivityService(apiClient: apiClient),
            authService: SupabaseAuthService(client: supabaseClient),
            notificationService: MockNotificationService(),
            apiClient: apiClient
        )
    }
}
