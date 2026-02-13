import SwiftUI

/// The main screen displaying all conversations ordered by latest activity.
///
/// Each row shows the contact avatar, name, last message preview, and relative timestamp.
/// Users can swipe to delete conversations or tap the compose button to start a new chat.
struct ConversationListView: View {
    @StateObject private var viewModel: ConversationListViewModel
    private let repository: ConversationRepositoryProtocol
    private let chatService: ChatService?
    
    @State private var showingNewChat = false
    
    init(viewModel: ConversationListViewModel,
         repository: ConversationRepositoryProtocol,
         chatService: ChatService? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.repository = repository
        self.chatService = chatService
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGroupedBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if viewModel.filteredConversations.isEmpty {
                    emptyStateView
                } else {
                    conversationList
                }
            }
            .navigationTitle("Messages")
            .searchable(text: $viewModel.searchText, prompt: "Search conversations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    .accessibilityLabel("New conversation")
                    .accessibilityIdentifier("newChatButton")
                }
            }
            .sheet(isPresented: $showingNewChat) {
                NewChatView(contactService: viewModel.contactService) { contactName in
                    viewModel.createNewConversation(contactName: contactName)
                    showingNewChat = false
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse, options: .repeating)
            
            Text("No Conversations")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Tap the compose button to start\na new conversation")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No conversations. Tap the compose button to start a new conversation.")
    }
    
    private var conversationList: some View {
        List {
            ForEach(viewModel.filteredConversations) { conversation in
                NavigationLink {
                    ChatView(
                        viewModel: ChatViewModel(
                            conversation: conversation,
                            repository: repository,
                            chatService: chatService
                        )
                    )
                } label: {
                    ConversationRow(conversation: conversation)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            repository.deleteConversation(conversation)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .animation(.default, value: viewModel.filteredConversations.count)
    }
}

// MARK: - Conversation Row Component

/// A single row in the conversation list showing the contact avatar, name,
/// last message preview, and relative timestamp.
struct ConversationRow: View {
    @ObservedObject var conversation: Conversation
    
    /// Deterministic gradient colors based on the contact name.
    private var avatarColors: [Color] {
        let hash = abs(conversation.contactName.hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = Double((hash / 360) % 360) / 360.0
        return [
            Color(hue: hue1, saturation: 0.6, brightness: 0.85),
            Color(hue: hue2, saturation: 0.7, brightness: 0.75)
        ]
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: avatarColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .overlay(
                    Text(conversation.contactInitials)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
                .shadow(color: avatarColors[0].opacity(0.3), radius: 4, y: 2)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(conversation.contactName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let date = conversation.lastMessageTimestamp {
                        Text(date, style: .relative)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 6) {
                    if let lastMessage = conversation.messagesArray.last {
                        // Only show media icons if the message exists AND is not deleted
                        if !lastMessage.isMessageDeleted {
                            if lastMessage.mediaType == .image {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            } else if lastMessage.mediaType == .video {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(conversation.lastMessageContent)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(conversation.unreadCount > 0 ? .primary : .secondary)
                            .fontWeight(conversation.unreadCount > 0 ? .semibold : .regular)
                            .lineLimit(1)
                    } else {
                        Text("No messages yet")
                           .font(.system(size: 15, design: .rounded))
                           .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(conversation.contactName). Last message: \(conversation.lastMessageContent)")
        .accessibilityIdentifier("conversationRow_\(conversation.contactName)")
    }
}
