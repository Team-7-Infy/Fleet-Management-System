import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    @State private var phase: Phase = .loading
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    enum Phase {
        case loading
        case success(Image)
        case failure
    }

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                placeholder()
            case .success(let image):
                content(image)
            case .failure:
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else {
            phase = .failure
            return
        }

        if let cached = ImageCache.shared.image(for: url) {
            phase = .success(Image(uiImage: cached))
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                ImageCache.shared.setImage(uiImage, for: url)
                phase = .success(Image(uiImage: uiImage))
            } else {
                phase = .failure
            }
        } catch {
            phase = .failure
        }
    }
}
