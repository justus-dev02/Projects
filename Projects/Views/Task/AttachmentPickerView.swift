//
//  AttachmentPickerView.swift
//  Projects
//
//  TaskFlow - File Attachment Picker and Management
//

import SwiftUI
import UniformTypeIdentifiers
import Combine // FIXED: Required for ObservableObject and @Published

#if canImport(UIKit)
import UIKit
#endif

#if canImport(PhotosUI)
import PhotosUI
#endif

#if canImport(QuickLook)
import QuickLook // FIXED: Required for QLPreviewController
#endif

// MARK: - Attachment Picker View
struct AttachmentPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AttachmentViewModel
    
    let task: Task
    
    @State private var showingFilePicker = false
    @State private var showingCamera = false
    @State private var selectedFiles: [URL] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Upload Section
                uploadSection
                
                Divider()
                
                // Attachments List
                attachmentsList
            }
            .navigationTitle("Attachments")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
#if os(iOS)
            .sheet(isPresented: $showingFilePicker) {
                FileImporterView(selectedFiles: $selectedFiles) { urls in
                    handleFileSelection(urls)
                }
            }
#elseif os(macOS)
            .onChange(of: showingFilePicker) { _, newValue in
                if newValue {
                    FileImporterView.present { urls in
                        handleFileSelection(urls)
                        showingFilePicker = false
                    }
                }
            }
#endif
        }
    }
    
    // MARK: - Upload Section
    private var uploadSection: some View {
        HStack(spacing: TaskFlowSpacing.large) {
            UploadButton(
                icon: "doc.badge.plus",
                title: "Add File",
                subtitle: "From device"
            ) {
                showingFilePicker = true
            }
            
#if os(iOS)
            UploadButton(
                icon: "camera.fill",
                title: "Photo",
                subtitle: "Take photo"
            ) {
                showingCamera = true
            }
#endif
            
            UploadButton(
                icon: "icloud.and.arrow.down",
                title: "Cloud",
                subtitle: "From cloud"
            ) {
                // Handle cloud selection
            }
        }
        .padding()
        .background(TaskFlowColors.background)
    }
    
    // MARK: - Attachments List
    private var attachmentsList: some View {
        Group {
            if viewModel.attachments.isEmpty {
                EmptyAttachmentsView()
            } else {
                List {
                    ForEach(viewModel.attachments, id: \.id) { attachment in
                        AttachmentRow(
                            attachment: attachment,
                            onDelete: {
                                viewModel.deleteAttachment(attachment)
                            },
                            onPreview: {
                                viewModel.previewAttachment(attachment)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Handle File Selection
    private func handleFileSelection(_ urls: [URL]) {
        for url in urls {
            viewModel.addAttachment(from: url, task: task)
        }
    }
}

// MARK: - Upload Button
struct UploadButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: TaskFlowSpacing.small) {
                ZStack {
                    Circle()
                        .fill(TaskFlowColors.primary.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(TaskFlowColors.primary)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(TaskFlowColors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(TaskFlowColors.textTertiary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - File Importer View
#if os(iOS)
struct FileImporterView: UIViewControllerRepresentable {
    @Binding var selectedFiles: [URL]
    let onComplete: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedFiles: $selectedFiles, onComplete: onComplete)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        @Binding var selectedFiles: [URL]
        let onComplete: ([URL]) -> Void

        init(selectedFiles: Binding<[URL]>, onComplete: @escaping ([URL]) -> Void) {
            _selectedFiles = selectedFiles
            self.onComplete = onComplete
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            selectedFiles = urls
            onComplete(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            selectedFiles = []
            onComplete([])
        }
    }
}
#elseif os(macOS)
struct FileImporterView: NSViewRepresentable {
    @Binding var selectedFiles: [URL]
    let onComplete: ([URL]) -> Void

    func makeNSView(context: Context) -> NSView {
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedFiles: $selectedFiles, onComplete: onComplete)
    }

    class Coordinator: NSObject, NSOpenSavePanelDelegate {
        @Binding var selectedFiles: [URL]
        let onComplete: ([URL]) -> Void

        init(selectedFiles: Binding<[URL]>, onComplete: @escaping ([URL]) -> Void) {
            _selectedFiles = selectedFiles
            self.onComplete = onComplete
        }

        func openPanel(_ sender: NSOpenPanel, shouldEnable url: URL) -> Bool {
            return true
        }
    }
}

extension FileImporterView {
    static func present(onComplete: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            if response == .OK {
                onComplete(panel.urls)
            } else {
                onComplete([])
            }
        }
    }
}
#endif

// MARK: - Attachment Row
struct AttachmentRow: View {
    let attachment: Attachment
    let onDelete: () -> Void
    let onPreview: () -> Void
    
    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: TaskFlowRadius.small)
                    .fill(TaskFlowColors.background)
                    .frame(width: 48, height: 48)
                
                Image(systemName: iconForMimeType(attachment.mimeType))
                    .font(.system(size: 20))
                    .foregroundColor(TaskFlowColors.primary)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(TaskFlowColors.textPrimary)
                    .lineLimit(1)
                
                Text(formattedFileSize)
                    .font(.system(size: 11))
                    .foregroundColor(TaskFlowColors.textTertiary)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: TaskFlowSpacing.small) {
                Button(action: onPreview) {
                    Image(systemName: "eye")
                        .font(.system(size: 14))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(TaskFlowColors.error)
                }
            }
        }
        .padding(.vertical, TaskFlowSpacing.small)
    }
    
    private var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: attachment.fileSize)
    }
    
    private func iconForMimeType(_ mimeType: String) -> String {
        if mimeType.hasPrefix("image/") {
            return "photo"
        } else if mimeType.hasPrefix("video/") {
            return "video"
        } else if mimeType.hasPrefix("audio/") {
            return "music.note"
        } else if mimeType.hasPrefix("application/pdf") {
            return "doc.richtext"
        } else if mimeType.hasPrefix("application/") {
            return "doc"
        }
        return "doc"
    }
}

// MARK: - Empty Attachments View
struct EmptyAttachmentsView: View {
    var body: some View {
        VStack(spacing: TaskFlowSpacing.medium) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(TaskFlowColors.textTertiary)
            
            Text("No Attachments")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)
            
            Text("Add files, photos, or documents\nto your task")
                .font(.system(size: 13))
                .foregroundColor(TaskFlowColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, TaskFlowSpacing.xHuge * 2)
    }
}

