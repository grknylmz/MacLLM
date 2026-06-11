import SwiftUI

struct DownloadView: View {
    let hfClient: HuggingFaceClient
    let modelManager: ModelManager
    let serverManager: ServerManager
    let pythonEnvManager: PythonEnvManager

    @State private var searchText = ""
    @State private var downloadProgress: [String: Double] = [:]
    @State private var downloadingModels: Set<String> = []
    @State private var downloadTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DOWNLOAD NEW MODEL")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            HStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    TextField("Search HuggingFace or paste model ID...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .onSubmit {
                            performSearch()
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.gray.opacity(0.1))
                .cornerRadius(6)

                Button {
                    performSearch()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .disabled(searchText.isEmpty)
            }
            .padding(.horizontal, 12)

            if hfClient.isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if !hfClient.searchResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(hfClient.searchResults) { model in
                            HFModelRow(
                                model: model,
                                isDownloading: downloadingModels.contains(model.id),
                                progress: downloadProgress[model.id] ?? 0,
                                isInstalled: isModelInstalled(model.id),
                                onDownload: {
                                    downloadModel(model.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .frame(maxHeight: 160)
            } else if let error = hfClient.error {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
            }
        }
    }

    private func performSearch() {
        downloadTask?.cancel()
        downloadTask = Task {
            if searchText.contains("/") {
                await hfClient.search(query: searchText)
            } else if searchText.isEmpty {
                await hfClient.searchPopularMLX()
            } else {
                await hfClient.search(query: searchText)
            }
        }
    }

    private func isModelInstalled(_ modelId: String) -> Bool {
        modelManager.installedModels.contains { $0.fullName == modelId }
    }

    private func downloadModel(_ modelId: String) {
        guard pythonEnvManager.isReady else { return }
        downloadingModels.insert(modelId)
        downloadProgress[modelId] = 0

        Task {
            let cacheName = Constants.hfModelsPrefix + modelId.replacingOccurrences(of: "/", with: "--")
            let modelCacheURL = Constants.hfCacheURL.appendingPathComponent(cacheName)

            let hfDownloadPath = Constants.venvURL
                .appendingPathComponent("bin/huggingface-cli")
                .path

            let result = try? await ProcessRunner.runWithOutput(
                executable: hfDownloadPath,
                arguments: ["download", modelId],
                onStdout: { output in
                    if output.contains("Fetching") || output.contains("Download") {
                        let patterns = ["(\\d+\\.?\\d*)%", "(\\d+)/(\\d+)"]
                        for pattern in patterns {
                            if let regex = try? NSRegularExpression(pattern: pattern),
                               let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)) {
                                if pattern == patterns[0] {
                                    if let range = Range(match.range(at: 1), in: output),
                                       let value = Double(output[range]) {
                                        downloadProgress[modelId] = value / 100.0
                                    }
                                }
                            }
                        }
                    }
                },
                onStderr: { _ in }
            )

            downloadingModels.remove(modelId)
            downloadProgress.removeValue(forKey: modelId)

            await modelManager.refreshModels()

            if let result, result.success, serverManager.activeModel == nil {
                await serverManager.start(model: modelId)
            }
        }
    }
}

struct HFModelRow: View {
    let model: HFModel
    let isDownloading: Bool
    let progress: Double
    let isInstalled: Bool
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(model.id)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let downloads = model.downloads {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 8))
                        Text(model.formattedDownloads)
                    }
                    if let tags = model.tags {
                        ForEach(tags.prefix(3), id: \.self) { tag in
                            if tag.hasPrefix("mlx") || tag.contains("bit") {
                                Text(tag)
                                    .font(.system(size: 8))
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(.blue.opacity(0.12))
                                    .cornerRadius(2)
                            }
                        }
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isDownloading {
                VStack(spacing: 2) {
                    ProgressView(value: progress)
                        .frame(width: 60)
                        .controlSize(.small)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            } else if isInstalled {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
            } else {
                Button {
                    onDownload()
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.04))
        )
    }
}
