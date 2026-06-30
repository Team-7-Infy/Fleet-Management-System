import Foundation

enum DatabaseContract {
    static let version = "1.0.0"
}

// MARK: - Table → Model Mapping
//
// users              → User
//   Optional image field: avatarurl → User.avatarUrl
// fleet_manager      → FleetManager
// drivers            → Driver
// maintenance_personnel → MaintenancePersonnel
// vehicles           → Vehicle
// trips              → Trip
// geofence           → Geofence
// deviation_alert    → DeviationAlert
// telemetry_log      → Telemetry
// maintenance_task   → MaintenanceTask
// inventory          → InventoryPart
// maintenance_task_parts → MaintenanceTaskPart
// task_vehicles      → TaskVehicle

// MARK: - Naming Conventions
//
// Database: snake_case (e.g., userid, createdat, f_name, licence_plate)
// Swift:    camelCase  (e.g., userId, createdAt, fName, licencePlate)
//
// PK columns are always mapped to `id` for Identifiable conformance.
// CodingKeys enum is used per model for explicit snake_case ↔ camelCase mapping.
//
// Files named after model types:
//   User.swift, Driver.swift, FleetManager.swift, etc.
// Shared models and enums in Utilities/Data Models/:
//   UserRole.swift, TripStatus.swift, MaintenanceTaskStatus.swift, etc.
// Services in Utilities/Services/:
//   AuthService.swift, VehicleService.swift, TripService.swift, etc.
// Protocols prefixed with model domain:
//   AuthServiceProtocol, VehicleServiceProtocol, TripServiceProtocol, etc.
// Implementations are named after the protocol without "Protocol":
//   AuthService, VehicleService, TripService, etc.

// MARK: - Serialization Strategy
//
// All models use standard JSON encoding/decoding via Codable.
// SharedDecoder (Utilities/Data Models/SharedDecoder.swift) provides
// the configured JSONDecoder and JSONEncoder for all Supabase operations.
//
// Date encoding: ISO 8601 with fractional seconds for timestamptz columns.
// Date-only columns (scheduleddate) use @DateOnly property wrapper
// with yyyy-MM-dd format.
//
// SupabaseService.swift initializes the client with URL and anon key
// from EnvironmentConfig (read from Info.plist).
//
// All service implementations are actors for thread safety.

// MARK: - UUID Handling Strategy
//
// All PKs are UUIDs with DB default gen_random_uuid().
//
// Swift models use UUID type for all UUID columns.
// UUIDs are sent to Supabase as their uuidString representation.
// PostgREST automatically handles UUID type coercion.
//
// When creating a new record, omit the PK field (let DB generate)
// or use UUID() for client-side generation.

// MARK: - Date Handling Strategy
//
// ┌────────────────┬──────────────┬──────────────────────────────┐
// │ DB Type        │ Swift Type   │ Serialization               │
// ├────────────────┼──────────────┼──────────────────────────────┤
// │ timestamptz    │ Date         │ ISO 8601 with fractional secs│
// │ date           │ @DateOnly    │ yyyy-MM-dd                  │
// └────────────────┴──────────────┴──────────────────────────────┘
//
// SharedDecoder handles both ISO8601 variants (with/without fractional seconds).
// @DateOnly handles the date-only format for scheduleddate.

// MARK: - DTO Strategy
//
// No separate DTO layer is used. Models map 1:1 to database tables
// and serve as both domain models and persistence models.
//
// Rationale:
// - Each model maps exactly one Supabase table
// - Junction tables (MaintenanceTaskPart, TaskVehicle) use composite PKs
// - No transformation logic exists between API and domain layers
// - Adding DTOs later is safe since models already use Codable
//
// If future requirements demand DTO separation (e.g., aggregated views,
// API versioning), create DTOs in Utilities/Data Models/DTOs/ with
// its own CodingKeys and conversion initializers.

// MARK: - Environment Setup
//
// 1. Add Supabase Swift SDK package dependency:
//    URL: https://github.com/supabase/supabase-swift
//    Version: Up to Next Major (2.x)
//
// 2. Add Info.plist entries:
//    - SUPABASE_URL (String)
//    - SUPABASE_ANON_KEY (String)
//
// 3. Configure xcconfig files:
//    Config/Development.xcconfig
//    Config/Production.xcconfig
//
//    SUPABASE_URL = $(SUPABASE_URL_DEV)
//    SUPABASE_ANON_KEY = $(SUPABASE_ANON_KEY_DEV)
//
// 4. Set per-scheme xcconfig in Xcode:
//    Product → Scheme → Edit Scheme → Build Configuration
//
// 5. Add SUPABASE_URL and SUPABASE_ANON_KEY to CI/CD environment variables.

// MARK: - Dependency Injection

// Service initialization follows a consistent pattern:
//
// let supabase = SupabaseService()
// let authService = AuthService(supabase: supabase)
// let vehicleService = VehicleService(supabase: supabase)

