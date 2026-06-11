import SwiftUI
import os

private let downloadLog = Logger(subsystem: "com.macllm", category: "Download")

func debugLog(_ message: String) {
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let line = "[\(timestamp)] \(message)\n"
    let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".macllm/download_debug.log")
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logURL.path) {
            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: logURL)
        }
    }
    downloadLog.info("\(message)")
}

struct DownloadView: View {
    let hfClient: HuggingFaceClient
    let modelManager: ModelManager
    let serverManager: ServerManager
    let pythonEnvManager: PythonEnvManager
    let downloadManager: DownloadManager

    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showFilters = false
    @State private var sortOption: HFSortOption = .trending
    @State private var taskFilter: HFTaskFilter = .all
    @State private var libraryFilter: HFLibraryFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            activeDownloadsSection

            Divider().padding(.horizontal, 8)

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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showFilters.toggle()
                    }
                } label: {
                    Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(hasActiveFilters ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .help("Filters")

                Button {
                    performSearch()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .disabled(searchText.isEmpty && !hasActiveFilters)
            }
            .padding(.horizontal, 12)

            if showFilters {
                filterBar
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

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
                                state: downloadManager.state(for: model.id),
                                isInstalled: isModelInstalled(model.id),
                                onDownload: {
                                    downloadManager.startDownload(model.id)
                                },
                                onPause: {
                                    downloadManager.pauseDownload(model.id)
                                },
                                onResume: {
                                    downloadManager.resumeDownload(model.id)
                                },
                                onStop: {
                                    downloadManager.stopDownload(model.id)
                                },
                                onRestart: {
                                    downloadManager.startDownload(model.id)
                                },
                                onClear: {
                                    downloadManager.clearDownload(model.id)
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

    private var hasActiveFilters: Bool {
        sortOption != .trending || taskFilter != .all || libraryFilter != .all
    }

    @ViewBuilder
    private var filterBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                filterPicker(
                    title: "Sort",
                    selection: $sortOption,
                    options: HFSortOption.allCases
                )

                filterPicker(
                    title: "Task",
                    selection: $taskFilter,
                    options: HFTaskFilter.allCases
                )

                filterPicker(
                    title: "Library",
                    selection: $libraryFilter,
                    options: HFLibraryFilter.allCases
                )

                Spacer()

                if hasActiveFilters {
                    Button("Reset") {
                        sortOption = .trending
                        taskFilter = .all
                        libraryFilter = .all
                        performSearch()
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.blue)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .background(.gray.opacity(0.04))
        .cornerRadius(6)
        .padding(.horizontal, 12)
    }

    private func filterPicker<T: RawRepresentable & CaseIterable & Hashable>(
        title: String,
        selection: Binding<T>,
        options: T.AllCases
    ) -> some View where T.RawValue == String {
        Menu {
            ForEach(Array(options), id: \.rawValue) { option in
                Button {
                    selection.wrappedValue = option
                    performSearch()
                } label: {
                    if selection.wrappedValue.rawValue == option.rawValue {
                        Image(systemName: "checkmark")
                    }
                    Text(option.rawValue)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(selection.wrappedValue.rawValue)
                    .font(.system(size: 10))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private var activeDownloadsSection: some View {
        let active = downloadManager.downloads.filter { $0.value.isActive || $0.value.isFailed }
        let completed = downloadManager.completedDownloads.filter { downloadManager.downloads[$0]?.isCompleted == true }

        if !active.isEmpty || !completed.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIVE DOWNLOADS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(active.sorted(by: { $0.key < $1.key }), id: \.key) { modelId, state in
                            ActiveDownloadRow(
                                modelId: modelId,
                                state: state,
                                onPause: { downloadManager.pauseDownload(modelId) },
                                onResume: { downloadManager.resumeDownload(modelId) },
                                onStop: { downloadManager.stopDownload(modelId) },
                                onRestart: { downloadManager.startDownload(modelId) },
                                onClear: { downloadManager.clearDownload(modelId) }
                            )
                        }

                        ForEach(completed, id: \.self) { modelId in
                            ActiveDownloadRow(
                                modelId: modelId,
                                state: .completed,
                                onPause: {},
                                onResume: {},
                                onStop: {},
                                onRestart: {},
                                onClear: { downloadManager.clearDownload(modelId) }
                            )
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .frame(maxHeight: 120)
            }
        }
    }

    private func performSearch() {
        searchTask?.cancel()
        debugLog("performSearch: query='\(searchText)' sort=\(sortOption.rawValue) task=\(taskFilter.rawValue) library=\(libraryFilter.rawValue)")
        searchTask = Task {
            await hfClient.search(
                query: searchText,
                sort: sortOption,
                task: taskFilter,
                library: libraryFilter
            )
            debugLog("Search completed. Results: \(hfClient.searchResults.count), error: \(hfClient.error ?? "nil")")
        }
    }

    private func isModelInstalled(_ modelId: String) -> Bool {
        modelManager.installedModels.contains { $0.fullName == modelId }
    }
}

struct ActiveDownloadRow: View {
    let modelId: String
    let state: DownloadState
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            statusIcon

            VStack(alignment: .leading, spacing: 1) {
                Text(modelId)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                statusText
            }

            Spacer()

            controlButtons
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .downloading:
            ProgressView(value: state.progress)
                .frame(width: 30, height: 12)
                .controlSize(.mini)
        case .paused:
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch state {
        case .downloading(let progress):
            Text("Downloading... \(Int(progress * 100))%")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        case .paused:
            Text("Paused — tap resume to continue")
                .font(.system(size: 9))
                .foregroundStyle(.orange)
        case .failed(let msg):
            Text(msg)
                .font(.system(size: 9))
                .foregroundStyle(.red)
                .lineLimit(1)
        case .completed:
            Text("Download complete")
                .font(.system(size: 9))
                .foregroundStyle(.green)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var controlButtons: some View {
        HStack(spacing: 4) {
            switch state {
            case .downloading:
                Button { onPause() } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 10))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
                .help("Pause")

                Button { onStop() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help("Stop")

            case .paused:
                Button { onResume() } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.green)
                .help("Resume")

                Button { onStop() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help("Stop")

            case .failed:
                Button { onRestart() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .help("Restart")

                Button { onClear() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear")

            case .completed:
                Button { onClear() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear")

            default:
                EmptyView()
            }
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .downloading: return .blue.opacity(0.04)
        case .paused: return .orange.opacity(0.04)
        case .failed: return .red.opacity(0.04)
        case .completed: return .green.opacity(0.04)
        default: return .clear
        }
    }
}

struct HFModelRow: View {
    let model: HFModel
    let state: DownloadState
    let isInstalled: Bool
    let onDownload: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(model.id)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let downloads = model.downloads {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 8))
                            Text(model.formattedDownloads)
                        }
                    }
                    if let likes = model.likes, likes > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "heart")
                                .font(.system(size: 8))
                            Text(model.formattedLikes)
                        }
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
                    if let pipeline = model.pipelineTag {
                        Text(pipeline.replacingOccurrences(of: "-", with: " "))
                            .font(.system(size: 8))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(.purple.opacity(0.1))
                            .cornerRadius(2)
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            }

            Spacer()

            if state.isDownloading {
                HStack(spacing: 4) {
                    VStack(spacing: 2) {
                        ProgressView(value: state.progress)
                            .frame(width: 50)
                            .controlSize(.small)
                        Text("\(Int(state.progress * 100))%")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                    Button { onPause() } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.orange)
                    .help("Pause")

                    Button { onStop() } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .help("Stop")
                }
            } else if state.isActive {
                HStack(spacing: 4) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)

                    Button { onResume() } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.green)
                    .help("Resume")

                    Button { onStop() } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .help("Stop")
                }
            } else if state.isFailed {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)

                    Button { onRestart() } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .help("Retry")
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
