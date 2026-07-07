import SwiftUI

struct ReportExportToolbarItem: View {
    let reportType: ReportType
    let viewModel: ReportsViewModel

    var body: some View {
        Menu("Export", systemImage: "square.and.arrow.up") {
            ShareLink(item: csvURL, preview: SharePreview(reportType.rawValue))
            ShareLink(item: pdfURL, preview: SharePreview(reportType.rawValue))
        }
    }

    private var csvString: String {
        ReportExporter.csvString(for: reportType, viewModel: viewModel)
    }

    private var csvURL: URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(reportType.filename).csv")
        try? csvString.write(to: url, atomically: true, encoding: .utf8)
        return url
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
