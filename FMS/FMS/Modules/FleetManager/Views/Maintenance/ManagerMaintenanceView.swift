import SwiftUI
import UniformTypeIdentifiers

private enum MaintenanceSegment: String, CaseIterable, Identifiable {
    case active = "Active"
    case history = "History"
    
    var id: String { rawValue }
}

struct ManagerMaintenanceView: View {
    @ObservedObject var viewModel: MaintenanceViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel
    @ObservedObject var usersViewModel: UserManagementViewModel
    var inventoryService: InventoryServiceProtocol
    var onNotification: ((String, String, String) -> Void)?
    @State private var selectedSegment: MaintenanceSegment = .active
    @State private var searchText = ""
    var openMaintenanceRequest: () -> Void

    private var filteredTasks: [MaintenanceTask] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = viewModel.tasks
            .filter { task in
                switch selectedSegment {
                case .active:
                    return task.status != .completed
                case .history:
                    return task.status == .completed
                }
            }
            .filter { task in
                guard query.isEmpty == false else { return true }
                let vehicle = viewModel.vehicles(for: task).first.flatMap { tv in
                    vehiclesViewModel.vehicle(for: tv.vin)
                }
                let searchable = [
                    task.displayTitle,
                    task.description,
                    task.status.title,
                    vehicle?.licencePlate,
                    vehicle.map { "\($0.make) \($0.model)" }
                ]
                return searchable.compactMap { $0 }.contains { $0.localizedCaseInsensitiveContains(query) }
            }
        return filtered.sorted {
            if $0.isUrgent != $1.isUrgent {
                return $0.isUrgent && !$1.isUrgent
            }
            return $0.reportedOrScheduledDate > $1.reportedOrScheduledDate
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FeedbackView(success: viewModel.successMessage, error: viewModel.errorMessage)

                if viewModel.tasks.isEmpty {
                    ContentUnavailableView(
                        "No work orders",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Request maintenance and assign registered personnel.")
                    )
                } else if filteredTasks.isEmpty {
                    ContentUnavailableView.search
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredTasks) { task in
                            NavigationLink {
                                ManagerServiceDetailView(
                                    task: task,
                                    viewModel: viewModel,
                                    vehiclesViewModel: vehiclesViewModel,
                                    usersViewModel: usersViewModel
                                )
                            } label: {
                                ManagerWorkOrderCard(
                                    task: task,
                                    viewModel: viewModel,
                                    vehiclesViewModel: vehiclesViewModel
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Workshop")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search tasks")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu("Filter", systemImage: "line.3.horizontal.decrease") {
                    Picker("Service Status", selection: $selectedSegment) {
                        ForEach(MaintenanceSegment.allCases) { segment in
                            Text(segment.rawValue).tag(segment)
                        }
                    }
                }
                NavigationLink {
                    ManagerInventoryView(inventoryService: inventoryService, onNotification: onNotification)
                } label: {
                    Image(systemName: "shippingbox")
                }
                Button("Request Workshop", systemImage: "plus", action: openMaintenanceRequest)
            }
        }
        .task {
            await viewModel.load()
            await vehiclesViewModel.load()
            await usersViewModel.load()
        }
        .refreshable {
            await viewModel.load()
            await vehiclesViewModel.load()
            await usersViewModel.load()
        }
    }
}

private struct ManagerWorkOrderCard: View {
    var task: MaintenanceTask
    @ObservedObject var viewModel: MaintenanceViewModel
    @ObservedObject var vehiclesViewModel: VehicleViewModel

