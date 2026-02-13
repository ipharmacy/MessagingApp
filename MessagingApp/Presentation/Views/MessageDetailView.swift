import SwiftUI

/// A detail view presented as a sheet when the user taps on a message.
///
/// Displays the full message content, sender, timestamp, delivery status,
/// and unique identifier (UUID). If the message is a reply, shows the
/// referenced message as well.
struct MessageDetailView: View {
    let message: Message
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingFullScreenImage = false
    
    var body: some View {
        NavigationStack {
            List {
                // Content section
                Section {
                    messageContent
                        .padding(.vertical, 4)
                        .accessibilityIdentifier("messageDetailContent")
                } header: {
                    Text("Message Content")
                }
                
                // Metadata section
                Section {
                    LabeledContent("Sender") {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(message.sender == .me ? Color.blue : Color.green)
                                .frame(width: 8, height: 8)
                            Text(message.senderDisplayName)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityIdentifier("messageDetailSender")
                    
                    LabeledContent("Status") {
                        HStack(spacing: 6) {
                            statusIcon
                            Text(message.statusDisplayName)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityIdentifier("messageDetailStatus")
                    
                    if let timestamp = message.timestamp {
                        LabeledContent("Date") {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(timestamp, style: .date)
                                    .foregroundColor(.secondary)
                                Text(timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .accessibilityIdentifier("messageDetailTimestamp")
                    }
                } header: {
                    Text("Details")
                }
                
                // Technical section
                Section {
                    LabeledContent("Message UUID") {
                        Text(message.id?.uuidString ?? "N/A")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    .accessibilityIdentifier("messageDetailUUID")
                    
                    if let replyTo = message.replyToMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("In Reply To")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.blue)
                                    .frame(width: 3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(replyTo.senderDisplayName)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                    
                                    Text(replyTo.content ?? "")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(3)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityIdentifier("messageDetailReplyTo")
                    }
                } header: {
                    Text("Technical")
                }
            }
            .navigationTitle("Message Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("messageDetailDone")
                }
            }
        }
    }
    
    // MARK: - Message Content
    
    @ViewBuilder
    private var messageContent: some View {
        switch message.mediaType {
        case .text:
            Text(message.content ?? "")
                .font(.body)
        case .image:
            if let data = message.mediaData, let uiImage = UIImage(data: data) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            showingFullScreenImage = true
                        }
                    
                    Text(message.content ?? "") // "📷 Image"
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .fullScreenCover(isPresented: $showingFullScreenImage) {
                    FullScreenImageView(image: uiImage)
                }
            } else {
                Text("Error loading image")
                    .foregroundColor(.red)
            }
        case .video:
            if let data = message.mediaData {
                VStack(alignment: .leading, spacing: 12) {
                    VideoDetailsView(data: data)
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Text(message.content ?? "") // "🎥 Video"
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Error loading video")
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Status Icon
    
    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case .sent:
            Image(systemName: "checkmark")
                .foregroundColor(.secondary)
                .font(.caption)
        case .delivered:
            Image(systemName: "checkmark.circle")
                .foregroundColor(.secondary)
                .font(.caption)
        case .read:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.blue)
                .font(.caption)
        }
    }
}

// MARK: - Helper Views

struct FullScreenImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
            
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

import AVKit

struct VideoDetailsView: View {
    let data: Data
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if player == nil {
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
    }
}
