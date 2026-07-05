import SwiftUI

struct FleetOptimizationView: View {
    @ObservedObject var reportsViewModel: ReportsViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    @ObservedObject var maintenanceViewModel: MaintenanceViewModel

    @State private var vehicleToSchedule: Vehicle?
    @State private var driverToCall: (driver: Driver, user: User?)?
    @State private var isScheduling = false
    @State private var scheduleSuccess = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                fleetHealthSummary
                vehiclesSection
                driversSection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .fleetScreenBackground()
        .navigationTitle("Fleet Optimization")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Schedule Maintenance", isPresented: .init(
            get: { vehicleToSchedule != nil },
            set: { if !$0 { vehicleToSchedule = nil } }
        ), presenting: vehicleToSchedule) { vehicle in
            Button("Cancel", role: .cancel) { vehicleToSchedule = nil }
            Button("Schedule") {
                Task { await scheduleMaintenance(for: vehicle) }
            }
        } message: { vehicle in
            Text("Schedule immediate maintenance for \(vehicle.licencePlate)?")
        }
        .alert("Call Driver", isPresented: .init(
            get: { driverToCall != nil },
            set: { if !$0 { driverToCall = nil } }
        ), presenting: driverToCall) { item in
            Button("Cancel", role: .cancel) { driverToCall = nil }
            Button("Call") {
                callDriver(item.driver, user: item.user)
            }
        } message: { item in
            Text("Call \(item.user?.displayName ?? "this driver") at \(item.user.map { "\($0.contact)" } ?? "their number")?")
        }
    }

    private var fleetHealthSummary: some View {
        let score = reportsViewModel.fleetHealthScore
        let color = reportsViewModel.fleetHealthColor

        return GlassPanel(hasBorder: false) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(color.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    Text("\(score)")
                        .font(.title3.weight(.heavy).monospacedDigit())
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Fleet Health Score: \(reportsViewModel.fleetHealthLabel)")
                        .font(.subheadline).bold()
                        .foregroundStyle(FleetPalette.textPrimary)
                    Text("\(reportsViewModel.vehiclesNeedingMaintenance.count) vehicles need attention")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("\(reportsViewModel.topUnderperformingDrivers.count) underperforming drivers")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var vehiclesSection: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Vehicles Requiring Maintenance", systemImage: "wrench.and.screwdriver.fill")
                    .font(.headline)
                    .foregroundStyle(FleetPalette.warning)

                Text("Vehicles with overdue or unresolved maintenance tasks")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                let items = reportsViewModel.vehiclesNeedingMaintenancePriority
                if items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(FleetPalette.success)
                        Text("All vehicles are up to date")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(items.prefix(8), id: \.vehicle.id) { item in
                        HStack(spacing: 8) {
                            NavigationLink {
                                ManagerVehicleDetailView(
                                    vehicle: item.vehicle,
                                    viewModel: vehiclesViewModel,
                                    usersViewModel: usersViewModel,
                                    openMaintenanceRequest: { _ in }
                                )
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.vehicle.licencePlate)
                                            .font(.subheadline).bold()
                                            .foregroundStyle(FleetPalette.textPrimary)
                                        Text("\(item.vehicle.make) \(item.vehicle.model)")
                                            .font(.caption)
                                            .foregroundStyle(FleetPalette.textSecondary)
                                    }
                                    Spacer()
                                    Text("\(item.overdueDays)d overdue")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(item.overdueDays > 14 ? FleetPalette.danger : FleetPalette.warning)
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                vehicleToSchedule = item.vehicle
                            } label: {
                                Image(systemName: "wrench.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(FleetPalette.warning, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .frame(minWidth: 44, minHeight: 44)
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private var driversSection: some View {
        GlassPanel(hasBorder: false) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Underperforming Drivers", systemImage: "person.fill.xmark")
                    .font(.headline)
                    .foregroundStyle(FleetPalette.danger)

                Text("Drivers with low on-time completion rate")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                let items = reportsViewModel.topUnderperformingDrivers
                if items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(FleetPalette.success)
                        Text("All drivers are performing well")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(items.prefix(8), id: \.driver.id) { item in
                        HStack(spacing: 8) {
                            if let user = item.user {
                                NavigationLink {
                                    ManagerUserDetailView(
                                        user: user,
                                        viewModel: usersViewModel,
                                        tripsViewModel: reportsViewModel.tripsViewModel,
                                        maintenanceViewModel: maintenanceViewModel
                                    )
                                } label: {
                                    rowLabel(for: item)
                                }
                                .buttonStyle(.plain)
                            } else {
                                rowLabel(for: item)
                            }

                            Button {
                                driverToCall = (item.driver, item.user)
                            } label: {
                                Image(systemName: "phone.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(FleetPalette.success, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .frame(minWidth: 44, minHeight: 44)
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private func rowLabel(for item: (driver: Driver, user: User?, totalTrips: Int, onTimeRate: Double)) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.user?.displayName ?? "Unknown Driver")
                    .font(.subheadline).bold()
                    .foregroundStyle(FleetPalette.textPrimary)
                Text("\(item.totalTrips) trips completed")
                    .font(.caption)
                    .foregroundStyle(FleetPalette.textSecondary)
            }
            Spacer()
            Text("\(Int(item.onTimeRate.rounded()))%")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.onTimeRate < 40 ? FleetPalette.danger : FleetPalette.warning)
        }
    }

    private func scheduleMaintenance(for vehicle: Vehicle) async {
        var form = FleetManagerMaintenanceTaskForm()
        form.title = "Scheduled from Optimization"
        form.description = "Auto-scheduled maintenance from Fleet Optimization"
        form.scheduledDate = Date()
        form.vehicleId = vehicle.id
        form.isUrgent = true
        form.status = .scheduled

        let success = await maintenanceViewModel.createTask(form: form)
        if success {
            await vehiclesViewModel.load()
            await maintenanceViewModel.load()
        }
    }

    private func callDriver(_ driver: Driver, user: User?) {
        guard let user, user.contact > 0 else { return }
        let phoneNumber = "\(user.contact)"
        guard let url = URL(string: "tel:\(phoneNumber)") else { return }
        UIApplication.shared.open(url)
    }
}
