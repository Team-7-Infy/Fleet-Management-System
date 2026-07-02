//
//  FuelHistoryView.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import SwiftUI
import PhotosUI

struct FuelHistoryView: View {
    @StateObject private var viewModel = FuelViewModel()
    @State private var showingRequestSheet = false

    var body: some View {
        NavigationStack {
            List(viewModel.fuelHistory) { record in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(record.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        StatusBadge(status: record.status)
                    }

                    HStack {
                        VStack(alignment: .leading) {
                            Text(record.fuelType.rawValue)
                                .font(.headline)
                            if let volume = record.volumeFilled {
                                Text("\(volume, specifier: "%.1f") \(record.refillUnit)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()

                        if let cost = record.cost {
                            Text("₹\(cost, specifier: "%.2f")")
                                .font(.title3)
                                .fontWeight(.bold)
                        } else if let requested = record.amountRequested {
                            Text("Req: $\(requested, specifier: "%.2f")")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Fuel Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingRequestSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingRequestSheet) {
                FuelRequestView()
            }
        }
    }
}

struct TripFuelHistoryView: View {
    @EnvironmentObject var localStore: LocalDataStore
    @Environment(\.dismiss) var dismiss

    let isReadOnly: Bool
    let activeTripId: String?
    let vehicleNumber: String

    @State private var selectedFuelType: FuelRecord.FuelType = .diesel
    @State private var liters: String = ""
    @State private var pricePerLiter: String = ""
    @State private var receiptCode: String = ""
    @State private var refillDate: Date = Date()
    @State private var selectedReceiptImage: PhotosPickerItem?
    @State private var showingSavedAlert = false

    init(isReadOnly: Bool = false, activeTripId: String? = nil, vehicleNumber: String = "") {
        self.isReadOnly = isReadOnly
        self.activeTripId = activeTripId
        self.vehicleNumber = vehicleNumber
    }

    private var quantityUnit: String {
        selectedFuelType == .ev ? "kW" : "L"
    }

    private var quantityTitle: String {
        selectedFuelType == .ev ? "Power Added" : "Liters"
    }

    private var priceTitle: String {
        selectedFuelType == .ev ? "Price / kW" : "Price / Liter"
    }

    private var efficiencyUnit: String {
        selectedFuelType == .ev ? "km/kW" : "km/L"
    }

    private var remainingLabel: String {
        selectedFuelType == .ev ? "charge remaining" : "fuel remaining"
    }

    private var tripFuelHistory: [FuelRecord] {
        localStore.fuelHistory
            .filter { $0.tripId == activeTripId && $0.status == .completed }
            .sorted { $0.date > $1.date }
    }

    private var quantityValue: Double {
        Double(liters) ?? 0
    }

    private var priceValue: Double {
        Double(pricePerLiter) ?? 0
    }

    private var totalCost: Double {
        quantityValue * priceValue
    }

    private var canSave: Bool {
        quantityValue > 0 && priceValue > 0 && !receiptCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let fuelLevel: Double = 0.5
    private let mileageKmPerLiter: Double = 12.0
    private let tankCapacityLiters: Double = 50.0

    private var estimatedRangeKm: Double {
        fuelLevel * tankCapacityLiters * mileageKmPerLiter
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isReadOnly {
                    historySection
                } else {
                    fuelRangeCard
                    refillForm
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(isReadOnly ? "Fuel Logs" : "Add Fuel Refill")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if isReadOnly {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert(isPresented: $showingSavedAlert) {
            Alert(
                title: Text("Refill Saved"),
                message: Text("Fuel refill has been added to this trip history."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var fuelRangeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Range")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(Int(estimatedRangeKm)) km")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                Image(systemName: selectedFuelType == .ev ? "bolt.car.fill" : "fuelpump.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.white)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geometry.size.width * min(max(fuelLevel, 0), 1))
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(Int(fuelLevel * 100))% \(remainingLabel)")
                Spacer()
                Text("\(mileageKmPerLiter, specifier: "%.1f") \(efficiencyUnit)")
            }
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white.opacity(0.85))
        }
        .padding(20)
        .background(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(20)
    }

    private var refillForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Refill")
                .font(.headline)

            Picker("Fuel Type", selection: $selectedFuelType) {
                ForEach(FuelRecord.FuelType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .accessibilityLabel("Fuel Type Selection")

            FuelFormField(title: quantityTitle, placeholder: "0.0 \(quantityUnit)", text: $liters, keyboardType: .decimalPad)
            FuelFormField(title: priceTitle, placeholder: "0.00", text: $pricePerLiter, keyboardType: .decimalPad)
            FuelFormField(title: "Receipt Code", placeholder: "Receipt or pump code", text: $receiptCode, keyboardType: .default)

            DatePicker("Date & Time", selection: $refillDate, displayedComponents: [.date, .hourAndMinute])

            PhotosPicker(selection: $selectedReceiptImage, matching: .images) {
                HStack {
                    Image(systemName: selectedReceiptImage == nil ? "photo.badge.plus" : "checkmark.circle.fill")
                    Text(selectedReceiptImage == nil ? "Attach Receipt Image" : "Receipt Image Attached")
                    Spacer()
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(selectedReceiptImage == nil ? .blue : .green)
            }

            HStack {
                Text("Calculated Total")
                    .fontWeight(.semibold)
                Spacer()
                Text("₹\(totalCost, specifier: "%.2f")")
                    .font(.title3)
                    .fontWeight(.heavy)
            }

            Button(action: saveRefill) {
                Text("Save Refill")
                    .font(.headline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSave ? Color.orange : Color.gray.opacity(0.25))
                    .foregroundColor(canSave ? .white : .gray)
                    .cornerRadius(14)
            }
            .disabled(!canSave)
            .accessibilityLabel("Save Fuel Refill")
        }
        .padding(18)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(18)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Trip Refills")
                    .font(.headline)
                Spacer()
                Text(activeTripId ?? "No Trip")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }

            if tripFuelHistory.isEmpty {
                Text("No refills recorded for this trip yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(tripFuelHistory) { record in
                        TripFuelHistoryRow(record: record)
                        if record.id != tripFuelHistory.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(18)
    }

    private func saveRefill() {
        localStore.saveFuelEntry(
            vehicleId: vehicleNumber,
            tripId: activeTripId ?? "",
            fuelType: selectedFuelType,
            liters: quantityValue,
            price: quantityValue * priceValue,
            receiptCode: receiptCode.trimmingCharacters(in: .whitespacesAndNewlines),
            date: refillDate
        )

        liters = ""
        pricePerLiter = ""
        receiptCode = ""
        refillDate = Date()
        selectedReceiptImage = nil
        showingSavedAlert = true
    }
}

struct FuelFormField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType

    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
            Spacer()
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(title)
        }
    }
}

struct TripFuelHistoryRow: View {
    let record: FuelRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.fuelType.rawValue)
                        .font(.headline)
                    Text(record.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(record.date, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("₹\((record.cost ?? 0), specifier: "%.2f")")
                    .font(.title3)
                    .fontWeight(.heavy)
            }

            HStack(spacing: 12) {
                Label("\((record.volumeFilled ?? 0), specifier: "%.1f") \(record.refillUnit)", systemImage: record.fuelType == .ev ? "bolt.fill" : "drop.fill")
                if let price = record.pricePerLiter {
                    Label("₹\(price, specifier: "%.2f")/\(record.priceUnit)", systemImage: "tag.fill")
                }
                if record.receiptImageURL != nil {
                    Label("Image", systemImage: "photo.fill")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            if let receiptCode = record.receiptCode, !receiptCode.isEmpty {
                Text("Receipt: \(receiptCode)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 12)
    }
}

// Reusable UI component for status badges
struct StatusBadge: View {
    let status: FuelRecord.RequestStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundColor(backgroundColor)
            .cornerRadius(12)
    }

    private var backgroundColor: Color {
        switch status {
        case .approved, .completed: return .green
        case .pending: return .orange
        case .rejected: return .red
        }
    }
}

#Preview {
    FuelHistoryView()
}
