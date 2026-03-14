//
//  TFDatePicker.swift
//  Projects
//
//  TaskFlow - Date Picker Component
//

import SwiftUI

// MARK: - TFDatePicker
struct TFDatePicker: View {
    let title: String?
    @Binding var date: Date?
    let showTime: Bool
    let inPast: Bool
    let errorMessage: String?
    let hintText: String?
    
    init(
        title: String? = nil,
        date: Binding<Date?>,
        showTime: Bool = false,
        inPast: Bool = true,
        errorMessage: String? = nil,
        hintText: String? = nil
    ) {
        self.title = title
        self._date = date
        self.showTime = showTime
        self.inPast = inPast
        self.errorMessage = errorMessage
        self.hintText = hintText
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.small) {
            // Title
            if let title = title {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(TaskFlowColors.textPrimary)
            }
            
            // Date Picker
            HStack(spacing: TaskFlowSpacing.medium) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(errorMessage != nil ? TaskFlowColors.error : TaskFlowColors.textTertiary)
                
                if let date = date {
                    Text(formatDate(date))
                        .font(.system(size: 14))
                        .foregroundColor(TaskFlowColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Select date")
                        .font(.system(size: 14))
                        .foregroundColor(TaskFlowColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                DatePicker(
                    "",
                    selection: .init(
                        get: { date ?? Date() },
                        set: { date = $0 }
                    ),
                    displayedComponents: showTime ? [.date, .hourAndMinute] : [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .opacity(0)
                .frame(width: 0, height: 0)
                
                TFIconButton(icon: "chevron.down", size: 16, style: .ghost) {
                    // Date picker is triggered by the button
                }
            }
            .padding(.horizontal, TaskFlowSpacing.medium)
            .padding(.vertical, TaskFlowSpacing.large)
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = showTime ? .short : .none
        return formatter.string(from: date)
    }
    
    private var backgroundColor: Color {
        TaskFlowColors.surface
    }
    
    private var borderColor: Color {
        errorMessage != nil ? TaskFlowColors.error : TaskFlowColors.border
    }
}

// MARK: - Relative Date Picker
struct TFRelativeDatePicker: View {
    let title: String?
    @Binding var date: Date?
    
    init(
        title: String? = nil,
        date: Binding<Date?>
    ) {
        self.title = title
        self._date = date
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            if let title = title {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(TaskFlowColors.textPrimary)
            }
            
            // Quick select options
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TaskFlowSpacing.small) {
                    QuickDateButton(title: "Today", icon: "sun.max.fill") {
                        date = Date()
                    }
                    
                    QuickDateButton(title: "Tomorrow", icon: "sun.max.fill") {
                        date = Calendar.current.date(byAdding: .day, value: 1, to: Date())
                    }
                    
                    QuickDateButton(title: "Next Week", icon: "calendar") {
                        date = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())
                    }
                    
                    QuickDateButton(title: "No Date", icon: "xmark.circle") {
                        date = nil
                    }
                }
            }
            
            // Full date picker
            TFDatePicker(date: $date)
        }
    }
}

// MARK: - Quick Date Button
struct QuickDateButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, TaskFlowSpacing.medium)
            .padding(.vertical, TaskFlowSpacing.small)
            .background(TaskFlowColors.background)
            .foregroundColor(TaskFlowColors.textPrimary)
            .cornerRadius(TaskFlowRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - TFColorPicker
struct TFColorPicker: View {
    let title: String?
    @Binding var selectedColor: String
    let colors: [String]
    let columns: Int
    
    init(
        title: String? = nil,
        selectedColor: Binding<String>,
        colors: [String] = ["#FF6B6B", "#FFB020", "#FFEAA7", "#00BA88", "#4ECDC4", "#45B7D1", "#2D5BFF", "#A855F7"],
        columns: Int = 4
    ) {
        self.title = title
        self._selectedColor = selectedColor
        self.colors = colors
        self.columns = columns
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            if let title = title {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(TaskFlowColors.textPrimary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TaskFlowSpacing.medium), count: columns), spacing: TaskFlowSpacing.medium) {
                ForEach(colors, id: \.self) { color in
                    Button(action: {
                        selectedColor = color
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 40, height: 40)
                            
                            if selectedColor == color {
                                Circle()
                                    .stroke(.white, lineWidth: 3)
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

// MARK: - Previews
#Preview("Date Picker") {
    TFDatePicker(date: .constant(Date()))
        .padding()
}

#Preview("Date Picker with Title") {
    TFDatePicker(
        title: "Due Date",
        date: .constant(Date()),
        hintText: "When should this be done?"
    )
    .padding()
}

#Preview("Relative Date Picker") {
    TFRelativeDatePicker(date: .constant(Date()))
        .padding()
}

#Preview("Color Picker") {
    TFColorPicker(selectedColor: .constant("#2D5BFF"))
        .padding()
}

#Preview("Color Picker with Title") {
    TFColorPicker(
        title: "Label Color",
        selectedColor: .constant("#FF6B6B")
    )
    .padding()
}
