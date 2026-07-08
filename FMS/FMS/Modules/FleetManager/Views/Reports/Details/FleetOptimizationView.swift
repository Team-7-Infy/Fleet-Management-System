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

        return FitnessCategoryCard {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.12), lineWidth: 8)
                        .frame(width: 72, height: 72)
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(color.gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: color.opacity(0.3), radius: 3, x: 0, y: 2)
                    Text("\(score)")
                        .font(.system(size: 20, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Fleet Health Score:")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FleetPalette.textSecondary)
                        Text(reportsViewModel.fleetHealthLabel.uppercased())
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    
                    Text("\(reportsViewModel.vehiclesNeedingMaintenance.count) vehicles need attention")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FleetPalette.textPrimary)
                    Text("\(reportsViewModel.topUnderperformingDrivers.count) underperforming drivers")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FleetPalette.textPrimary)
                }
            }
        }
    }

    private var vehiclesSection: some View {
        FitnessCategoryCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.headline)
                        .foregroundStyle(FleetPalette.warning)
                    Text("Vehicles Requiring Maintenance")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(FleetPalette.textPrimary)
                }

                Text("Vehicles with overdue or unresolved maintenance tasks")
                    .font(.caption)
                    .foregroundStyle(FleetPalette.textSecondary)
                    .padding(.bottom, 4)

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
                    VStack(spacing: 8) {
                        ForEach(items.prefix(8), id: \.vehicle.id) { item in
                            vehicleRow(item: item)
                        }
                    }
                }
            }
        }
    }

    private func vehicleRow(item: (vehicle: Vehicle, overdueDays: Int, tasks: [MaintenanceTask])) -> some View {
        HStack(spacing: 12) {
            NavigationLink {
                ManagerVehicleDetailView(
                    vehicle: item.vehicle,
                    viewModel: vehiclesViewModel,
                    usersViewModel: usersViewModel,
                    openMaintenanceRequest: { _ in }
                )
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(FleetPalette.warning)
                        .frame(width: 36, height: 36)
                        .background(FleetPalette.warning.opacity(0.08), in: Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.vehicle.licencePlate)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FleetPalette.textPrimary)
                        Text("\(item.vehicle.make) \(item.vehicle.model)")
                            .font(.caption)
                            .foregroundStyle(FleetPalette.textSecondary)
                    }
                    
                    Spacer()
                    
                    Text("\(item.overdueDays)d overdue")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(item.overdueDays > 14 ? FleetPalette.danger : FleetPalette.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((item.overdueDays > 14 ? FleetPalette.danger : FleetPalette.warning).opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)
            
            Button {
                vehicleToSchedule = item.vehicle
            } label: {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(
                            colors: [FleetPalette.warning, FleetPalette.warning.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .shadow(color: FleetPalette.warning.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(FleetPalette.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FleetPalette.tertiary.opacity(0.08), lineWidth: 1)
        }
    }

    private var driversSection: some View {
        FitnessCategoryCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill.xmark")
                        .font(.headline)
                        .foregroundStyle(FleetPalette.danger)
                    Text("Underperforming Drivers")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(FleetPalette.textPrimary)
                }

                Text("Drivers with low on-time completion rate")
                    .font(.caption)
                    .foregroundStyle(FleetPalette.textSecondary)
                    .padding(.bottom, 4)

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
                    VStack(spacing: 8) {
                        ForEach(items.prefix(8), id: \.driver.id) { item in
                            driverRow(item: item)
                        }
                    }
                }
            }
        }
    }

    private func driverRow(item: (driver: Driver, user: User?, totalTrips: Int, onTimeRate: Double)) -> some View {
        HStack(spacing: 12) {
            if let user = item.user {
                NavigationLink {
                    ManagerUserDetailView(
                        user: user,
                        viewModel: usersViewModel,
                        vehiclesViewModel: vehiclesViewModel,
                        tripsViewModel: reportsViewModel.tripsViewModel,
                        maintenanceViewModel: maintenanceViewModel
                    )
                } label: {
                    driverRowLabel(for: item)
                }
                .buttonStyle(.plain)
            } else {
                driverRowLabel(for: item)
            }
            
            Button {
                driverToCall = (item.driver, item.user)
            } label: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(
                            colors: [FleetPalette.success, FleetPalette.success.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .shadow(color: FleetPalette.success.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(FleetPalette.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FleetPalette.tertiary.opacity(0.08), lineWidth: 1)
        }
    }
    
    private func driverRowLabel(for item: (driver: Driver, user: User?, totalTrips: Int, onTimeRate: Double)) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark.fill")
                .font(.title3)
                .foregroundStyle(FleetPalette.danger)
                .frame(width: 36, height: 36)
                .background(FleetPalette.danger.opacity(0.08), in: Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.user?.displayName ?? "Unknown Driver")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FleetPalette.textPrimary)
                Text("\(item.totalTrips) trips completed")
                    .font(.caption)
                    .foregroundStyle(FleetPalette.textSecondary)
            }
            
            Spacer()
            
            Text("\(Int(item.onTimeRate.rounded()))% on-time")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(item.onTimeRate < 40 ? FleetPalette.danger : FleetPalette.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((item.onTimeRate < 40 ? FleetPalette.danger : FleetPalette.warning).opacity(0.12))
                .clipShape(Capsule())
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