    private var vehicle: Vehicle? {
        guard let vin = viewModel.vehicles(for: task).first?.vin else { return nil }
        return vehiclesViewModel.vehicle(for: vin)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(task.displayTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(FleetPalette.textPrimary)
                        .lineLimit(2)

                    if let vehicle {
                        Text(vehicle.licencePlate)
                            .font(.subheadline)
                            .foregroundStyle(FleetPalette.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("No Vehicle Linked")
                            .font(.subheadline)
                            .foregroundStyle(FleetPalette.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    StatusPill(
                        text: task.status.title,
                        color: FleetPalette.maintenanceStatus(task.status),
                        dotSize: 8
                    )

                    if task.isUrgent {
                        UrgentTag()
                    }
                }
            }

            Divider()
                .background(FleetPalette.tertiary.opacity(0.5))

            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text("Reported \(task.hoursAgoText)")
                        .font(.caption)
                }
                .foregroundStyle(FleetPalette.textSecondary)
                
                Spacer()
                
                if let cost = task.totalCost, cost > 0 {
                    Text("Cost: ₹\(Int(cost))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FleetPalette.success)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(FleetPalette.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
    }
}

private struct UrgentTag: View {
    var body: some View {
        Text("URGENT")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(FleetPalette.danger)
            .clipShape(Capsule())
            .accessibilityLabel("Urgent")
    }
}

private struct ManagerInventoryView: View {
    var inventoryService: InventoryServiceProtocol
    var onNotification: ((String, String, String) -> Void)?
    @State private var parts: [InventoryPart] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showImportPicker = false
    @State private var showImportResult = false
    @State private var importResult: CSVImportResult?
    @State private var isImporting = false
    @State private var importSuccessMessage: String?

    var lowStockParts: [InventoryPart] {
        parts.filter { $0.quantity <= ($0.reorderLevel ?? 0) && ($0.reorderLevel ?? 0) > 0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if isLoading && parts.isEmpty {
                    ProgressView("Loading inventory...")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Inventory unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else if parts.isEmpty {
                    ContentUnavailableView(
                        "No inventory",
                        systemImage: "shippingbox",
                        description: Text("Inventory table has no parts yet. Import a CSV to get started.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(parts) { part in
                            InventoryPartRow(part: part)
                        }
                    }
                }
            }
            .padding()
        }
        .fleetScreenBackground()
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu("Actions", systemImage: "ellipsis.circle") {
                    Button {
                        showImportPicker = true
                    } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                    }

                    ShareLink(item: templateCSVString, preview: SharePreview("Inventory Template", icon: "shippingbox")) {
                        Label("Download Template", systemImage: "doc.badge.plus")
                    }

                    if !lowStockParts.isEmpty {
                        ShareLink(item: quotationCSVString, preview: SharePreview("Low Stock Quotation", icon: "exclamationmark.triangle")) {
                            Label("Low Stock Quotation (\(lowStockParts.count))", systemImage: "doc.text")
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else {
                    self.importResult = CSVImportResult(validRows: [], errors: [
                        CSVImportError(row: 0, column: "", message: "Could not access the selected file.")
                    ])
                    self.showImportResult = true
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    let data = try Data(contentsOf: url)
                    let parsed = InventoryCSVParser.parse(csvData: data)
                    self.importResult = parsed
                    self.importSuccessMessage = nil
                    self.showImportResult = true
                } catch {
                    self.importResult = CSVImportResult(validRows: [], errors: [
                        CSVImportError(row: 0, column: "", message: "Failed to read file: \(error.localizedDescription)")
                    ])
                    self.showImportResult = true
                }
            case .failure(let error):
                self.importResult = CSVImportResult(validRows: [], errors: [
                    CSVImportError(row: 0, column: "", message: "File selection failed: \(error.localizedDescription)")
                ])
                self.showImportResult = true
            }
        }
        .sheet(isPresented: $showImportResult) {
            ImportResultSheet(
                result: importResult,
                isImporting: isImporting,
                importSuccessMessage: importSuccessMessage,
                onConfirm: executeImport,
                onDismiss: {
                    showImportResult = false
                    importResult = nil
                    importSuccessMessage = nil
                }
            )
        }
        .task {
            await loadParts()
        }
        .refreshable {
            await loadParts()
        }
    }

    private var templateCSVString: String {
        InventoryCSVParser.generateTemplateCSV()
    }

    private var quotationCSVString: String {
        InventoryCSVParser.generateLowStockQuotationCSV(parts: parts)
    }

    private func loadParts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            parts = try await inventoryService.fetchParts()
                .sorted { $0.partName.localizedCaseInsensitiveCompare($1.partName) == .orderedAscending }
            errorMessage = nil
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func executeImport() {
        guard let result = importResult, !result.validRows.isEmpty else { return }
        isImporting = true

        Task {
            do {
                let count = try await inventoryService.bulkImportFromCSV(validatedRows: result.validRows)
                importSuccessMessage = "Successfully imported \(count) item(s)."
                showImportResult = false
                isImporting = false
                importResult = nil
                await loadParts()
                let lowStockCount = lowStockParts.count
                if lowStockCount > 0 {
                    onNotification?(
                        "Low Stock Alert",
                        "\(lowStockCount) item(s) are at or below reorder level. Review Low Stock Quotation for details.",
                        "inventory_alert"
                    )
                }
            } catch {
                importSuccessMessage = nil
                importResult = CSVImportResult(validRows: [], errors: [
                    CSVImportError(row: 0, column: "", message: "Import failed: \(error.localizedDescription)")
                ])
                isImporting = false
            }
        }
    }
}

// MARK: - Import Result Sheet
private struct ImportResultSheet: View {
    let result: CSVImportResult?
    let isImporting: Bool
    let importSuccessMessage: String?
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let success = importSuccessMessage {
                    successView(success)
                } else if let result {
                    resultView(result)
                } else {
                    Text("No data.")
                        .foregroundStyle(FleetPalette.textSecondary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationTitle("CSV Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if importSuccessMessage != nil {
                        Button("Done") { onDismiss() }
                    } else if let result, !result.validRows.isEmpty {
                        Button("Import \(result.validRows.count) Items") {
                            onConfirm()
                        }
                        .disabled(isImporting)
                    } else {
                        Button("Done") { onDismiss() }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if importSuccessMessage == nil {
                        Button("Cancel") { onDismiss() }
                            .disabled(isImporting)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func successView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("The imported items now appear in your inventory list.")
                .font(.subheadline)
                .foregroundStyle(FleetPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func resultView(_ result: CSVImportResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryRow(label: "Valid rows", value: "\(result.validRows.count)", color: .green)
                summaryRow(label: "Errors", value: "\(result.errors.count)", color: result.errors.isEmpty ? .green : .red)

                if !result.errors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Row Errors")
                            .font(.headline)
                            .foregroundStyle(FleetPalette.danger)

                        ForEach(result.errors) { error in
                            HStack(alignment: .top, spacing: 8) {
                                Text("Row \(error.row):")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(FleetPalette.danger)
                                    .frame(minWidth: 50, alignment: .trailing)

                                Text(error.message)
                                    .font(.caption)
                                    .foregroundStyle(FleetPalette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(12)
                    .background(FleetPalette.danger.opacity(0.06))
                    .cornerRadius(10)
                }

                if !result.validRows.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview (\(result.validRows.count) items)")
                            .font(.headline)
                            .foregroundStyle(FleetPalette.success)

                        ForEach(result.validRows.prefix(5)) { part in
                            HStack {
                                Text(part.partName)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text("SKU: \(part.sku ?? "-")")
                                    .font(.caption)
                                    .foregroundStyle(FleetPalette.textSecondary)
                            }
                            .padding(.vertical, 2)
                        }
                        if result.validRows.count > 5 {
                            Text("... and \(result.validRows.count - 5) more")
                                .font(.caption)
                                .foregroundStyle(FleetPalette.textTertiary)
                        }
                    }
                    .padding(12)
                    .background(FleetPalette.success.opacity(0.06))
                    .cornerRadius(10)
                }

                if isImporting {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Importing...")
                            .font(.subheadline)
                            .foregroundStyle(FleetPalette.textSecondary)
                    }
                }
            }
        }
    }

    private func summaryRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(FleetPalette.textSecondary)
            Spacer()
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 4)
    }
}

private struct InventoryPartRow: View {
    var part: InventoryPart

    private var isLowStock: Bool {
        guard let reorder = part.reorderLevel, reorder > 0 else { return false }
        return part.quantity <= reorder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(part.partName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(FleetPalette.textPrimary)
                            .lineLimit(2)

                        if isLowStock {
                            Text("LOW")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(FleetPalette.danger.opacity(0.12))
                                .foregroundStyle(FleetPalette.danger)
                                .clipShape(Capsule())
                        }
                    }

                    if let sku = part.sku, !sku.isEmpty {
                        Text("SKU: \(sku)")
                            .font(.caption)
                            .foregroundStyle(FleetPalette.textTertiary)
                    }
                }

                Spacer(minLength: 12)

                Text("Qty \(part.quantity)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isLowStock ? FleetPalette.danger : FleetPalette.success)
            }

            Divider()
                .background(FleetPalette.tertiary.opacity(0.5))

            HStack {
                if let reorder = part.reorderLevel, reorder > 0 {
                    Text("Reorder at \(reorder)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FleetPalette.textSecondary)
                } else {
                    Text("No reorder threshold")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FleetPalette.textTertiary)
                }
                Spacer()
                Text("₹\(String(format: "%.2f", part.unitCost ?? part.cost))/unit")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FleetPalette.textPrimary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(FleetPalette.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isLowStock ? FleetPalette.danger.opacity(0.3) : .clear, lineWidth: 1)
        )
    }
}
