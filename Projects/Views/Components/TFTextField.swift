//
//  TFTextField.swift
//  Projects
//
//  TaskFlow - Reusable Text Field Component
//

import SwiftUI

// MARK: - TFTextField
struct TFTextField: View {
    let title: String?
    let placeholder: String
    let icon: String?
    @Binding var text: String
    let isSecure: Bool
    let isDisabled: Bool
    let errorMessage: String?
    let hintText: String?
    let characterLimit: Int?
    let multiline: Bool
    let minLineCount: Int
    let onCommit: () -> Void
    
    init(
        title: String? = nil,
        placeholder: String = "",
        icon: String? = nil,
        text: Binding<String>,
        isSecure: Bool = false,
        isDisabled: Bool = false,
        errorMessage: String? = nil,
        hintText: String? = nil,
        characterLimit: Int? = nil,
        multiline: Bool = false,
        minLineCount: Int = 1,
        onCommit: @escaping () -> Void = {}
    ) {
        self.title = title
        self.placeholder = placeholder
        self.icon = icon
        self._text = text
        self.isSecure = isSecure
        self.isDisabled = isDisabled
        self.errorMessage = errorMessage
        self.hintText = hintText
        self.characterLimit = characterLimit
        self.multiline = multiline
        self.minLineCount = minLineCount
        self.onCommit = onCommit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.small) {
            // Title
            if let title = title {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TaskFlowColors.textPrimary)
                    
                    Spacer()
                    
                    if let limit = characterLimit {
                        Text("\(text.count)/\(limit)")
                            .font(.system(size: 11))
                            .foregroundColor(text.count > limit ? TaskFlowColors.error : TaskFlowColors.textTertiary)
                    }
                }
            }
            
            // Input Field
            HStack(spacing: TaskFlowSpacing.medium) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(errorMessage != nil ? TaskFlowColors.error : TaskFlowColors.textTertiary)
                }
                
                if multiline {
                    TextEditor(text: $text)
                        .font(.system(size: 14))
                        .foregroundColor(isDisabled ? TaskFlowColors.textTertiary : TaskFlowColors.textPrimary)
                        .frame(minHeight: CGFloat(minLineCount) * 20)
                        .disabled(isDisabled)
                } else if isSecure {
                    SecureField(placeholder, text: $text)
                        .font(.system(size: 14))
                        .foregroundColor(isDisabled ? TaskFlowColors.textTertiary : TaskFlowColors.textPrimary)
                        .disabled(isDisabled)
                        .onSubmit(onCommit)
                } else {
                    TextField(placeholder, text: $text)
                        .font(.system(size: 14))
                        .foregroundColor(isDisabled ? TaskFlowColors.textTertiary : TaskFlowColors.textPrimary)
                        .disabled(isDisabled)
                        .onSubmit(onCommit)
                }
            }
            .padding(.horizontal, icon == nil ? TaskFlowSpacing.medium : 0)
            .padding(.vertical, multiline ? TaskFlowSpacing.medium : TaskFlowSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                    .stroke(borderColor, lineWidth: 1)
            )
            
            // Error or Hint Text
            if let errorMessage = errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                    Text(errorMessage)
                        .font(.system(size: 11))
                }
                .foregroundColor(TaskFlowColors.error)
            } else if let hintText = hintText {
                Text(hintText)
                    .font(.system(size: 11))
                    .foregroundColor(TaskFlowColors.textTertiary)
            }
        }
    }
    
    private var backgroundColor: Color {
        isDisabled ? TaskFlowColors.background : TaskFlowColors.surface
    }
    
    private var borderColor: Color {
        if errorMessage != nil {
            return TaskFlowColors.error
        }
        return TaskFlowColors.border
    }
}

// MARK: - TFSearchField
struct TFSearchField: View {
    let placeholder: String
    @Binding var text: String
    let onClear: () -> Void
    
    init(
        placeholder: String = "Search...",
        text: Binding<String>,
        onClear: @escaping () -> Void = {}
    ) {
        self.placeholder = placeholder
        self._text = text
        self.onClear = onClear
    }
    
    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(TaskFlowColors.textTertiary)
            
            TextField(placeholder, text: $text)
                .font(.system(size: 14))
            
            if !text.isEmpty {
                TFIconButton(icon: "xmark.circle.fill", size: 16, style: .ghost) {
                    onClear()
                }
            }
        }
        .padding(.horizontal, TaskFlowSpacing.medium)
        .padding(.vertical, TaskFlowSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                .fill(TaskFlowColors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                .stroke(TaskFlowColors.border, lineWidth: 1)
        )
    }
}

// MARK: - TFNumberField
struct TFNumberField: View {
    let title: String?
    let placeholder: String
    @Binding var value: Double?
    let suffix: String?
    let isDisabled: Bool
    let errorMessage: String?
    
    init(
        title: String? = nil,
        placeholder: String = "0",
        value: Binding<Double?>,
        suffix: String? = nil,
        isDisabled: Bool = false,
        errorMessage: String? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._value = value
        self.suffix = suffix
        self.isDisabled = isDisabled
        self.errorMessage = errorMessage
    }
    
    var body: some View {
        TFTextField(
            title: title,
            placeholder: placeholder,
            text: .init(
                get: { value.map { String(format: "%.2f", $0) } ?? "" },
                set: { value = Double($0) }
            ),
            isDisabled: isDisabled,
            errorMessage: errorMessage
        )
    }
}

// MARK: - Previews
#Preview("Basic TextField") {
    TFTextField(placeholder: "Enter text", text: .constant(""))
        .padding()
}

#Preview("TextField with Title") {
    TFTextField(
        title: "Task Title",
        placeholder: "Enter task title",
        text: .constant("")
    )
    .padding()
}

#Preview("TextField with Icon") {
    TFTextField(
        placeholder: "Search",
        icon: "magnifyingglass",
        text: .constant("")
    )
    .padding()
}

#Preview("TextField with Error") {
    TFTextField(
        title: "Email",
        placeholder: "Enter email",
        icon: "envelope",
        text: .constant("invalid"),
        errorMessage: "Invalid email format"
    )
    .padding()
}

#Preview("Multiline TextField") {
    TFTextField(
        title: "Description",
        placeholder: "Enter description",
        text: .constant(""),
        multiline: true,
        minLineCount: 4
    )
    .padding()
}

#Preview("Secure Field") {
    TFTextField(
        title: "Password",
        placeholder: "Enter password",
        icon: "lock",
        text: .constant(""),
        isSecure: true
    )
    .padding()
}

#Preview("Search Field") {
    TFSearchField(text: .constant(""))
        .padding()
}

#Preview("Disabled TextField") {
    TFTextField(
        placeholder: "Disabled",
        text: .constant("Cannot edit"),
        isDisabled: true
    )
    .padding()
}
