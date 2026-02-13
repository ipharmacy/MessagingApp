import CoreData

/// Manages the Core Data stack for the application.
///
/// Provides both the shared (on-disk) persistence controller for production use
/// and an in-memory variant for SwiftUI previews and unit tests.
struct PersistenceController {
    
    // MARK: - Shared Instance
    
    /// Singleton instance backed by the on-disk SQLite store.
    static let shared = PersistenceController()
    
    // MARK: - Preview Instance
    
    /// In-memory persistence controller pre-seeded with sample data for SwiftUI previews.
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        let contacts = ["Alice Johnson", "Bob Smith", "Charlie Brown", "Diana Ross", "Eve Martinez"]
        let sampleMessages = [
            ["Hey, how are you?", "I'm doing great, thanks!", "Want to grab lunch tomorrow?"],
            ["Did you finish the project?", "Almost done, just fixing tests.", "Nice work!"],
            ["Happy birthday! 🎂", "Thank you so much! 🥳"],
            ["The meeting is at 3pm", "Got it, I'll be there.", "Don't forget the slides!"],
            ["Check out this new app", "Looks amazing!", "Let's discuss later"]
        ]
        
        for (index, name) in contacts.enumerated() {
            let conversation = Conversation(context: context)
            conversation.id = UUID()
            conversation.contactName = name
            conversation.lastMessageTimestamp = Date().addingTimeInterval(TimeInterval(-index * 3600))
            
            for (msgIndex, content) in sampleMessages[index].enumerated() {
                let message = Message(context: context)
                message.id = UUID()
                message.content = content
                message.timestamp = Date().addingTimeInterval(TimeInterval(-index * 3600 + msgIndex * 60))
                message.senderRaw = Int16(msgIndex % 2 == 0 ? 0 : 1)
                message.statusRaw = Int16([0, 1, 2][msgIndex % 3])
                message.conversation = conversation
            }
        }
        
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("Preview seeding error: \(nsError), \(nsError.userInfo)")
        }
        return controller
    }()
    
    // MARK: - Properties
    
    /// The underlying `NSPersistentContainer` that owns the managed-object model and store.
    let container: NSPersistentContainer
    
    // MARK: - Initializer
    
    /// Creates a persistence controller.
    /// - Parameter inMemory: When `true`, uses `/dev/null` as the store URL so data
    ///   is never written to disk (useful for tests and previews).
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MessagingApp")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // In production, log to a crash reporting service instead of printing.
                print("CoreData Error: \(error), \(error.userInfo)")
            }
        }
        
        // Automatically merge changes pushed from background contexts.
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Convenience Save
    
    /// Saves the view context if it has pending changes.
    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("Error saving context: \(nsError), \(nsError.userInfo)")
        }
    }
}
