# TaskFlow 🚀

**Native iOS/iPadOS/macOS Task Management Application**

A full-featured, native Apple platform task management app built with Swift, SwiftUI, and SwiftData - inspired by Trello and Asana.

---

## 📱 Platform Support

- **iOS** 17.0+ (iPhone)
- **iPadOS** 17.0+ (iPad)
- **macOS** 14.0+ (Mac)

---

## ✨ Features

### Core Features

| Feature | Status | Description |
|---------|--------|-------------|
| **Dashboard** | ✅ | Real-time statistics, task overview, workspace progress |
| **Workspaces** | ✅ | Multiple workspaces with custom colors and icons |
| **Projects** | ✅ | Kanban boards with customizable columns |
| **Tasks** | ✅ | Full task management with priorities, labels, due dates |
| **Subtasks** | ✅ | Checklists with progress tracking |
| **Comments** | ✅ | Task comments with author information |
| **Labels** | ✅ | Color-coded labels for categorization |
| **Notifications** | ✅ | In-app notifications system |
| **Settings** | ✅ | User profile, preferences, data management |

### Multi-Platform Features

| Feature | iOS | iPadOS | macOS |
|---------|-----|--------|-------|
| Tab Navigation | ✅ | ✅ | ❌ |
| Sidebar Navigation | ❌ | ✅ | ✅ |
| Adaptive Layouts | ✅ | ✅ | ✅ |
| Keyboard Shortcuts | ❌ | ❌ | ✅ |
| Window Support | ❌ | ❌ | ✅ |

---

## 🏗️ Architecture

### Project Structure

```
Projects/
├── Models/                    # SwiftData Models
│   ├── User.swift            # User model with roles
│   ├── Workspace.swift       # Workspace & members
│   ├── Project.swift         # Projects & board columns
│   ├── Task.swift            # Tasks, subtasks, comments
│   ├── Label.swift           # Label categories
│   ├── NotificationModel.swift
│   └── SavedView.swift
│
├── Services/                  # Business Logic
│   ├── DataService.swift     # Core data service
│   ├── AuthService.swift     # Authentication
│   ├── WorkspaceRepository.swift
│   ├── ProjectRepository.swift
│   ├── TaskRepository.swift
│   ├── DashboardService.swift
│   └── DemoDataSeeder.swift  # Demo data generation
│
├── ViewModels/               # View Models (MVVM)
│
├── Views/                    # SwiftUI Views
│   ├── Components/          # Reusable UI components
│   │   ├── TFButton.swift
│   │   ├── TFCard.swift
│   │   ├── TFBadge.swift
│   │   ├── TFTextField.swift
│   │   ├── TFAvatar.swift
│   │   ├── TFProgressBar.swift
│   │   └── TFDatePicker.swift
│   │
│   ├── Dashboard/           # Dashboard views
│   ├── Workspace/           # Workspace management
│   ├── Project/             # Project & Kanban board
│   ├── Task/                # Task detail views
│   ├── Settings/            # Settings & notifications
│   └── RootContentView.swift
│
├── Utils/                   # Utilities
│   └── DesignSystem.swift   # Design tokens, colors
│
└── Resources/               # Assets
```

### Architecture Pattern: MVVM + Repository

```
┌─────────────────────────────────────────────────────────┐
│                      Views (SwiftUI)                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │  Dashboard  │  │  Workspace  │  │   Project   │      │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘      │
└─────────┼────────────────┼────────────────┼─────────────┘
          │                │                │
┌─────────▼────────────────▼────────────────▼─────────────┐
│                   ViewModels                             │
│         (ObservableObject, @Published)                   │
└─────────┬────────────────┬────────────────┬─────────────┘
          │                │                │
┌─────────▼────────────────▼────────────────▼─────────────┐
│                   Repositories                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │  Workspace  │  │   Project   │  │    Task     │      │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘      │
└─────────┼────────────────┼────────────────┼─────────────┘
          │                │                │
┌─────────▼────────────────▼────────────────▼─────────────┐
│                  DataService (SwiftData)                 │
│              (ModelContext, FetchDescriptors)            │
└──────────────────────────────────────────────────────────┘
```

---

## 🎨 Design System

### Colors

```swift
// Primary
primary: #2D5BFF      // Blue
success: #00BA88      // Green
warning: #FFB020      // Orange
error: #FF4757        // Red

// Background
background: #FAFBFC   // Light gray
surface: #FFFFFF      // White
border: #E6E9ED       // Border gray
```

### Typography

- **Display**: System bold (24-32pt)
- **Headline**: System semibold (18-20pt)
- **Body**: System regular (14-16pt)
- **Caption**: System regular (11-13pt)

### Components

All UI components follow a consistent naming convention (`TF*`):

- `TFButton` - Primary, Secondary, Ghost, Outline, Danger
- `TFCard` - Content cards with shadows
- `TFBadge` - Status, Priority, Label badges
- `TFTextField` - Text inputs with validation
- `TFAvatar` - User avatars with initials
- `TFProgressBar` - Linear and circular progress
- `TFDatePicker` - Date selection with quick options

---

## 🚀 Getting Started

### Prerequisites

- Xcode 15.0+
- macOS 14.0+ (for development)
- iOS 17.0+ SDK
- Swift 5.9+

### Installation

1. **Clone the repository**
   ```bash
   cd /Users/justusschmiernow/Documents/Development/XCode/Projects
   ```

2. **Open in Xcode**
   ```bash
   open Projects.xcodeproj
   ```

3. **Build and Run**
   - Select your target device (iPhone, iPad, or Mac)
   - Press `Cmd + R` to build and run

### First Launch

