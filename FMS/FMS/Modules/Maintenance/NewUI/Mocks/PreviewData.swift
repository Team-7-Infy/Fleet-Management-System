import Foundation

enum PreviewData {
    static var currentUser = UserProfile(
        id: UUID(),
        email: "john.carter@fleet.com",
        aadhar: "1234-5678-9012",
        contact: 9876543210,
        role: "Senior Technician",
        f_name: "John",
        l_name: "Carter",
        addressStr: "123 Fleet Street",
        isactive: true,
        createdat: Date(),
        avatarurl: nil,
        first_time_login: false,
        personnelId: nil,
        profileImageData: nil
    )

    static let vehicles = [
        Vehicle(
            id: UUID(),
            make: "Volvo",
            model: "VNL",
            year: 2020,
            licencePlate: "KACM92KS6",
            status: .maintenance,
            vehicleType: "Truck",
            driverId: nil
        ),
        Vehicle(
            id: UUID(),
            make: "Blue Bird",
            model: "Vision",
            year: 2018,
            licencePlate: "BUSC11",
            status: .active,
            vehicleType: "Bus",
            driverId: nil
        )
    ]

    static let workOrders = [
        WorkOrder(
            id: UUID(),
            taskTitle: "Engine Maintenance",
            description: "Engine temp is high.",
            scheduledDate: "2026-06-25",
            scheduledBy: currentUser.id,
            executedBy: currentUser.id,
            isUrgent: true,
            statusString: JobStatus.inProgress.rawValue,
            totalCostDB: nil,
            photoUrls: nil,
            remarks: nil,
            completedAt: nil,
            taskVehicles: [MpTaskVehicle(vin: vehicles[0].id)],
            taskParts: nil,
            elapsedTime: 2730, // 45m 30s
            usedParts: []
        )
    ]

    static let services = [
        MaintenanceSchedule(
            id: UUID(),
            vehicleId: vehicles[0].id,
            taskType: "Brake Inspection",
            intervalKm: 5000,
            intervalDays: 90,
            lastCompletedKm: 115000,
            lastCompletedDate: Date(timeIntervalSinceNow: -86400 * 30),
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]

    static let inspectionItems = [
        MPInspectionItem(id: "inspection-1", category: "Engine", title: "Check coolant level", isComplete: true),
        MPInspectionItem(id: "inspection-2", category: "Engine", title: "Inspect radiator", isComplete: true)
    ]

    static let parts = [
        InventoryItem(
            id: UUID(),
            partname: "Coolant Fluid",
            cost: 15.0,
            quantityOnHand: 14,
            vehicletype: "Truck"
        ),
        InventoryItem(
            id: UUID(),
            partname: "Radiator Cap",
            cost: 25.0,
            quantityOnHand: 20,
            vehicletype: "General"
        )
    ]
    
    static let spareParts = parts

    static let activities = [
        Activity(id: "act-1", title: "Oil and Filter Change", subtitle: "For Vehicle", date: Date(timeIntervalSinceNow: -3600), status: .completed)
    ]
}
