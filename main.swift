import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ImageIO

@main
struct ImageCompressorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 760, minHeight: 520)
        }
    }
}

struct ContentView: View {
    @State private var inputURLs: [URL] = []
    @State private var outputFolder: URL?
    @State private var format: OutputFormat = .jpeg
    @State private var quality: Double = 0.72
    @State private var maxWidth: Double = 1600
    @State private var preserveMetadata = false
    @State private var isCompressing = false
    @State private var logs: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mac Image Compressor")
                .font(.title2).bold()

            HStack(spacing: 10) {
                Button("Select Images") { chooseImages() }
                Button("Select Output Folder") { chooseOutputFolder() }
                Text(outputFolder?.path(percentEncoded: false) ?? "No output folder selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack {
                Picker("Output format", selection: $format) {
                    ForEach(OutputFormat.allCases, id: \.self) { f in
                        Text(f.displayName).tag(f)
                    }
                }
                .frame(width: 220)

                VStack(alignment: .leading) {
                    Text("Quality: \(Int(quality * 100))")
                    Slider(value: $quality, in: 0.1...1.0)
                }

                VStack(alignment: .leading) {
                    Text("Max width: \(Int(maxWidth)) px")
                    Slider(value: $maxWidth, in: 400...5000, step: 50)
                }
            }

            Toggle("Preserve metadata", isOn: $preserveMetadata)

            Text("Selected files: \(inputURLs.count)")
                .font(.subheadline)

            List(inputURLs, id: \.self) { url in
                Text(url.lastPathComponent)
                    .font(.system(.body, design: .monospaced))
            }
            .frame(minHeight: 220)

            HStack {
                Button(isCompressing ? "Compressing..." : "Compress Now") {
                    Task { await compress() }
                }
                .disabled(isCompressing || inputURLs.isEmpty || outputFolder == nil)

                Button("Clear Logs") { logs.removeAll() }
                Spacer()
            }

            List(logs.indices, id: \.self) { i in
                Text(logs[i]).font(.caption)
            }
            .frame(height: 130)
        }
        .padding(16)
    }

    private func chooseImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .gif, .bmp, .webP]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK {
            inputURLs = panel.urls
        }
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK {
            outputFolder = panel.url
        }
    }

    @MainActor
    private func compress() async {
        guard let outputFolder else { return }
        isCompressing = true
        logs.removeAll()

        for url in inputURLs {
            do {
                let sourceData = try Data(contentsOf: url)
                guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    logs.append("❌ Failed to read \(url.lastPathComponent)")
                    continue
                }

                let resized = resize(image: image, maxWidth: Int(maxWidth))
                let ext = format.fileExtension
                let destURL = outputFolder.appendingPathComponent(url.deletingPathExtension().lastPathComponent + "-compressed." + ext)

                guard let dest = CGImageDestinationCreateWithURL(destURL as CFURL, format.utType.identifier as CFString, 1, nil) else {
                    logs.append("❌ Failed to create output for \(url.lastPathComponent)")
                    continue
                }

                var props: [CFString: Any] = [
                    kCGImageDestinationLossyCompressionQuality: quality
                ]

                if preserveMetadata,
                   let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                    for (k, v) in metadata { props[k] = v }
                }

                CGImageDestinationAddImage(dest, resized, props as CFDictionary)
                let ok = CGImageDestinationFinalize(dest)
                if !ok {
                    logs.append("❌ Failed to write \(destURL.lastPathComponent)")
                    continue
                }

                let originalBytes = sourceData.count
                let compressedBytes = (try? Data(contentsOf: destURL).count) ?? 0
                let savedPercent = originalBytes > 0 ? (1.0 - (Double(compressedBytes) / Double(originalBytes))) * 100 : 0
                logs.append("✅ \(url.lastPathComponent) → \(destURL.lastPathComponent) | \(human(originalBytes)) -> \(human(compressedBytes)) | -\(Int(savedPercent))%")

            } catch {
                logs.append("❌ \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        isCompressing = false
    }

    private func resize(image: CGImage, maxWidth: Int) -> CGImage {
        let width = image.width
        let height = image.height
        guard width > maxWidth else { return image }

        let scale = CGFloat(maxWidth) / CGFloat(width)
        let newSize = CGSize(width: CGFloat(width) * scale, height: CGFloat(height) * scale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(origin: .zero, size: newSize))
        return ctx.makeImage() ?? image
    }

    private func human(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var b = Double(bytes)
        var idx = 0
        while b >= 1024 && idx < units.count - 1 {
            b /= 1024
            idx += 1
        }
        return String(format: "%.1f%@", b, units[idx])
    }
}

enum OutputFormat: CaseIterable {
    case jpeg
    case png
    case heic
    case webp

    var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        case .webp: return "WebP"
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .webp: return "webp"
        }
    }

    var utType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        case .webp: return .webP
        }
    }
}
