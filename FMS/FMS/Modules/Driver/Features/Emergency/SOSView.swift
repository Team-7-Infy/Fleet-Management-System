//
//  SOSView.swift
//  FMSD
//
//  Created by Dev Jain on 24/06/26.
//


import SwiftUI

struct SOSView: View {
    @StateObject private var viewModel = SOSViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.presentationMode) var presentationMode
    
    // Animation states
    @State private var isPressing = false
    @State private var progress: CGFloat = 0.0
    private let holdDuration: Double = 2.0 // Hold for 2 seconds to trigger
    
    var body: some View {
        ZStack {
            // Dark, high-contrast background
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 40) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "light.beacon.max.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Emergency SOS")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(viewModel.isActivated ? "SOS Triggered" : "Hold the button for 2 seconds to immediately notify the Fleet Manager and local authorities.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Main Interactive Area
                if viewModel.alertSent {
                    // Success State
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                        
                        Text("Authorities Dispatched")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Stay calm. Help is on the way to your exact GPS location.")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                } else if viewModel.isActivated {
                    // Countdown State
                    VStack(spacing: 30) {
                        Text("\(viewModel.countdown)")
                            .font(.system(size: 120, weight: .bold, design: .rounded))
                            .foregroundColor(.red)
                        
                        Text("Sending alert in...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Button(action: {
                            viewModel.cancelSOS()
                        }) {
                            Text("CANCEL SOS")
                                .font(.title3)
                                .fontWeight(.bold)
                                .frame(width: 250, height: 60)
                                .background(Color.white.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(30)
                        }
                    }
                } else {
                    // Hold to Activate State
                    ZStack {
                        // Background Track
                        Circle()
                            .stroke(lineWidth: 8)
                            .foregroundColor(Color.red.opacity(0.3))
                            .frame(width: 220, height: 220)
                        
                        // Progress Indicator
                        Circle()
                            .trim(from: 0.0, to: progress)
                            .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.red)
                            .frame(width: 220, height: 220)
                            .rotationEffect(Angle(degrees: -90))
                        
                        // Central Button
                        Circle()
                            .fill(isPressing ? Color.red.opacity(0.8) : Color.red)
                            .frame(width: 180, height: 180)
                            .shadow(color: .red.opacity(0.5), radius: isPressing ? 20 : 10)
                            .overlay(
                                Text("SOS")
                                    .font(.system(size: 50, weight: .black))
                                    .foregroundColor(.white)
                            )
                    }
                    // Custom Gesture Logic
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isPressing {
                                    isPressing = true
                                    withAnimation(.linear(duration: holdDuration)) {
                                        progress = 1.0
                                    }
                                    // Trigger after hold duration
                                    DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
                                        if isPressing {
                                            viewModel.triggerSOSSequence(currentLocation: locationManager.location)
                                            progress = 0
                                            isPressing = false
                                        }
                                    }
                                }
                            }
                            .onEnded { _ in
                                if isPressing {
                                    isPressing = false
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        progress = 0.0
                                    }
                                }
                            }
                    )
                    
                    Text("PRESS AND HOLD")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                }
                
                Spacer()
                
                // Dismiss Button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Close")
                        .foregroundColor(.gray)
                        .padding()
                }
                .disabled(viewModel.isActivated && !viewModel.alertSent) // Disable close during countdown
            }
        }
    }
}