// MARK: - Attachment View Model
@MainActor
class AttachmentViewModel: NSObject, ObservableObject { // FIXED: Added NSObject inheritance for QLPreviewController delegates
    @Published var attachments: [Attachment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let dataService: DataService
    
    init(dataService: DataService) {
        self.dataService = dataService
        super.init() // FIXED: Call super.init() since we inherit from NSObject now
    }
    
    func loadAttachments(for task: Task) {
        attachments = task.attachments ?? []
    }
    
    func addAttachment(from url: URL, task: Task) {
        isLoading = true
        
        do {
            // Get file attributes
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            // Determine MIME type
            let mimeType = mimeTypeForFile(url: url)
            
            // Create attachment
            let attachment = Attachment(
                fileName: url.lastPathComponent,
                fileSize: fileSize,
                mimeType: mimeType,
                url: url.absoluteString
            )
            attachment.uploader = task.assignee
            attachment.task = task
            
            task.attachments?.append(attachment)
            
            try dataService.save()
            
            attachments.append(attachment)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func deleteAttachment(_ attachment: Attachment) {
        dataService.delete(attachment)
        try? dataService.save()
        attachments.removeAll { $0.id == attachment.id }
    }
    
    func previewAttachment(_ attachment: Attachment) {
        // Open in Quick Look or preview controller
        guard let url = attachment.url, let _ = URL(string: url) else { return }
        
        #if os(iOS)
        let previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.delegate = self
        // Would need to be presented from a view controller
        #endif
    }
    
    private func mimeTypeForFile(url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "pdf": return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "heic": return "image/heic"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "txt": return "text/plain"
        case "rtf": return "application/rtf"
        case "zip": return "application/zip"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - QLPreviewController DataSource
#if os(iOS)
extension AttachmentViewModel: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        // Return URL as preview item
        return NSURL() as QLPreviewItem
    }
}
#endif

// MARK: - Preview
#Preview("Attachment Picker") {
    let task = Task(title: "Test Task")
    return AttachmentPickerView(viewModel: AttachmentViewModel(dataService: DataService()), task: task)
}
