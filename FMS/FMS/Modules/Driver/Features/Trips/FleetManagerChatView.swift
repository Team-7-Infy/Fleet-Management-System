//
//  FleetManagerChatView.swift
//  FMSD
//
//  Created by Dev Jain on 26/06/26.
//

import SwiftUI
import Combine

// MARK: - Message Model
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let sender: SenderType
    let text: String
    let timestamp: Date
    
    enum SenderType {
        case driver
        case manager
    }
}

// MARK: - Chat ViewModel
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    
    init() {
        loadMockMessages()
    }
    
    private func loadMockMessages() {
        let now = Date()
        messages = [
            ChatMessage(sender: .manager, text: "Hi Alex, this is John from Fleet Dispatch. I see you are en route to Pune.", timestamp: now.addingTimeInterval(-600)),
            ChatMessage(sender: .driver, text: "Yes, John. Cleared the yard and navigating now.", timestamp: now.addingTimeInterval(-500)),
            ChatMessage(sender: .manager, text: "Great. Drive safe, let me know if you run into any checkpoints.", timestamp: now.addingTimeInterval(-450))
        ]
    }
    
    func sendMessage() {
        let cleanText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        
        let newMsg = ChatMessage(sender: .driver, text: cleanText, timestamp: Date())
        messages.append(newMsg)
        inputText = ""
        
        HapticManager.shared.triggerImpact(style: .light)
        
        // Simulated response from John the Fleet Manager
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            let replyText = self.generateManagerReply(for: cleanText)
            let replyMsg = ChatMessage(sender: .manager, text: replyText, timestamp: Date())
            self.messages.append(replyMsg)
            HapticManager.shared.triggerNotification(type: .success)
        }
    }
    
    private func generateManagerReply(for text: String) -> String {
        let message = text.lowercased()
        if message.contains("delay") || message.contains("traffic") || message.contains("jam") {
            return "Copy that, Alex. We'll update the warehouse of the delay."
        } else if message.contains("fuel") || message.contains("diesel") || message.contains("refill") {
            return "Roger. Please submit the refill request and log the receipt in the Fuel history view."
        } else if message.contains("break") || message.contains("rest") || message.contains("stop") {
            return "Copy. Make sure to log it on your duty logbook. Take your full rest."
        } else if message.contains("weather") || message.contains("rain") || message.contains("storm") {
            return "Safety first. Slow down or pull over if visibility drops."
        } else if message.contains("inspected") || message.contains("checklist") {
            return "Yes, pre-trip inspection is updated in our portal. Thanks."
        } else {
            return "Understood. Keep proceeding as scheduled. Safe driving!"
        }
    }
}

// MARK: - Chat View
struct FleetManagerChatView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ChatViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Active Fleet Manager Status Banner
                HStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "person.badge.shield.checkmark.fill")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                            )
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle().stroke(Color(UIColor.systemBackground), lineWidth: 2)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("John Doe")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Fleet Manager (Dispatch Unit 3)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                
                // Chat bubbles
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { msg in
                                ChatBubbleRow(message: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages) { oldValue, newValue in
                        if let lastId = newValue.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let lastId = viewModel.messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                
                // Chat Input bar
                Divider()
                HStack(spacing: 12) {
                    TextField("Type a message to John...", text: $viewModel.inputText)
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .font(.subheadline)
                        .accessibilityLabel("Chat message text input")
                    
                    Button(action: {
                        viewModel.sendMessage()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                            .clipShape(Circle())
                            .shadow(color: viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.clear : Color.blue.opacity(0.2), radius: 6)
                            .accessibilityLabel("Send message")
                    }
                    .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
            }
            .navigationTitle("Manager Dispatch Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        HapticManager.shared.triggerImpact(style: .light)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Chat Bubble Row
struct ChatBubbleRow: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.sender == .driver {
                Spacer()
            }
            
            VStack(alignment: message.sender == .driver ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundColor(message.sender == .driver ? .white : .primary)
                    .background(
                        message.sender == .driver ? Color.blue : Color(UIColor.systemGray5)
                    )
                    .cornerRadius(16, corners: message.sender == .driver ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                
                Text(formatTime(message.timestamp))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            if message.sender == .manager {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Rounded Corner Helper
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
