import Foundation
import CoreData

// MARK: - MessageSender Enum

/// Represents who sent a message within the conversation.
enum MessageSender: Int16 {
    /// The current user (owner of the device).
    case me = 0
    /// The other participant in the conversation.
    case contact = 1
}

// MARK: - MessageStatus Enum

/// Tracks the delivery lifecycle of a message.
enum MessageStatus: Int16 {
    /// Message has been created and saved locally.
    case sent = 0
    /// Message has been delivered to the recipient (simulated).
    case delivered = 1
    /// Message has been read by the recipient (simulated).
    case read = 2
}

// MARK: - MediaType Enum

/// Defines the content type of a message.
enum MediaType: Int16 {
    /// Standard text message.
    case text = 0
    /// Image attachment.
    case image = 1
    /// Video attachment.
    case video = 2
}

// MARK: - Message Extensions

extension Message {
    
    /// Type-safe accessor for `senderRaw` backed by `MessageSender` enum.
    var sender: MessageSender {
        get { MessageSender(rawValue: senderRaw) ?? .me }
        set { senderRaw = newValue.rawValue }
    }
    
    /// Type-safe accessor for `statusRaw` backed by `MessageStatus` enum.
    var status: MessageStatus {
        get { MessageStatus(rawValue: statusRaw) ?? .sent }
        set { statusRaw = newValue.rawValue }
    }
    
    /// Type-safe accessor for `mediaTypeRaw` backed by `MediaType` enum.
    var mediaType: MediaType {
        get { MediaType(rawValue: mediaTypeRaw) ?? .text }
        set { mediaTypeRaw = newValue.rawValue }
    }
    

    
    /// A human-readable label for the sender.
    var senderDisplayName: String {
        sender == .me ? "Me" : (conversation?.contactName ?? "Contact")
    }
    
    /// A human-readable label for the message status.
    var statusDisplayName: String {
        switch status {
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .read: return "Read"
        }
    }
}

// MARK: - Conversation Extensions

extension Conversation {
    

    
    /// Convenience wrapper for the stored `contactName_` attribute.
    /// Falls back to "Unknown" if no name has been set.
    var contactName: String {
        get { contactName_ ?? "Unknown" }
        set { contactName_ = newValue }
    }
    
    /// Returns initials derived from the contact name (up to 2 characters).
    var contactInitials: String {
        let components = contactName.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.prefix(2)
        return String(initials).uppercased()
    }
    
    /// Messages belonging to this conversation, sorted chronologically (oldest first).
    var messagesArray: [Message] {
        let set = messages as? Set<Message> ?? []
        return set.sorted {
            ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast)
        }
    }
    
    /// Preview text for the conversation list — shows the last message content.
    var lastMessageContent: String {
        guard let lastMessage = messagesArray.last else {
            return "No messages yet"
        }
        
        if lastMessage.isMessageDeleted {
            return "This message was deleted"
        }
        
        return lastMessage.content ?? "No content"
    }
    
    /// The number of unread messages from the contact in this conversation.
    var unreadCount: Int {
        messagesArray.filter { $0.sender == .contact && $0.status != .read }.count
    }
}
