import SwiftData

/// The schema version the app currently works with. All code outside the `Schema` folder uses
/// these aliases, so a schema bump only touches this file.
public typealias CurrentSchema = SchemaV2

public typealias Workspace = CurrentSchema.Workspace
public typealias Project = CurrentSchema.Project
public typealias BoardColumn = CurrentSchema.BoardColumn
public typealias TaskItem = CurrentSchema.TaskItem
public typealias Subtask = CurrentSchema.Subtask
public typealias TaskComment = CurrentSchema.TaskComment
public typealias TaskQuestion = CurrentSchema.TaskQuestion
public typealias TaskAttachment = CurrentSchema.TaskAttachment
public typealias ActivityEntry = CurrentSchema.ActivityEntry
public typealias TaskLabel = CurrentSchema.TaskLabel
public typealias CustomFieldDefinition = CurrentSchema.CustomFieldDefinition
public typealias CustomFieldValue = CurrentSchema.CustomFieldValue
public typealias TaskTemplate = CurrentSchema.TaskTemplate
