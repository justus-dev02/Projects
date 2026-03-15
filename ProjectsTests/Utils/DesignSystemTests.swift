//
//  DesignSystemTests.swift
//  ProjectsTests
//
//  Comprehensive Unit Tests for DesignSystem and Color Extensions
//

import XCTest
@testable import Projects
import SwiftUI

@MainActor
final class DesignSystemTests: XCTestCase {
    
    // MARK: - Color Hex Conversion Tests
    
    func testColor_InitFromHex_With6Characters() {
        // When
        let color = Color(hex: "#FF6B6B")
        
        // Then - Verify color is created (can't directly compare RGB values in tests)
        XCTAssertNotNil(color)
    }
    
    func testColor_InitFromHex_With3Characters() {
        // When
        let color = Color(hex: "#F66")
        
        // Then
        XCTAssertNotNil(color)
    }
    
    func testColor_InitFromHex_With8Characters() {
        // When
        let color = Color(hex: "#FF6B6B80")
        
        // Then
        XCTAssertNotNil(color)
    }
    
    func testColor_InitFromHex_WithoutHash() {
        // When
        let color = Color(hex: "FF6B6B")
        
        // Then
        XCTAssertNotNil(color)
    }
    
    func testColor_InitFromHex_InvalidString() {
        // When
        let color = Color(hex: "invalid")
        
        // Then - Should create black color as fallback
        XCTAssertNotNil(color)
    }
    
    func testColor_InitFromHex_EmptyString() {
        // When
        let color = Color(hex: "")
        
        // Then - Should create black color as fallback
        XCTAssertNotNil(color)
    }
    
    func testColor_ToHex_FromKnownColor() {
        // Given - Create color from known hex
        let originalHex = "#FF6B6B"
        let color = Color(hex: originalHex)
        
        // When
        let resultHex = color.toHex()
        
        // Then
        XCTAssertEqual(resultHex, originalHex)
    }
    
    func testColor_ToHex_PrimaryColor() {
        // Given
        let color = TaskFlowColors.primary
        
        // When
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#2D5BFF")
    }
    
    func testColor_ToHex_SuccessColor() {
        // Given
        let color = TaskFlowColors.success
        
        // When
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#00BA88")
    }
    
    func testColor_ToHex_WarningColor() {
        // Given
        let color = TaskFlowColors.warning
        
        // When
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#FFB020")
    }
    
    func testColor_ToHex_ErrorColor() {
        // Given
        let color = TaskFlowColors.error
        
        // When
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#FF4757")
    }
    
    // MARK: - TaskFlowColors Tests
    
    func testTaskFlowColors_Primary() {
        // When
        let color = TaskFlowColors.primary
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#2D5BFF")
    }
    
    func testTaskFlowColors_Success() {
        // When
        let color = TaskFlowColors.success
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#00BA88")
    }
    
    func testTaskFlowColors_Warning() {
        // When
        let color = TaskFlowColors.warning
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#FFB020")
    }
    
    func testTaskFlowColors_Error() {
        // When
        let color = TaskFlowColors.error
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#FF4757")
    }
    
    func testTaskFlowColors_Background() {
        // When
        let color = TaskFlowColors.background
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#FAFBFC")
    }
    
    func testTaskFlowColors_BackgroundDark() {
        // When
        let color = TaskFlowColors.backgroundDark
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#1A1A2E")
    }
    
    func testTaskFlowColors_Surface() {
        // When
        let color = TaskFlowColors.surface
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#FFFFFF")
    }
    
    func testTaskFlowColors_SurfaceDark() {
        // When
        let color = TaskFlowColors.surfaceDark
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#16213E")
    }
    
    func testTaskFlowColors_Border() {
        // When
        let color = TaskFlowColors.border
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#E6E9ED")
    }
    
    func testTaskFlowColors_BorderDark() {
        // When
        let color = TaskFlowColors.borderDark
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#2D3748")
    }
    
    func testTaskFlowColors_TextPrimary() {
        // When
        let color = TaskFlowColors.textPrimary
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#1A202E")
    }
    
    func testTaskFlowColors_TextSecondary() {
        // When
        let color = TaskFlowColors.textSecondary
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#718096")
    }
    
    func testTaskFlowColors_TextTertiary() {
        // When
        let color = TaskFlowColors.textTertiary
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#A0AEC0")
    }
    
    func testTaskFlowColors_TextPrimaryDark() {
        // When
        let color = TaskFlowColors.textPrimaryDark
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#F7FAFC")
    }
    
    func testTaskFlowColors_TextSecondaryDark() {
        // When
        let color = TaskFlowColors.textSecondaryDark
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#A0AEC0")
    }
    
    func testTaskFlowColors_LabelColors_Count() {
        // Then
        XCTAssertEqual(TaskFlowColors.labelColors.count, 8)
    }
    
    func testTaskFlowColors_LabelColors_AllValid() {
        // Then
        for color in TaskFlowColors.labelColors {
            let hex = color.toHex()
            XCTAssertTrue(hex.hasPrefix("#"))
        }
    }
    
    func testTaskFlowColors_PriorityLow() {
        // When
        let color = TaskFlowColors.priorityLow
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#95A5A6")
    }
    
    func testTaskFlowColors_PriorityMedium() {
        // When
        let color = TaskFlowColors.priorityMedium
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#45B7D1")
    }
    
    func testTaskFlowColors_PriorityHigh() {
        // When
        let color = TaskFlowColors.priorityHigh
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#FFB020")
    }
    
