import SwiftUI
import AVKit

/// A message bubble component with distinct styles for incoming and outgoing messages.
///
/// Features:
/// - Gradient backgrounds for outgoing (blue) and incoming (gray) messages
/// - Reply indicator showing the referenced message
/// - Timestamp and delivery status icons
/// - Full accessibility labeling
struct MessageBubble: View {
    @ObservedObject var message: Message
    
    private var isMe: Bool {
        message.sender == .me
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMe { Spacer(minLength: 60) }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                // Combined Bubble (Reply + Content)
                VStack(alignment: .leading, spacing: 0) {
                    // Internal Reply Preview
                    if let reply = message.replyToMessage {
                        replyPreviewBlock(for: reply)
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                            .padding(.bottom, 2)
                    }
                    
                    // Actual Message Content
                    messageContent
                        .padding(.horizontal, message.mediaType == .text ? 12 : 0)
                        .padding(.vertical, message.mediaType == .text ? 8 : 0)
                        .padding(.top, (message.mediaType == .text && message.replyToMessage != nil) ? 4 : 0)
                }
                .background(bubbleBackground)
                .foregroundColor(isMe ? .white : .primary)
                .clipShape(BubbleShape(isMe: isMe))
                .shadow(
                    color: isMe ? Color.blue.opacity(0.3) : Color.black.opacity(0.1),
                    radius: 2,
                    x: 0,
                    y: 1
                )
                
                // Timestamp and status
                HStack(spacing: 4) {
                    Text(message.timestamp ?? Date(), style: .time)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    if isMe {
                        statusIcon
                    }
                }
                .padding(.horizontal, 4)
            }
            
            if !isMe { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityIdentifier("messageBubble_\(message.id?.uuidString ?? "unknown")")
    }
    
    // MARK: - Message Content View
    
    @ViewBuilder
    private var messageContent: some View {
        if message.isMessageDeleted {
            Text("Ce message a été supprimé")
                .font(.system(.body, design: .rounded))
                .italic()
                .foregroundColor(.secondary)
        } else {
            switch message.mediaType {
            case .text:
                Text(message.content ?? "")
                    .font(.system(.body, design: .rounded))
            case .image:
                if let data = message.mediaData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260, maxHeight: 320)
                } else {
                    Text("Error loading image")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            case .video:
                if let data = message.mediaData {
                    VideoPlayerView(data: data)
                        .frame(width: 260, height: 180)
                } else {
                    Text("Error loading video")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Internal Reply Preview Block
    
    private func replyPreviewBlock(for reply: Message) -> some View {
        HStack(spacing: 8) {
            // Colored Quote Bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.purple)
                .frame(width: 4)
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(reply.senderDisplayName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(isMe ? .white.opacity(0.9) : .purple)
                
                Text(reply.content ?? "Media Message")
                    .font(.system(size: 11, design: .rounded))
                    .lineLimit(1)
                    .foregroundColor(isMe ? .white.opacity(0.7) : .secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isMe ? Color.black.opacity(0.15) : Color.gray.opacity(0.1))
        )
        // Ensure it doesn't stretch too wide if message is short
        .fixedSize(horizontal: false, vertical: true)
    }
    
    // MARK: - Bubble Background
    
    private var bubbleBackground: some ShapeStyle {
        if isMe {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.0, green: 0.5, blue: 1.0),
                        Color(red: 0.0, green: 0.35, blue: 0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(
                .ultraThinMaterial
            )
        }
    }
    
    // MARK: - Status Icon
    
    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case .sent:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.6))
        case .delivered:
            HStack(spacing: -3) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary.opacity(0.6))
        case .read:
            HStack(spacing: -3) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Color(red: 0.0, green: 0.7, blue: 1.0))
        }
    }
    
    // MARK: - Accessibility
    
    private var accessibilityDescription: String {
        var label = isMe ? "My message" : "Message from \(message.senderDisplayName)"
        label += ": \(message.content ?? "")"
        
        if let timestamp = message.timestamp {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            label += ". Sent at \(formatter.string(from: timestamp))"
        }
        
        if isMe {
            label += ". Status: \(message.statusDisplayName)"
        }
        
        if message.replyToMessage != nil {
            label += ". This is a reply"
        }
        
        return label
    }
}

// MARK: - Custom Bubble Shape

/// A custom shape that creates a chat-bubble silhouette with a tail on one side.
struct BubbleShape: Shape {
    let isMe: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = Path(
            roundedRect: rect,
            cornerRadius: 20,
            style: .continuous
        )
        return path
    }
}

struct VideoPlayerView: View {
    let data: Data
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            if player == nil {
                loadVideo()
            }
        }
    }
    
    private func loadVideo() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        
        do {
            try data.write(to: fileURL)
            self.player = AVPlayer(url: fileURL)
        } catch {
            print("Error writing video data: \(error)")
        }
    }
}
