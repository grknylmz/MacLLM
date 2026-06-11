import SwiftUI

struct ModelListView: View {
    let modelManager: ModelManager
    let serverManager: ServerManager
    @State private var hoveredModelId: String?

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
                                isHovered: hoveredModelId == model.id,
                                isDeleting: modelManager.deletingModelId == model.id,
                                onActivate: {
                                    Task { await serverManager.switchModel(to: model.fullName) }
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
    }
}

struct ModelRow: View {
    let model: MLXModel
    let isActive: Bool
    let isHovered: Bool
    let isDeleting: Bool
    let onActivate: () -> Void
    let onDelete: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundStyle(isActive ? .green : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(model.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(model.organization)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    if let quant = model.quantization {
                        Text(quant)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.15))
                            .cornerRadius(3)
                    }
                    if let params = model.parameterCount {
                        Text(params)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.purple.opacity(0.15))
                            .cornerRadius(3)
                    }
                    Text(model.formattedSize)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
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
