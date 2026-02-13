import Foundation
import CoreData

/// Provides chat-related business logic on top of the repository layer.
///
/// Handles simulated auto-replies to mimic a real messaging experience.
/// In a production app this would integrate with a networking layer.
class ChatService {
    
    // MARK: - Dependencies
    
    private let repository: ConversationRepositoryProtocol
    
    // MARK: - Initialization
    
    init(repository: ConversationRepositoryProtocol) {
        self.repository = repository
    }
    
    // MARK: - Simulated Replies
    
    /// Simulates an incoming reply from the contact after a short delay.
    /// - Parameter conversation: The conversation to receive the auto-reply.
    func simulateIncomingReply(in conversation: Conversation) {
        let replies = [
            "Got it! 👍",
            "Sounds good to me!",
            "Let me think about that...",
            "That's interesting! Tell me more.",
            "Sure, I'll get back to you soon.",
            "Thanks for letting me know! 😊",
            "Absolutely, count me in!",
            "I'll check and confirm later."
        ]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            guard let content = replies.randomElement() else { return }
            
            // Use repository to persist the incoming message
            self.repository.sendMessage(content, to: conversation, sender: .contact, replyTo: nil)
        }
    }
}
