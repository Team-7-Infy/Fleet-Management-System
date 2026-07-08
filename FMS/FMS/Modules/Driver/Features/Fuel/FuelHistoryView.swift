import SwiftUI
import PhotosUI

struct TripFuelHistoryView: View {
    @EnvironmentObject var localStore: LocalDataStore
    @Environment(\.dismiss) var dismiss

    let isReadOnly: Bool
    let activeTripId: String?
    let tripStatus: TripStatus?
    let tripEndTime: Date?
    let vehicleNumber: String
    let expenseService: ExpenseServiceProtocol?
    let driverId: UUID?
    let vehicleId: UUID?
    let vehicleFuelType: String?

    @State private var selectedFuelType: FuelRecord.FuelType = .diesel
    @State private var liters: String = ""
    @State private var pricePerLiter: String = ""
    @State private var receiptCode: String = ""
    @State private var refillDate: Date = Date()
    @State private var selectedReceiptImage: PhotosPickerItem?
    @State private var showingSavedAlert = false

    @State private var ocrAmount: String?
    @State private var ocrDate: String?
    @State private var ocrVendor: String?
    @State private var ocrNumber: String?
    @State private var showOCRReview = false
    @State private var receiptImageData: Data?
    @State private var isScanningReceipt = false
    @State private var ocrScanFailed = false
    @State private var showingSaveError = false
    @State private var saveErrorMessage = ""
    private var fuelLogs: [FuelLog]? = nil

    init(isReadOnly: Bool = false, activeTripId: String? = nil, tripStatus: TripStatus? = nil,
         tripEndTime: Date? = nil, vehicleNumber: String = "",
         expenseService: ExpenseServiceProtocol? = nil, driverId: UUID? = nil,
         vehicleId: UUID? = nil, vehicleFuelType: String? = nil, fuelLogs: [FuelLog]? = nil) {
        self.isReadOnly = isReadOnly
        self.activeTripId = activeTripId
        self.tripStatus = tripStatus
        self.tripEndTime = tripEndTime
        self.vehicleNumber = vehicleNumber
        self.expenseService = expenseService
        self.driverId = driverId
        self.vehicleId = vehicleId
        self.vehicleFuelType = vehicleFuelType
        self.fuelLogs = fuelLogs
    }

    private var canLogFuel: Bool {
        if tripStatus == .inProgress { return true }
        if tripStatus == .completed, let end = tripEndTime,
           Date().timeIntervalSince(end) < TripTimingPolicy.postTripInspectionDeadline {
            return true
        }
        return false
    }

    private var quantityUnit: String {
        selectedFuelType == .cng ? "kg" : "L"
    }

    private var quantityTitle: String {
        selectedFuelType == .cng ? "Weight" : "Liters"
    }

    private var priceTitle: String {
        selectedFuelType == .cng ? "Price / kg" : "Price / Liter"
    }

    private var efficiencyUnit: String {
        selectedFuelType == .cng ? "km/kg" : "km/L"
    }

    private var remainingLabel: String {
        selectedFuelType == .cng ? "fuel remaining" : "fuel remaining"
    }

