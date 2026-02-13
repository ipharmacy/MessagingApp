# iOS Messaging App

A simplified WhatsApp-like messaging application built for iOS 17+, demonstrating clean architecture, local persistence, and modern UI implementation using Swift and SwiftUI.

## 📱 Features

### Core Requirements
- **Contacts**: Fetches local device contacts with proper permission handling. Falls back to mock data if denied.
- **Conversation List**: ordered by latest activity, showing previews and unread status.
- **Chat Interface**: Full message history with distinct bubbles for incoming/outgoing messages.
- **Messaging**: "Soft" real-time updates for sending text, images, and video.
- **Reply System**: Swipe-to-reply or long-press to reply, with referencing visualization.
- **Media Support**: Send images and videos from the photo library.
- **Details View**: View full message metadata (status, sender, UUID).

### Bonus Features
- **Search**: integrated search in both conversation list and chat detail.
- **Soft Delete**: Messages can be "deleted" (content hidden) without breaking consistency.
- **Accessibility**: Comprehensive accessibility labels and identifiers for UI testing/VoiceOver.
- **Dark Mode**: Fully supported via adaptive system colors.

## 🛠 Tech Stack

- **Language**: Swift 5.10
- **UI Framework**: SwiftUI
- **Architecture**: MVVM-C (Model-View-ViewModel with Coordinator/Router concepts simplified for SwiftUI NavigationStack) + Repository Pattern.
- **Persistence**: Core Data
- **Concurrency**: Combine & `async/await`
- **Testing**: XCTest (Unit Tests)

## 🏗 Architecture & Design

The application follows a strict **MVVM (Model-View-ViewModel)** pattern to ensure separation of concerns:

### 1. Presentation Layer (Views & ViewModels)
- **Views**: Pure SwiftUI views that declare the UI state. They observe ViewModels.
- **ViewModels**: `ObservableObject` classes that hold state (`@Published` properties) and handle business logic. They do *not* import CoreData directly if possible, relying on the Repository.

### 2. Domain/Data Layer (Repositories)
- **ConversationRepository**: A protocol-oriented repository that abstracts Core Data operations.
- **Protocol**: `ConversationRepositoryProtocol` allows for easy mocking in unit tests.
- **Combine**: Exposes data streams (e.g. `conversations` publisher) so ViewModels reactively update when the underlying database changes.

### 3. Persistence Layer (Core Data)
- **PersistenceController**: Manages the `NSPersistentContainer`.
- **Entities**: `Conversation` (1) <---> (Many) `Message`.
- **Extensions**: `ModelExtensions.swift` provides clean, type-safe wrappers around `NSManagedObject` properties (enums for Status, Sender, MediaType).

## 🚀 Setup Instructions

1. **Requirements**: Xcode 15+ (iOS 17 SDK).
2. **Open Project**: Double-click `MessagingApp.xcodeproj`.
3. **Run**: Select a Simulator (e.g., iPhone 15 Pro) and press `Cmd+R`.
4. **Permissions**: When prompted, allow access to Contacts to see "Real" contacts. If denied, the app will auto-load mock contacts.

## 🧪 Testing

The project includes a suite of XCTests covering:
- **Core Data Integration**: Verifying CRUD operations and relationships.
- **ViewModel Logic**: Testing state updates, soft-deletion, and sorting.
- **Extensions**: Verifying computed properties and enum mapping.

**To run tests:**
Press `Cmd+U` in Xcode.

## 📝 Assumptions & Limitations

- **Backend**: As requested, there is no real backend. "Sending" a message saves it locally and simulates a reception delay/reply in some cases.
- **Media Storage**: Images/Videos are stored as `Data` blobs in Core Data. In a production app, these would be saved to disk with file paths stored in the DB to avoid bloating the SQLite file.
- **Contacts**: The app assumes contacts are read-only from the system. New conversations are "started" by selecting a contact.
