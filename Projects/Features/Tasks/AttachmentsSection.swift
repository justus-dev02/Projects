import QuickLook
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem
import UniformTypeIdentifiers

/// Files attached to a task. The file content is copied into the database (and synced), so
/// attachments keep working after the original file is moved or deleted.
struct AttachmentsSection: View {
    @Environment(AppDependencies.self) private var dependencies
    let task: TaskItem
    @State private var isImporting = false
    @State private var previewURL: URL?

    var body: some View {
        let limit = Int64(AttachmentPolicy.maxBytes).formatted(.byteCount(style: .memory))
        CardSection(title: Text("Attachments"), footer: Text("Up to \(limit) per file.")) {
            ForEach(task.sortedAttachments) { attachment in
                Button {
                    preview(attachment)
                } label: {
                    HStack(spacing: TFSpacing.medium) {
                        Image(systemName: symbol(for: attachment))
                            .font(.title3)
                            .foregroundStyle(.tint)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(attachment.fileName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(Int64(attachment.byteCount), format: .byteCount(style: .file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .cardRow()
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Delete", role: .destructive) { delete(attachment) }
                }
                CardDivider()
            }
            Button {
                isImporting = true
            } label: {
                Label("Add Attachment", systemImage: "paperclip")
                    .cardRow()
            }
            .buttonStyle(.borderless)
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            handleImport(result)
        }
        .quickLookPreview($previewURL)
    }

    /// Files are read and stored in the background store, so large attachments do not block the UI.
    private func handleImport(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            let taskID = task.id
            Task {
                for url in urls {
                    await dependencies.addAttachment(toTaskWithID: taskID, from: url)
                }
            }
        case .failure(let error):
            dependencies.errors.present(error)
        }
    }

    /// Quick Look needs a file URL, so the stored data is written to a temporary file.
    private func preview(_ attachment: TaskAttachment) {
        guard let data = attachment.data else { return }
        let directory = URL.temporaryDirectory.appending(path: attachment.id.uuidString, directoryHint: .isDirectory)
        let url = directory.appending(path: attachment.fileName)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            previewURL = url
        } catch {
            dependencies.errors.present(error)
        }
    }

    private func delete(_ attachment: TaskAttachment) {
        dependencies.errors.perform { try dependencies.tasks.deleteAttachment(attachment) }
    }

    private func symbol(for attachment: TaskAttachment) -> String {
        guard let type = UTType(attachment.contentType) else { return "doc" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        if type.conforms(to: .audiovisualContent) { return "film" }
        if type.conforms(to: .archive) { return "doc.zipper" }
        if type.conforms(to: .text) { return "doc.text" }
        return "doc"
    }
}
