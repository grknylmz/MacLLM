import SwiftUI

struct ModelListView: View {
    let modelManager: ModelManager
    let serverManager: ServerManager
    let memoryMonitor: SystemMemoryMonitor
    @State private var hoveredModelId: String?
    @State private var memoryWarningModel: MLXModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("INSTALLED MODELS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            if modelManager.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else if modelManager.installedModels.isEmpty {
                HStack {
                    Spacer()
                    Text("No models installed")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(modelManager.installedModels) { model in
                            ModelRow(
                                model: model,
                                isActive: serverManager.activeModel == model.fullName,
                                isRunning: serverManager.isRunning && serverManager.activeModel == model.fullName,
                                isHovered: hoveredModelId == model.id,
                                isDeleting: modelManager.deletingModelId == model.id,
                                onActivate: {
                                    tryStartModel(model)
                                },
                                onDelete: {
                                    Task { await modelManager.deleteModel(model) }
                                },
                                onHover: { hovering in
                                    hoveredModelId = hovering ? model.id : nil
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .frame(maxHeight: 180)
            }

            if let error = modelManager.error {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
            }
        }
        .alert("Insufficient Memory", isPresented: Binding(
            get: { memoryWarningModel != nil },
            set: { if !$0 { memoryWarningModel = nil } }
        )) {
            Button("Start Anyway") {
                if let model = memoryWarningModel {
                    forceStartModel(model)
                }
                memoryWarningModel = nil
            }
            Button("Cancel", role: .cancel) {
                memoryWarningModel = nil
            }
        } message: {
            if let model = memoryWarningModel, let ram = model.formattedEstimatedRAM {
                Text("This model requires \(ram) but only \(String(format: "%.1f", memoryMonitor.freeGB)) GB is free. This may cause the system to freeze or crash.")
            } else {
                Text("Not enough memory to start this model.")
            }
        }
    }

    private func tryStartModel(_ model: MLXModel) {
        if !serverManager.checkMemoryBeforeStart(
            estimatedRAMGB: model.estimatedRAMGB,
            freeGB: memoryMonitor.freeGB
        ) {
            memoryWarningModel = model
            return
        }
        forceStartModel(model)
    }

    private func forceStartModel(_ model: MLXModel) {
        modelManager.markModelRun(model.fullName)
        Task { await serverManager.switchModel(to: model.fullName) }
    }
}

struct ModelRow: View {
    let model: MLXModel
    let isActive: Bool
    let isRunning: Bool
    let isHovered: Bool
    let isDeleting: Bool
    let onActivate: () -> Void
    let onDelete: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: 12, height: 12)
                if isRunning {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 18, height: 18)
                        .scaleEffect(1.4)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isRunning)
                }
                Image(systemName: isActive ? "checkmark" : "")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(model.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(model.organization)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)

                    if let arch = model.architecture {
                        Text(arch)
                            .font(.system(size: 8, weight: .medium))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(.cyan.opacity(0.12))
                            .cornerRadius(2)
                    }

                    if let quant = model.quantization {
                        Text(quant)
                            .font(.system(size: 8, weight: .medium))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.12))
                            .cornerRadius(2)
                    }

                    if let params = model.parameterCount {
                        Text(params)
                            .font(.system(size: 8, weight: .medium))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(.purple.opacity(0.12))
                            .cornerRadius(2)
                    }

                    if let ram = model.formattedEstimatedRAM {
                        Text(ram)
                            .font(.system(size: 8, weight: .medium))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.12))
                            .cornerRadius(2)
                    }

                    Text(model.formattedSize)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }

                if isHovered, let lastRun = model.relativeLastRun {
                    Text("Last run: \(lastRun)")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if isDeleting {
                ProgressView()
                    .controlSize(.mini)
            } else if isHovered {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.green.opacity(0.08) : (isHovered ? Color.gray.opacity(0.08) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isActive { onActivate() }
        }
        .onHover { hovering in
            onHover(hovering)
        }
    }
}
