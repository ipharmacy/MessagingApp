import Foundation
import Combine
import CoreData

/// ViewModel for the chat screen.
///
/// Manages the message list for a single conversation, handles sending messages
/// (including replies), and triggers simulated auto-replies.
class ChatViewModel: ObservableObject {
    
    // MARK: - Published State
    
    /// All messages in the conversation, sorted chronologically (oldest first).
    @Published var messages: [Message] = []
    
    /// The current text in the message input field.
    @Published var messageText: String = ""
    
    /// The message the user is replying to, or `nil` if not in reply mode.
    @Published var replyingTo: Message?
    
    // MARK: - Dependencies
    
    private let conversation: Conversation
    private let repository: ConversationRepositoryProtocol
    private let chatService: ChatService?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Display name of the conversation partner.
    var contactName: String {
        conversation.contactName
    }
    
    /// Initials of the contact for the avatar.
    var contactInitials: String {
        conversation.contactInitials
    }
    
    // MARK: - Initialization
    
    /// Creates a chat view model.
    /// - Parameters:
    ///   - conversation: The conversation to display.
    ///   - repository: The repository for persistence operations.
    ///   - chatService: Optional chat service for simulated replies.
    init(conversation: Conversation,
         repository: ConversationRepositoryProtocol,
         chatService: ChatService? = nil) {
        self.conversation = conversation
        self.repository = repository
        self.chatService = chatService
        
        loadMessages()
        
        // Re-load messages whenever the repository reports a data change.
        repository.conversations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadMessages()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    private func loadMessages() {
        messages = conversation.messagesArray
        markAllAsRead()
    }
    
    /// Marks all incoming messages in this conversation as read.
    func markAllAsRead() {
        let unread = messages.filter { $0.sender == .contact && $0.status != .read }
        guard !unread.isEmpty else { return }
        
        for message in unread {
            message.status = .read
        }
        
        // Pick any message to trigger a repository update/save
        if let first = unread.first {
            repository.updateMessage(first)
        }
    }
    
    // MARK: - Actions
    
    /// Sends the current message text. Clears the input and exits reply mode.
    func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        repository.sendMessage(trimmed, to: conversation, sender: .me, replyTo: replyingTo)
        
        // Clear input state.
        messageText = ""
        replyingTo = nil
        
        // Trigger a simulated auto-reply for demonstration purposes.
        chatService?.simulateIncomingReply(in: conversation)
    }
    
    /// Activates reply mode for the given message.
    func setReply(to message: Message) {
        replyingTo = message
    }
    
    /// Cancels the current reply mode.
    func cancelReply() {
        replyingTo = nil
    }
    
    /// Soft-deletes a message from the conversation.
    func deleteMessage(_ message: Message) {
        message.isMessageDeleted = true
        message.content = nil // Optional: clear content
        message.mediaData = nil // Optional: clear media
        repository.updateMessage(message)
    }
    
    /// Sends an image message.
    func sendImage(_ data: Data) {
        repository.sendMedia(data, type: .image, to: conversation, replyTo: replyingTo)
        replyingTo = nil
    }
    
    /// Sends a video message.
    func sendVideo(_ data: Data) {
        repository.sendMedia(data, type: .video, to: conversation, replyTo: replyingTo)
        replyingTo = nil
    }
}
