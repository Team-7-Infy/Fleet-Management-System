import SwiftUI

struct ReportExportToolbarItem: View {
    let reportType: ReportType
    let viewModel: ReportsViewModel

    var body: some View {
        ShareLink(item: pdfURL, preview: SharePreview(reportType.rawValue)) {
            Label("Export", systemImage: "square.and.arrow.up")
        }
    }

    private var pdfData: Data {
        ReportExporter.pdfData(for: reportType, viewModel: viewModel)
    }

    private var pdfURL: URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(reportType.filename).pdf")
        try? pdfData.write(to: url)
        return url
    }
}