    private var tripFuelHistory: [FuelRecord] {
        if let logs = fuelLogs {
            logs.map { log in
                FuelRecord(
                    id: log.id,
                    date: log.date,
                    vehicleId: log.vehicleId.uuidString,
                    tripId: log.tripId?.uuidString,
                    fuelType: FuelRecord.FuelType(rawValue: log.fuelType) ?? .diesel,
                    cost: log.cost,
                    volumeFilled: log.volumeFilled,
                    pricePerLiter: log.pricePerLiter,
                    currentFuelLevel: log.currentFuelLevel ?? 0,
                    receiptCode: log.receiptCode,
                    receiptImageURL: log.receiptImageUrl,
                    kWhAdded: log.kWhAdded,
                    chargePercentBefore: log.chargePercentBefore,
                    chargePercentAfter: log.chargePercentAfter
                )
            }
            .sorted { $0.date > $1.date }
        } else {
            localStore.fuelHistory
                .filter { $0.tripId == activeTripId }
                .sorted { $0.date > $1.date }
        }
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
                if !canLogFuel && !isReadOnly {
                    lockedState
                } else {
                    fuelRangeCard
                    refillForm
                    historySection
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
        .alert(isPresented: $showingSaveError) {
            Alert(
                title: Text("Save Failed"),
                message: Text(saveErrorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showOCRReview) {
            OCRReviewView(
                amount: $ocrAmount,
                date: $ocrDate,
                vendor: $ocrVendor,
                receiptNumber: $ocrNumber
            )
        }
        .onChange(of: selectedReceiptImage) { _, newItem in
            guard let item = newItem else { return }
            isScanningReceipt = true
            ocrScanFailed = false
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    await MainActor.run { isScanningReceipt = false }
                    return
                }
                await MainActor.run { receiptImageData = data }

                let result: OCRReceiptResult? = await withCheckedContinuation { continuation in
                    guard let image = UIImage(data: data) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    OCRService.extractReceiptInfo(from: image) { ocrResult in
                        continuation.resume(returning: ocrResult)
                    }
                }

                await MainActor.run {
                    isScanningReceipt = false
                    guard let result,
                          result.amount != nil || result.date != nil || result.vendor != nil || result.receiptNumber != nil
                    else {
                        ocrScanFailed = true
                        return
                    }

                    ocrAmount = result.amount
                    ocrDate = result.date
                    ocrVendor = result.vendor
                    ocrNumber = result.receiptNumber

                    if receiptCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let num = result.receiptNumber {
                        receiptCode = num
                    }

                    showOCRReview = true
                }
            }
        }
    }

    private var lockedState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
                .accessibilityHidden(true)
            Text("Fuel Logging Locked")
                .font(.title2.weight(.bold))
            Text("Fuel can only be logged during an active trip or within 2 hours of its completion.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 32)
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
                        .font(.largeTitle.weight(.heavy))
                        .foregroundColor(.white)
                }
                Spacer()
                Image(systemName: "fuelpump.fill")
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

            DatePicker("Date & Time", selection: $refillDate, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: [.date, .hourAndMinute])

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
            .accessibilityLabel("Attach Receipt Image")

            if isScanningReceipt {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Scanning receipt…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityLabel("Scanning Receipt")
            }

            if ocrScanFailed {
                Text("Couldn't read the receipt automatically — you can still enter the details below.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("OCR Scan Failed")
                    .padding(.vertical, 4)
            }

            if ocrAmount != nil || ocrDate != nil || ocrVendor != nil || ocrNumber != nil {
                Button(action: { showOCRReview = true }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Review OCR Data")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
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
        localStore.lastFuelSaveError = nil

        Task {
            await localStore.saveFuelEntry(
                vehicleId: vehicleId ?? UUID(),
                tripId: activeTripId ?? "",
                fuelType: selectedFuelType,
                liters: quantityValue,
                price: quantityValue * priceValue,
                receiptCode: receiptCode.trimmingCharacters(in: .whitespacesAndNewlines),
                date: refillDate
            )

            if let error = localStore.lastFuelSaveError {
                await MainActor.run {
                    saveErrorMessage = error
                    showingSaveError = true
                }
                return
            }

            if let expenseService, let driverId, let vehicleId {
                var ocrData: String?
                if ocrAmount != nil || ocrDate != nil || ocrVendor != nil || ocrNumber != nil {
                    let dict: [String: String?] = [
                        "amount": ocrAmount, "date": ocrDate,
                        "vendor": ocrVendor, "receiptNumber": ocrNumber
                    ]
                    ocrData = (try? JSONSerialization.data(withJSONObject: dict.compactMapValues { $0 }))
                        .flatMap { String(data: $0, encoding: .utf8) }
                }

                let entry = ExpenseEntry(
                    id: UUID(),
                    tripId: activeTripId.flatMap { UUID(uuidString: $0) },
                    vehicleId: vehicleId,
                    driverId: driverId,
                    expenseType: "fuel",
                    liters: quantityValue,
                    costPerLiter: priceValue,
                    fuelType: selectedFuelType.rawValue.lowercased(),
                    totalCost: quantityValue * priceValue,
                    odometerReading: nil,
                    receiptImageUrl: nil,
                    receiptOcrData: ocrData,
                    locationLat: nil,
                    locationLng: nil,
                    notes: nil,
                    createdAt: refillDate
                )
                _ = try? await expenseService.createExpense(entry)
            }

            await MainActor.run {
                liters = ""
                pricePerLiter = ""
                receiptCode = ""
                refillDate = Date()
                selectedReceiptImage = nil
                ocrAmount = nil
                ocrDate = nil
                ocrVendor = nil
                ocrNumber = nil
                receiptImageData = nil
                showingSavedAlert = true
            }
        }
    }
}
struct OCRReviewView: View {
    @Environment(\.dismiss) var dismiss

    @Binding var amount: String?
    @Binding var date: String?
    @Binding var vendor: String?
    @Binding var receiptNumber: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("OCR Extracted Data")) {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("e.g. ₹1,500", text: Binding(
                            get: { amount ?? "" },
                            set: { amount = $0.isEmpty ? nil : $0 }
                        ))
                        .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Date")
                        Spacer()
                        TextField("e.g. 15/06/26", text: Binding(
                            get: { date ?? "" },
                            set: { date = $0.isEmpty ? nil : $0 }
                        ))
                        .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Vendor")
                        Spacer()
                        TextField("e.g. IndianOil", text: Binding(
                            get: { vendor ?? "" },
                            set: { vendor = $0.isEmpty ? nil : $0 }
                        ))
                        .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Receipt No.")
                        Spacer()
                        TextField("e.g. INV-001", text: Binding(
                            get: { receiptNumber ?? "" },
                            set: { receiptNumber = $0.isEmpty ? nil : $0 }
                        ))
                        .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Review Receipt Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
                Label("\((record.volumeFilled ?? 0), specifier: "%.1f") \(record.refillUnit)", systemImage: record.fuelType == .cng ? "flame.fill" : "drop.fill")
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
