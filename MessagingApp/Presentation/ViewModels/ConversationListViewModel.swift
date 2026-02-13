import Foundation
import Combine

/// ViewModel for the main conversation list screen.
///
/// Subscribes to repository updates via Combine and exposes an ordered list
/// of conversations for the view layer. Also drives contact selection for new chats.
class ConversationListViewModel: ObservableObject {
    
    // MARK: - Published State
    
    /// Conversations sorted by latest activity (newest first).
    @Published var conversations: [Conversation] = []
    
    /// Indicates whether data is being loaded (reserved for future async operations).
    @Published var isLoading: Bool = false
    
    /// An optional user-facing error message.
    @Published var errorMessage: String?
    
    /// Search text for filtering conversations.
    @Published var searchText: String = ""
    
    // MARK: - Dependencies
    
    private let repository: ConversationRepositoryProtocol
    let contactService: ContactService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Conversations filtered by the current search text.
    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations
        }
        return conversations.filter { conversation in
            conversation.contactName.localizedCaseInsensitiveContains(searchText) ||
            conversation.lastMessageContent.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Initialization
    
    init(repository: ConversationRepositoryProtocol, contactService: ContactService) {
        self.repository = repository
        self.contactService = contactService
        
        // Subscribe to repository updates.
        repository.conversations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conversations in
                self?.conversations = conversations
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    /// Creates a new conversation for the specified contact name.
    func createNewConversation(contactName: String) {
        _ = repository.createConversation(contactName: contactName)
    }
    
    /// Deletes conversations at the given index set (for swipe-to-delete).
    func deleteConversation(at indexSet: IndexSet) {
        indexSet.forEach { index in
            guard index < filteredConversations.count else { return }
            let conversation = filteredConversations[index]
            repository.deleteConversation(conversation)
        }
    }
    
    /// Sends a message in a conversation, optionally as a reply.
    func sendMessage(_ content: String, to conversation: Conversation, replyTo: Message? = nil) {
        repository.sendMessage(content, to: conversation, sender: .me, replyTo: replyTo)
    }
}
