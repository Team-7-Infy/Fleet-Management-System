import SwiftUI

struct VehicleComplianceDocsView: View {
    @ObservedObject var viewModel: VehicleViewModel
    var vehicleId: UUID

    @State private var showAddSheet = false
    @State private var selectedDocType = "insurance"
    @State private var docNumber = ""
    @State private var issueDate = Date()
    @State private var expiryDate = Date().addingTimeInterval(365 * 86400)
    @State private var editingDocument: VehicleDocument?

    private let docTypes = ["insurance", "registration", "road_tax", "permit", "puc"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionTitle("Compliance Documents")

            GlassPanel(hasBorder: false) {
                VStack(spacing: 12) {
                    if viewModel.documents.isEmpty {
                        Text("No documents added yet.")
                            .font(.subheadline)
                            .foregroundStyle(FleetPalette.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(viewModel.documents) { document in
                            documentRow(document)
                            if document.id != viewModel.documents.last?.id {
                                Divider()
                            }
                        }
                    }

                    Divider()

                    Button {
                        selectedDocType = "insurance"
                        docNumber = ""
                        issueDate = Date()
                        expiryDate = Date().addingTimeInterval(365 * 86400)
                        editingDocument = nil
                        showAddSheet = true
                    } label: {
                        Label("Add Document", systemImage: "plus.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FleetPalette.accent)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            documentFormSheet
        }
        .task {
            await viewModel.loadDocuments(for: vehicleId)
        }
    }

    @ViewBuilder
    private func documentRow(_ document: VehicleDocument) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(documentTitle(document.docType))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(FleetPalette.textPrimary)
                Text("No. \(document.docNumber)")
                    .font(.caption)
                    .foregroundStyle(FleetPalette.textSecondary)
                Text("Expires \(formattedDate(document.expiryDate.wrappedValue))")
                    .font(.caption2)
                    .foregroundStyle(statusColor(for: document.expiryDate.wrappedValue))
            }

            Spacer()

            statusBadge(for: document.expiryDate.wrappedValue)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await viewModel.removeDocument(id: document.id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func documentTitle(_ type: String) -> String {
        switch type {
        case "insurance": return "Insurance"
        case "registration": return "Registration"
        case "road_tax": return "Road Tax"
        case "permit": return "Permit"
        case "puc": return "PUC"
        default: return type.capitalized
        }
    }

    private func statusBadge(for date: Date) -> some View {
        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        let text: String
        let color: Color
        if daysRemaining < 0 {
            text = "EXPIRED"
            color = FleetPalette.danger
        } else if daysRemaining <= 30 {
            text = "EXPIRING"
            color = FleetPalette.warning
        } else {
            text = "VALID"
            color = FleetPalette.success
        }
        return DocStatusPill(text: text, color: color)
    }

    private func statusColor(for date: Date) -> Color {
        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if daysRemaining < 0 { return FleetPalette.danger }
        if daysRemaining <= 30 { return FleetPalette.warning }
        return FleetPalette.success
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private var documentFormSheet: some View {
        NavigationStack {
            Form {
                Section("Document Type") {
                    Picker("Type", selection: $selectedDocType) {
                        ForEach(docTypes, id: \.self) { type in
                            Text(documentTitle(type)).tag(type)
                        }
                    }
                }

                Section("Details") {
                    TextField("Document Number", text: $docNumber)
                    DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
                    DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                }

                Section {
                    Button("Save Document") {
                        Task {
                            let success = await viewModel.addDocument(
                                vehicleId: vehicleId,
                                docType: selectedDocType,
                                docNumber: docNumber,
                                issueDate: issueDate,
                                expiryDate: expiryDate
                            )
                            if success {
                                showAddSheet = false
                            }
                        }
                    }
                    .disabled(docNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddSheet = false }
                }
            }
        }
    }
}

private struct DocStatusPill: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .black))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
