import XCTest
@testable import MessagingApp
import CoreData
import Combine

// MARK: - MessagingApp Test Suite

/// Comprehensive unit tests covering conversation management, message sorting,
/// reply logic, and repository operations.
final class MessagingAppTests: XCTestCase {
    
    // MARK: - Properties
    
    var persistenceController: PersistenceController!
    var repository: ConversationRepository!
    var context: NSManagedObjectContext!
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        repository = ConversationRepository(context: context)
        cancellables = []
    }
    
    override func tearDownWithError() throws {
        cancellables.removeAll()
        persistenceController = nil
        repository = nil
        context = nil
    }
    
    // MARK: - Conversation Creation Tests
    
    func testConversationCreation() throws {
        let name = "John Doe"
        let conversation = repository.createConversation(contactName: name)
        
        XCTAssertNotNil(conversation.id, "Conversation should have a UUID")
        XCTAssertEqual(conversation.contactName, name, "Contact name should match")
        XCTAssertNotNil(conversation.lastMessageTimestamp, "Timestamp should be set")
        
        let fetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1, "Exactly one conversation should exist")
    }
    
    func testMultipleConversationCreation() throws {
        let names = ["Alice", "Bob", "Charlie"]
        for name in names {
            repository.createConversation(contactName: name)
        }
        
        let fetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 3, "Three conversations should exist")
    }
    
    func testConversationContactNamePersistence() throws {
        let name = "Jane Smith"
        let conversation = repository.createConversation(contactName: name)
        
        // Save and re-fetch to verify persistence
        try context.save()
        context.refresh(conversation, mergeChanges: false)
        
        XCTAssertEqual(conversation.contactName, name, "Contact name should persist after refresh")
    }
    
    // MARK: - Message Sending Tests
    
    func testMessageSending() throws {
        let conversation = repository.createConversation(contactName: "Test Contact")
        
        repository.sendMessage("Hello", to: conversation)
        repository.sendMessage("World", to: conversation)
        
        XCTAssertEqual(conversation.messagesArray.count, 2, "Two messages should exist")
        XCTAssertEqual(conversation.messagesArray[0].content, "Hello")
        XCTAssertEqual(conversation.messagesArray[1].content, "World")
    }
    
    func testMessageDefaultValues() throws {
        let conversation = repository.createConversation(contactName: "Default Test")
        repository.sendMessage("Test message", to: conversation)
        
        let message = conversation.messagesArray.first!
        
        XCTAssertNotNil(message.id, "Message should have a UUID")
        XCTAssertNotNil(message.timestamp, "Message should have a timestamp")
        XCTAssertEqual(message.sender, .me, "Sender should default to .me")
        XCTAssertEqual(message.status, .sent, "Status should default to .sent")
        XCTAssertEqual(message.content, "Test message")
    }
    
    func testMessageUpdatesConversationTimestamp() throws {
        let conversation = repository.createConversation(contactName: "Timestamp Test")
        let originalTimestamp = conversation.lastMessageTimestamp!
        
        // Wait a tiny interval to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.01)
        
        repository.sendMessage("New message", to: conversation)
        
        XCTAssertGreaterThan(
            conversation.lastMessageTimestamp!,
            originalTimestamp,
            "Conversation timestamp should update after sending a message"
        )
    }
    
    // MARK: - Message Sorting Tests
    
    func testMessageSortingChronologicalOrder() throws {
        let conversation = repository.createConversation(contactName: "Sorting Contact")
        
        let now = Date()
        
        let message1 = Message(context: context)
        message1.id = UUID()
        message1.content = "Oldest"
        message1.timestamp = now.addingTimeInterval(-120) // 2 minutes ago
        message1.conversation = conversation
        
        let message2 = Message(context: context)
        message2.id = UUID()
        message2.content = "Middle"
        message2.timestamp = now.addingTimeInterval(-60) // 1 minute ago
        message2.conversation = conversation
        
        let message3 = Message(context: context)
        message3.id = UUID()
        message3.content = "Newest"
        message3.timestamp = now
        message3.conversation = conversation
        
        try context.save()
        
        let messages = conversation.messagesArray
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[0].content, "Oldest", "First should be oldest")
        XCTAssertEqual(messages[1].content, "Middle", "Second should be middle")
        XCTAssertEqual(messages[2].content, "Newest", "Third should be newest")
    }
    
    func testMessageSortingWithSameTimestamp() throws {
        let conversation = repository.createConversation(contactName: "Same Time Contact")
        let fixedDate = Date()
        
        for i in 0..<5 {
            let message = Message(context: context)
            message.id = UUID()
            message.content = "Message \(i)"
            message.timestamp = fixedDate
            message.conversation = conversation
        }
        
        try context.save()
        
        let messages = conversation.messagesArray
        XCTAssertEqual(messages.count, 5, "All messages should be present even with same timestamp")
    }
    
    // MARK: - Reply Logic Tests
    
    func testReplyCreation() throws {
        let conversation = repository.createConversation(contactName: "Reply Contact")
        
        repository.sendMessage("Original", to: conversation)
        let original = conversation.messagesArray.first!
        
        repository.sendMessage("Reply to original", to: conversation, replyTo: original)
        let reply = conversation.messagesArray.last!
        
        XCTAssertEqual(reply.replyToMessage, original, "Reply should reference the original message")
        XCTAssertEqual(reply.content, "Reply to original")
        XCTAssertEqual(reply.replyToMessage?.content, "Original", "Referenced content should match")
    }
    
    func testReplyInverseRelationship() throws {
        let conversation = repository.createConversation(contactName: "Inverse Reply")
        
        repository.sendMessage("Parent message", to: conversation)
        let parent = conversation.messagesArray.first!
        
        repository.sendMessage("Reply 1", to: conversation, replyTo: parent)
        repository.sendMessage("Reply 2", to: conversation, replyTo: parent)
        
        // The parent should have 2 replies via the inverse relationship
        let replies = parent.replies as? Set<Message> ?? []
        XCTAssertEqual(replies.count, 2, "Parent should have two replies")
        
        let replyContents = replies.compactMap(\.content).sorted()
        XCTAssertEqual(replyContents, ["Reply 1", "Reply 2"])
    }
    
    func testReplyToReply() throws {
        let conversation = repository.createConversation(contactName: "Chain Reply")
        
        repository.sendMessage("Root", to: conversation)
        let root = conversation.messagesArray.first!
        
        repository.sendMessage("Reply to root", to: conversation, replyTo: root)
        let firstReply = conversation.messagesArray.last!
        
        repository.sendMessage("Reply to reply", to: conversation, replyTo: firstReply)
        let secondReply = conversation.messagesArray.last!
        
        XCTAssertEqual(secondReply.replyToMessage, firstReply, "Second reply should reference first reply")
        XCTAssertEqual(secondReply.replyToMessage?.replyToMessage, root, "Chain should lead back to root")
    }
    
    func testMessageWithoutReply() throws {
        let conversation = repository.createConversation(contactName: "No Reply")
        
        repository.sendMessage("Standalone message", to: conversation)
        let message = conversation.messagesArray.first!
        
        XCTAssertNil(message.replyToMessage, "Non-reply message should have nil replyToMessage")
    }
    
    // MARK: - Conversation Sorting by Latest Activity
    
    func testConversationSortingByLatestActivity() throws {
        // Create conversations with distinct timestamps
        let conv1 = repository.createConversation(contactName: "Conv 1")
        Thread.sleep(forTimeInterval: 0.01)
        _ = repository.createConversation(contactName: "Conv 2")
        Thread.sleep(forTimeInterval: 0.01)
        
        let expectation = XCTestExpectation(description: "Fetch conversations after update")
        
        // Subscribe BEFORE the action that changes the order
        repository.conversations
            .dropFirst() // Drop the current state
            .sink { conversations in
                // We assume successful sort if Conv 1 is first (most recent)
                if conversations.first?.contactName == "Conv 1" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
            
        // Now send a message to conv1, making it the most recently active
        repository.sendMessage("New activity in conv1", to: conv1)
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testConversationSortingMultipleUpdates() throws {
        let conv1 = repository.createConversation(contactName: "Alpha")
        Thread.sleep(forTimeInterval: 0.01)
        let conv2 = repository.createConversation(contactName: "Beta")
        Thread.sleep(forTimeInterval: 0.01)
        let conv3 = repository.createConversation(contactName: "Gamma")
        
        let expectation = XCTestExpectation(description: "Final sort order")
        
        // Subscribe BEFORE the actions
        repository.conversations
            .dropFirst()
            .sink { conversations in
                if conversations.count == 3 {
                    // Check if we hit the target state: Beta (newest), Gamma, Alpha
                    if conversations[0].contactName == "Beta" &&
                       conversations[1].contactName == "Gamma" &&
                       conversations[2].contactName == "Alpha" {
                        expectation.fulfill()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Send messages in specific order to control sorting
        Thread.sleep(forTimeInterval: 0.01)
        repository.sendMessage("Message to Alpha", to: conv1)
        Thread.sleep(forTimeInterval: 0.01)
        repository.sendMessage("Message to Gamma", to: conv3)
        Thread.sleep(forTimeInterval: 0.01)
        repository.sendMessage("Message to Beta", to: conv2)
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - Deletion Tests
    
    func testConversationDeletion() throws {
        let conversation = repository.createConversation(contactName: "Delete Me")
        repository.sendMessage("Hello", to: conversation)
        
        repository.deleteConversation(conversation)
        
        let fetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 0, "Conversation should be deleted")
        
        // Messages should be cascade-deleted
        let msgRequest: NSFetchRequest<Message> = Message.fetchRequest()
        let messages = try context.fetch(msgRequest)
        XCTAssertEqual(messages.count, 0, "Messages should be cascade-deleted")
    }
    
    func testMessageDeletion() throws {
        let conversation = repository.createConversation(contactName: "Msg Delete")
        repository.sendMessage("Message 1", to: conversation)
        repository.sendMessage("Message 2", to: conversation)
        
        // Test Hard Delete (Repository level)
        let messageToDelete = conversation.messagesArray.first!
        repository.deleteMessage(messageToDelete)
        
        XCTAssertEqual(conversation.messagesArray.count, 1, "One message should remain after hard delete")
        XCTAssertEqual(conversation.messagesArray.first?.content, "Message 2")
    }
    
    func testMessageSoftDeletion() throws {
        let conversation = repository.createConversation(contactName: "Soft Delete")
        repository.sendMessage("To be deleted", to: conversation)
        
        let message = conversation.messagesArray.first!
        
        // Simulate Soft Delete (ViewModel level)
        message.isMessageDeleted = true
        repository.updateMessage(message)
        
        XCTAssertTrue(message.isMessageDeleted, "Message should be marked as deleted")
        XCTAssertFalse(message.isDeleted, "Core Data object should not be deleted")
        XCTAssertEqual(conversation.messagesArray.count, 1, "Message should still exist in conversation")
    }
    
    func testMediaMessageSending() throws {
        let conversation = repository.createConversation(contactName: "Media User")
        let dummyData = Data([0x00, 0x01, 0x02])
        
        repository.sendMedia(dummyData, type: .video, to: conversation)
        
        let message = conversation.messagesArray.first!
        XCTAssertEqual(message.mediaType, .video, "Media type should be video")
        XCTAssertEqual(message.content, "🎥 Video", "Content should be placeholder text")
        XCTAssertEqual(message.mediaData, dummyData, "Data should match")
        
        // Test Image
        repository.sendMedia(dummyData, type: .image, to: conversation)
        let imageMessage = conversation.messagesArray.last!
        XCTAssertEqual(imageMessage.mediaType, .image)
        XCTAssertEqual(imageMessage.content, "📷 Image")
    }
        
    // MARK: - Model Extension Tests
    
    func testLastMessageContent() throws {
        let conversation = repository.createConversation(contactName: "Last Msg Test")
        
        XCTAssertEqual(conversation.lastMessageContent, "No messages yet",
                       "Empty conversation should show placeholder")
        
        repository.sendMessage("First", to: conversation)
        XCTAssertEqual(conversation.lastMessageContent, "First")
        
        repository.sendMessage("Latest", to: conversation)
        XCTAssertEqual(conversation.lastMessageContent, "Latest",
                       "Should return the most recent message content")
    }
    
    func testContactInitials() throws {
        let conv1 = repository.createConversation(contactName: "John Doe")
        XCTAssertEqual(conv1.contactInitials, "JD")
        
        let conv2 = repository.createConversation(contactName: "Alice")
        XCTAssertEqual(conv2.contactInitials, "A")
        
        let conv3 = repository.createConversation(contactName: "Bob Charlie Smith")
        XCTAssertEqual(conv3.contactInitials, "BC") // First two initials
    }
    
    func testMessageSenderDisplayName() throws {
        let conversation = repository.createConversation(contactName: "Display Name Test")
        
        repository.sendMessage("My message", to: conversation)
        let myMessage = conversation.messagesArray.first!
        XCTAssertEqual(myMessage.senderDisplayName, "Me")
        
        // Simulate an incoming message
        let incomingMessage = Message(context: context)
        incomingMessage.id = UUID()
        incomingMessage.content = "Their message"
        incomingMessage.sender = .contact
        incomingMessage.conversation = conversation
        try context.save()
        
        XCTAssertEqual(incomingMessage.senderDisplayName, "Display Name Test")
    }
    
    func testMessageStatusDisplayName() throws {
        let conversation = repository.createConversation(contactName: "Status Test")
        repository.sendMessage("Test", to: conversation)
        
        let message = conversation.messagesArray.first!
        
        message.status = .sent
        XCTAssertEqual(message.statusDisplayName, "Sent")
        
        message.status = .delivered
        XCTAssertEqual(message.statusDisplayName, "Delivered")
        
        message.status = .read
        XCTAssertEqual(message.statusDisplayName, "Read")
    }
}
