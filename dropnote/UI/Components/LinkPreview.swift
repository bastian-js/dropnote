import SwiftUI
import LinkPresentation
import AppKit

/// Fetches and caches rich metadata (title + favicon) for URLs.
final class LinkPreviewCache {
    static let shared = LinkPreviewCache()
    private let cache = NSCache<NSURL, LPLinkMetadata>()

    func fetch(_ url: URL, completion: @escaping (LPLinkMetadata?) -> Void) {
        if let cached = cache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }
        let provider = LPMetadataProvider()
        provider.timeout = 8
        provider.startFetchingMetadata(for: url) { [weak self] metadata, _ in
            DispatchQueue.main.async {
                if let metadata { self?.cache.setObject(metadata, forKey: url as NSURL) }
                completion(metadata)
            }
        }
    }
}

/// Observable wrapper around a single link's loaded preview.
final class LinkPreviewItem: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL
    @Published var title: String
    @Published var icon: NSImage?

    init(url: URL) {
        self.url = url
        self.title = url.host ?? url.absoluteString
        load()
    }

    private func load() {
        LinkPreviewCache.shared.fetch(url) { [weak self] meta in
            guard let self, let meta else { return }
            if let t = meta.title, !t.isEmpty { self.title = t }
            let provider = meta.iconProvider ?? meta.imageProvider
            provider?.loadObject(ofClass: NSImage.self) { obj, _ in
                guard let img = obj as? NSImage else { return }
                DispatchQueue.main.async { self.icon = img }
            }
        }
    }
}

/// A horizontal strip of compact preview cards for every link found in `text`.
struct LinkPreviewStrip: View {
    let text: String
    @State private var items: [LinkPreviewItem] = []

    var body: some View {
        Group {
            if !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items) { LinkPreviewCard(item: $0) }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .onAppear { rebuild(text) }
        .onChange(of: text) { _, newValue in rebuild(newValue) }
    }

    private func rebuild(_ text: String) {
        let urls = Self.detectURLs(in: text)
        // Reuse already-loaded items so we don't refetch on every keystroke.
        let next: [LinkPreviewItem] = urls.prefix(5).map { url in
            items.first(where: { $0.url == url }) ?? LinkPreviewItem(url: url)
        }
        if next.map(\.url) != items.map(\.url) {
            items = next
        }
    }

    static func detectURLs(in text: String) -> [URL] {
        guard !text.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let ns = text as NSString
        let matches = detector.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var seen = Set<String>()
        var urls: [URL] = []
        for match in matches {
            guard let url = match.url, url.scheme?.hasPrefix("http") == true,
                  !seen.contains(url.absoluteString) else { continue }
            seen.insert(url.absoluteString)
            urls.append(url)
        }
        return urls
    }
}

/// Wraps the card with a trailing spacer so it stays flush-left inside a wider
/// host frame (NSHostingView centers a bare compact view, which drifts it right).
struct LinkPreviewSlot: View {
    @ObservedObject var item: LinkPreviewItem

    var body: some View {
        HStack(spacing: 0) {
            LinkPreviewCard(item: item)
            Spacer(minLength: 0)
        }
    }
}

struct LinkPreviewCard: View {
    @ObservedObject var item: LinkPreviewItem
    @State private var isHovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(item.url)
        } label: {
            HStack(spacing: 7) {
                ZStack {
                    if let icon = item.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else {
                        Image(systemName: "link")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(item.url.host ?? item.url.absoluteString)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: 190, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.primary.opacity(isHovering ? 0.1 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(item.url.absoluteString)
    }
}
