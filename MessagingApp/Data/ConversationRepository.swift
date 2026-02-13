import Foundation
import CoreData
import Combine

// MARK: - Repository Protocol

/// Defines the public API for conversation and message persistence operations.
/// Conforming to a protocol allows easy mocking in unit tests.
protocol ConversationRepositoryProtocol {
    /// A publisher that emits the ordered list of conversations whenever data changes.
    var conversations: AnyPublisher<[Conversation], Never> { get }
    
    /// Creates and persists a new conversation for the given contact.
    @discardableResult
    func createConversation(contactName: String) -> Conversation
    
    /// Sends a new message in a conversation, optionally as a reply to another message.
    func sendMessage(_ content: String, to conversation: Conversation, sender: MessageSender, replyTo: Message?)
    
    /// Sends a media message (image or video).
    func sendMedia(_ data: Data, type: MediaType, to conversation: Conversation, replyTo: Message?)
    
    /// Deletes a conversation and all of its messages (cascade).
    func deleteConversation(_ conversation: Conversation)
    
    /// Deletes a single message.
    func deleteMessage(_ message: Message)
    
    /// Updates an existing message in the repository.
    func updateMessage(_ message: Message)
}

// MARK: - ConversationRepository

/// Concrete implementation of `ConversationRepositoryProtocol` backed by Core Data.
///
/// Uses `NSFetchedResultsController` to efficiently observe changes and publish
/// an up-to-date list of conversations via Combine.
class ConversationRepository: NSObject, ConversationRepositoryProtocol {
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    private let conversationsSubject = CurrentValueSubject<[Conversation], Never>([])
    private var fetchedResultsController: NSFetchedResultsController<Conversation>?
    
    /// Publishes the current list of conversations, sorted by latest activity (newest first).
    var conversations: AnyPublisher<[Conversation], Never> {
        conversationsSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    /// Creates a repository operating on the given managed object context.
    /// - Parameter context: The `NSManagedObjectContext` to use for all operations.
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        super.init()
        setupFetchedResultsController()
    }
    
    // MARK: - Fetched Results Controller
    
    private func setupFetchedResultsController() {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Conversation.lastMessageTimestamp, ascending: false)
        ]
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController?.delegate = self
        
        do {
            try fetchedResultsController?.performFetch()
            conversationsSubject.send(fetchedResultsController?.fetchedObjects ?? [])
        } catch {
            print("Error fetching conversations: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    
    @discardableResult
    func createConversation(contactName: String) -> Conversation {
        let conversation = Conversation(context: context)
        conversation.id = UUID()
        conversation.contactName = contactName
        conversation.lastMessageTimestamp = Date()
        save()
        return conversation
    }
    
    func sendMessage(_ content: String, to conversation: Conversation, sender: MessageSender = .me, replyTo: Message? = nil) {
        let message = Message(context: context)
        message.id = UUID()
        message.content = content
        message.timestamp = Date()
        message.sender = sender
        message.status = sender == .me ? .sent : .delivered
        message.mediaType = .text
        message.conversation = conversation
        
        if let replyTo = replyTo {
            message.replyToMessage = replyTo
        }
        
        conversation.lastMessageTimestamp = message.timestamp
        save()
    }
    
    func sendMedia(_ data: Data, type: MediaType, to conversation: Conversation, replyTo: Message? = nil) {
        let message = Message(context: context)
        message.id = UUID()
        message.content = type == .image ? "📷 Image" : "🎥 Video"
        message.mediaData = data
        message.mediaType = type
        message.timestamp = Date()
        message.sender = .me
        message.status = .sent
        message.conversation = conversation
        
        if let replyTo = replyTo {
            message.replyToMessage = replyTo
        }
        
        conversation.lastMessageTimestamp = message.timestamp
        save()
    }
    
    func deleteConversation(_ conversation: Conversation) {
        context.delete(conversation)
        save()
    }
    
    func deleteMessage(_ message: Message) {
        let conversation = message.conversation
        // Use the repository's context, not the shared one
        context.delete(message)
        
        // Update the conversation's last-message timestamp after deletion.
        if let conv = conversation {
            let remaining = conv.messagesArray
            conv.lastMessageTimestamp = remaining.last?.timestamp ?? conv.lastMessageTimestamp
        }
        
        save()
    }
    
    func updateMessage(_ message: Message) {
        // Trigger a change notification on the conversation so that list observers refresh.
        // Even though the timestamp value might stay the same, the notification forces an update.
        if let conversation = message.conversation {
            conversation.willChangeValue(forKey: "lastMessageTimestamp")
            conversation.didChangeValue(forKey: "lastMessageTimestamp")
        }
        save()
    }
    
    // MARK: - Persistence
    
    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension ConversationRepository: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let updatedList = controller.fetchedObjects as? [Conversation] {
            conversationsSubject.send(updatedList)
        }
    }
}
