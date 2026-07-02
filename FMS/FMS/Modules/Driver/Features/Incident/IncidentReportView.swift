//
//  IncidentReportView.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import SwiftUI
import CoreLocation

struct IncidentReportView: View {
    @StateObject private var viewModel = IncidentViewModel()
    @EnvironmentObject var locationManager: LocationManager // Injected from App environment
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            // Section 1: Incident Type
            Section(header: Text("What Happened?")) {
                Picker("Incident Type", selection: $viewModel.selectedType) {
                    ForEach(Incident.IncidentType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }
            
            // Section 2: Details
            Section(header: Text("Description of Event")) {
                TextEditor(text: $viewModel.incidentDescription)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            
            // Section 3: Evidence (Photos)
            Section(header: Text("Photographic Evidence"), footer: Text("Please include wide shots and close-ups of any damage.")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(viewModel.capturedPhotos, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .overlay(Image(systemName: "photo").foregroundColor(.gray))
                        }
                        
                        Button(action: {
                            viewModel.simulatePhotoCapture()
                        }) {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    VStack {
                                        Image(systemName: "camera.fill")
                                        Text("Add")
                                            .font(.caption)
                                    }
                                )
                                .foregroundColor(FleetPalette.inProgress)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Section 4: Location Context
            Section(header: Text("Location Data")) {
                if let location = locationManager.location {
                    HStack {
                        Image(systemName: "location.fill").foregroundColor(FleetPalette.success)
                        Text("GPS Coordinates Captured")
                            .font(.subheadline)
                        Spacer()
                    }
                } else {
                    HStack {
                        Image(systemName: "location.slash.fill").foregroundColor(FleetPalette.danger)
                        Text("Location Unavailable")
                            .font(.subheadline)
                    }
                }
            }
            
            // Section 5: Submit Action
            Section {
                Button(action: {
                    viewModel.submitReport(currentLocation: locationManager.location)
                }) {
                    HStack {
                        Spacer()
                        if viewModel.isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding(.trailing, 8)
                        }
                        Text(viewModel.isSubmitting ? "Submitting Report..." : "Submit Incident Report")
                            .fontWeight(.bold)
                        Spacer()
                    }
                }
                .foregroundColor(viewModel.isValid ? FleetPalette.danger : .gray)
                .disabled(!viewModel.isValid || viewModel.isSubmitting)
            }
        }
        .navigationTitle("Report Incident")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .alert(isPresented: $viewModel.submissionSuccess) {
            Alert(
                title: Text("Report Submitted"),
                message: Text("The Fleet Manager has been notified. Please await further instructions."),
                dismissButton: .default(Text("Understood")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
