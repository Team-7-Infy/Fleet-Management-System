import Foundation
import Combine

class DocumentViewModel: ObservableObject {
    @Published var documents: [FleetDocument] = []
    @Published var selectedCategory: FleetDocument.DocumentCategory = .driver
    
    init() {
        fetchDocuments()
    }
    
    var filteredDocuments: [FleetDocument] {
        documents.filter { $0.type == selectedCategory }
    }
    
    var alertCount: Int {
        documents.filter { $0.isUploaded && ($0.status == .critical || $0.status == .expired) }.count
    }
    
    private func fetchDocuments() {
        let calendar = Calendar.current
        let today = Date()
        
        self.documents = [
            FleetDocument(title: "Commercial Driving License", type: .driver, expiryDate: calendar.date(byAdding: .day, value: 12, to: today)!, documentURL: "https://example.com/license.pdf"),
            FleetDocument(title: "Medical Fitness Certificate", type: .driver, expiryDate: calendar.date(byAdding: .day, value: -2, to: today)!, documentURL: nil),
            FleetDocument(title: "Background Check", type: .driver, expiryDate: calendar.date(byAdding: .month, value: 6, to: today)!, documentURL: nil)
        ]
    }
}
