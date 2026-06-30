import SwiftUI

struct DocumentCenterView: View {
    @StateObject private var viewModel = DocumentViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.alertCount > 0 {
                HStack {
                    Image(systemName: "exclamationmark.octagon.fill")
                    Text("You have \(viewModel.alertCount) document(s) requiring immediate attention.")
                        .font(.caption)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
            }

            List {
                ForEach(viewModel.filteredDocuments) { document in
                    DocumentRowView(document: document)
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .navigationTitle("Document Center")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DocumentRowView: View {
    let document: FleetDocument
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                
                Text("Expires: \(document.expiryDate, style: .date)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack {
                Text(daysRemainingText)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch document.status {
        case .notUploaded: return .gray
        case .valid: return .green
        case .warning: return .orange
        case .critical: return .red
        case .expired: return .gray
        }
    }
    
    private var statusIcon: String {
        switch document.status {
        case .notUploaded: return "tray.fill"
        case .valid: return "checkmark.shield.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.shield.fill"
        case .expired: return "lock.fill"
        }
    }
    
    private var daysRemainingText: String {
        guard document.isUploaded else {
            return "Not Uploaded"
        }
        if document.daysRemaining < 0 {
            return "Expired"
        } else if document.daysRemaining == 0 {
            return "Expires Today"
        } else {
            return "\(document.daysRemaining) Days"
        }
    }
}