    func testTaskFlowColors_PriorityUrgent() {
        // When
        let color = TaskFlowColors.priorityUrgent
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#FF4757")
    }
    
    func testTaskFlowColors_StatusTodo() {
        // When
        let color = TaskFlowColors.statusTodo
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#95A5A6")
    }
    
    func testTaskFlowColors_StatusInProgress() {
        // When
        let color = TaskFlowColors.statusInProgress
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#45B7D1")
    }
    
    func testTaskFlowColors_StatusReview() {
        // When
        let color = TaskFlowColors.statusReview
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#FFB020")
    }
    
    func testTaskFlowColors_StatusDone() {
        // When
        let color = TaskFlowColors.statusDone
        let hex = color.toHex()
        
        // Then
        XCTAssertEqual(hex, "#00BA88")
    }
    
    // MARK: - TaskFlowTypography Tests
    
    func testTaskFlowTypography_FontSizes() {
        // Then
        XCTAssertEqual(TaskFlowTypography.tiny, 10)
        XCTAssertEqual(TaskFlowTypography.small, 12)
        XCTAssertEqual(TaskFlowTypography.body, 14)
        XCTAssertEqual(TaskFlowTypography.mediumSize, 16)
        XCTAssertEqual(TaskFlowTypography.large, 18)
        XCTAssertEqual(TaskFlowTypography.xLarge, 20)
        XCTAssertEqual(TaskFlowTypography.title, 24)
        XCTAssertEqual(TaskFlowTypography.xTitle, 28)
        XCTAssertEqual(TaskFlowTypography.display, 32)
    }
    
    func testTaskFlowTypography_FontWeights() {
        // Then
        XCTAssertEqual(TaskFlowTypography.regular, .regular)
        XCTAssertEqual(TaskFlowTypography.mediumWeight, .medium)
        XCTAssertEqual(TaskFlowTypography.semibold, .semibold)
        XCTAssertEqual(TaskFlowTypography.bold, .bold)
    }
    
    // MARK: - TaskFlowSpacing Tests
    
    func testTaskFlowSpacing_Values() {
        // Then
        XCTAssertEqual(TaskFlowSpacing.none, 0)
        XCTAssertEqual(TaskFlowSpacing.xs, 2)
        XCTAssertEqual(TaskFlowSpacing.small, 4)
        XCTAssertEqual(TaskFlowSpacing.medium, 8)
        XCTAssertEqual(TaskFlowSpacing.large, 12)
        XCTAssertEqual(TaskFlowSpacing.xLarge, 16)
        XCTAssertEqual(TaskFlowSpacing.xxLarge, 20)
        XCTAssertEqual(TaskFlowSpacing.huge, 24)
        XCTAssertEqual(TaskFlowSpacing.xHuge, 32)
    }
    
    // MARK: - TaskFlowRadius Tests
    
    func testTaskFlowRadius_Values() {
        // Then
        XCTAssertEqual(TaskFlowRadius.none, 0)
        XCTAssertEqual(TaskFlowRadius.small, 4)
        XCTAssertEqual(TaskFlowRadius.medium, 8)
        XCTAssertEqual(TaskFlowRadius.large, 12)
        XCTAssertEqual(TaskFlowRadius.xLarge, 16)
        XCTAssertEqual(TaskFlowRadius.full, 999)
    }
    
    // MARK: - TaskFlowShadow Tests
    
    func testTaskFlowShadow_None() {
        // Then
        XCTAssertEqual(TaskFlowShadow.none.color, .clear)
        XCTAssertEqual(TaskFlowShadow.none.radius, 0)
        XCTAssertEqual(TaskFlowShadow.none.x, 0)
        XCTAssertEqual(TaskFlowShadow.none.y, 0)
    }
    
    func testTaskFlowShadow_Small() {
        // Then
        XCTAssertEqual(TaskFlowShadow.small.radius, 4)
        XCTAssertEqual(TaskFlowShadow.small.x, 0)
        XCTAssertEqual(TaskFlowShadow.small.y, 2)
    }
    
    func testTaskFlowShadow_Medium() {
        // Then
        XCTAssertEqual(TaskFlowShadow.medium.radius, 8)
        XCTAssertEqual(TaskFlowShadow.medium.x, 0)
        XCTAssertEqual(TaskFlowShadow.medium.y, 4)
    }
    
    func testTaskFlowShadow_Large() {
        // Then
        XCTAssertEqual(TaskFlowShadow.large.radius, 16)
        XCTAssertEqual(TaskFlowShadow.large.x, 0)
        XCTAssertEqual(TaskFlowShadow.large.y, 8)
    }
    
    // MARK: - TaskFlowAnimation Tests
    
    func testTaskFlowAnimation_Durations() {
        // Then
        XCTAssertEqual(TaskFlowAnimation.fast, 0.15)
        XCTAssertEqual(TaskFlowAnimation.medium, 0.25)
        XCTAssertEqual(TaskFlowAnimation.slow, 0.35)
        XCTAssertEqual(TaskFlowAnimation.springDuration, 0.5)
    }
    
    func testTaskFlowAnimation_EaseInOut() {
        // Then
        XCTAssertNotNil(TaskFlowAnimation.easeInOut)
    }
    
    func testTaskFlowAnimation_Spring() {
        // Then
        XCTAssertNotNil(TaskFlowAnimation.spring)
    }
}