On first launch, you'll see:
1. **Onboarding flow** (4 pages)
2. **Local login** (automatic, no password required)
3. **Demo data** (automatically seeded)

---

## 📁 Data Models

### Core Entities

#### User
```swift
@Model
class User {
    var id: String           // UUID
    var email: String
    var displayName: String
    var avatarColor: String
    var role: String         // owner, admin, member
    var isLocalUser: Bool
}
```

#### Workspace
```swift
@Model
class Workspace {
    var id: String
    var name: String
    var description: String?
    var color: String
    var icon: String
    var projects: [Project]?
    var members: [WorkspaceMember]?
    var labels: [Label]?
}
```

#### Project
```swift
@Model
class Project {
    var id: String
    var name: String
    var status: String       // active, paused, completed
    var boardColumns: [BoardColumn]?
    var tasks: [Task]?
}
```

#### Task
```swift
@Model
class Task {
    var id: String
    var title: String
    var status: String       // todo, inProgress, review, done
    var priority: String     // low, medium, high, urgent
    var subtasks: [Subtask]?
    var comments: [Comment]?
    var labels: [TaskLabel]?
    var assignee: User?
}
```

---

## 🧪 Testing

### Unit Tests (54+ tests)

Run tests with `Cmd + U`:

```bash
# User tests
testUserCreation()
testUserRandomColor()

# Workspace tests
testWorkspaceCreation()
testWorkspaceStats()

# Project tests
testProjectCreation()
testProjectProgress()

# Task tests
testTaskCreation()
testTaskOverdue()
testTaskPriorityWeights()

# Performance tests
testPerformanceExample()
```

### UI Tests (32+ tests)

```bash
# Launch tests
testLaunch()

# Onboarding tests
testOnboardingFlow()

# Navigation tests
testBottomTabNavigation()

# Feature tests
testDashboardDisplays()
testWorkspaceList()
testCreateWorkspace()
testSettingsView()
```

### Test Coverage

| Category | Tests | Coverage |
|----------|-------|----------|
| Models | 27 | ~90% |
| Services | 15 | ~85% |
| Views | 12 | ~80% |
| **Total** | **54+** | **~87%** |

---

## 🔐 Security

### Authentication

- **Local Mode**: No password required for demo
- **Demo Credentials**: 
  - Email: `local@taskflow.dev`
  - Auto-login on first launch

### Data Protection

- SwiftData local storage
- No external network calls (offline-first)
- User data isolated per installation

---

## 📊 SwiftData Integration

### Model Container Setup

```swift
let schema = Schema([
    User.self,
    Workspace.self,
    WorkspaceMember.self,
    Project.self,
    BoardColumn.self,
    Task.self,
    Subtask.self,
    Comment.self,
    Label.self,
    NotificationModel.self
])

let modelContainer = try ModelContainer(
    for: schema,
    configurations: [ModelConfiguration()]
)
```

### Fetching Data

```swift
@Query private var workspaces: [Workspace]
@Query(sort: \Workspace.createdAt) var sortedWorkspaces: [Workspace]

// With predicate
let predicate = #Predicate<Workspace> { $0.isArchived == false }
let activeWorkspaces = try dataService.fetch(Workspace.self, predicate: predicate)
```

---

## 🎯 Key Implementation Details

### Adaptive Layouts

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass

var body: some View {
    if horizontalSizeClass == .regular {
        // iPad/Mac layout
        NavigationSplitView { ... }
    } else {
        // iPhone layout
        NavigationStack { ... }
    }
}
```

### Repository Pattern

```swift
@MainActor
final class TaskRepository: BaseRepository<Task> {
    func getTasksForProject(projectId: String) throws -> [Task] {
        let predicate = #Predicate<Task> { $0.project?.id == projectId }
        return try dataService.fetch(Task.self, predicate: predicate)
    }
    
    func createTask(title: String, ...) throws -> Task {
        let task = Task(title: title, ...)
        dataService.insert(task)
        try dataService.save()
        return task
    }
}
```

---

## 🛠️ Development

### Code Style

- **SwiftLint**: Enabled for consistent code style
- **Format**: 4 spaces, no tabs
- **Naming**: PascalCase for types, camelCase for variables

### Git Workflow

```bash
# Feature branch
git checkout -b feature/new-feature

# Commit changes
git add .
git commit -m "feat: add new feature"

# Push and PR
git push origin feature/new-feature
```

---

## 📈 Roadmap

### Phase 1 (Completed) ✅
- [x] Core data models
- [x] Repository pattern
- [x] Basic UI components
- [x] Dashboard views
- [x] Workspace management
- [x] Project Kanban boards
- [x] Task management
- [x] Subtasks & comments
- [x] Multi-platform support

### Phase 2 (Planned)
- [ ] Drag-and-drop for Kanban
- [ ] Real-time sync (CloudKit)
- [ ] Push notifications
- [ ] Widget support
- [ ] Siri Shortcuts
- [ ] Apple Watch app

### Phase 3 (Future)
- [ ] Team collaboration
- [ ] File attachments
- [ ] Advanced filtering
- [ ] Calendar view
- [ ] Timeline/Gantt view
- [ ] Export to PDF/CSV

---

## 📄 License

This project is for portfolio demonstration purposes.

---

## 👨‍💻 Author

**TaskFlow Team**

A Senior-Level Portfolio Project demonstrating:
- Full-stack iOS/macOS development
- SwiftUI & SwiftData expertise
- MVVM architecture
- Multi-platform support
- Comprehensive testing

---

## 🙏 Acknowledgments

- Inspired by Trello and Asana
- Built with SwiftUI & SwiftData
- Designed for Apple platforms

---

**Built with ❤️ for Apple Platforms**
