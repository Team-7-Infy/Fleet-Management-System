import SwiftUI

struct EndTripView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var endOdometer: String = ""
    @State private var tripNotes: String = ""
    @State private var isSubmitting: Bool = false
    
    // Signature State
    @State private var signaturePath = Path()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // 1. Header Details
                        VStack(spacing: 8) {
                            Text("Finalize Trip")
                                .font(.title2)
                                .fontWeight(.black)
                        }
                        .padding(.top, 20)
                        
                        // 2. Data Entry Card
                        VStack(spacing: 0) {
                            HStack {
                                Text("End Odometer")
                                    .fontWeight(.medium)
                                Spacer()
                                TextField("e.g. 45120", text: $endOdometer)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.blue)
                                    .font(.system(.body, design: .monospaced))
                            }
                            .padding()
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Delivery Notes (Optional)")
                                    .fontWeight(.medium)
                                TextEditor(text: $tripNotes)
                                    .frame(height: 80)
                                    .padding(8)
                                    .background(Color(.tertiarySystemFill))
                                    .cornerRadius(8)
                            }
                            .padding()
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // 3. Digital Signature Pad
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Customer Signature")
                                    .fontWeight(.bold)
                                Spacer()
                                Button(action: { signaturePath = Path() }) {
                                    Text("Clear")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            // Native SwiftUI Drawing Canvas
                            SignatureCanvas(path: $signaturePath)
                                .frame(height: 150)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                                )
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // 4. Submit Button
                        Button(action: submitTrip) {
                            HStack {
                                Spacer()
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 8)
                                }
                                Text(isSubmitting ? "Syncing Data..." : "Confirm & End Trip")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            .padding()
                            .background(canSubmit ? Color.black : Color.gray.opacity(0.3))
                            .foregroundColor(canSubmit ? .white : .gray)
                            .cornerRadius(16)
                        }
                        .disabled(!canSubmit || isSubmitting)
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    // Validation: Odometer must be entered and signature cannot be empty
    private var canSubmit: Bool {
        !endOdometer.isEmpty && !signaturePath.isEmpty
    }
    
    private func submitTrip() {
        isSubmitting = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isSubmitting = false
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Reusable Signature Canvas Component
struct SignatureCanvas: View {
    @Binding var path: Path
    
    var body: some View {
        GeometryReader { geometry in
            path.stroke(Color.primary, lineWidth: 3)
                .background(Color.clear)
                .gesture(
                    DragGesture(minimumDistance: 0.1)
                        .onChanged { value in
                            let currentPoint = value.location
                            if value.translation.width == 0 && value.translation.height == 0 {
                                path.move(to: currentPoint)
                            } else {
                                path.addLine(to: currentPoint)
                            }
                        }
                )
        }
    }
}
