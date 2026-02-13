import SwiftUI
import PhotosUI
import AVKit

/// The chat screen for a single conversation.
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var searchResults: [UUID] = []
    @State private var currentSearchIndex = 0
    @State private var selectedMessage: Message?
    @State private var selectedItem: PhotosPickerItem?
    @FocusState private var isInputFocused: Bool
    
    /// Deterministic avatar colors derived from the contact name.
    private var avatarColors: [Color] {
        let hash = abs(viewModel.contactName.hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = Double((hash / 360) % 360) / 360.0
        return [
            Color(hue: hue1, saturation: 0.6, brightness: 0.85),
            Color(hue: hue2, saturation: 0.7, brightness: 0.75)
        ]
    }
    var body: some View {
        ZStack {
            // Adaptive background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    if isSearching {
                        searchBar(proxy: proxy)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                                    .background(
                                        searchResults.contains(message.id ?? UUID()) ? Color.red.opacity(0.3).cornerRadius(10) : nil
                                    )
                                    .onTapGesture {
                                        selectedMessage = message
                                    }
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                                        removal: .opacity
                                    ))
                                    .contextMenu {
                                        Button {
                                            viewModel.setReply(to: message)
                                        } label: {
                                            Label("Reply", systemImage: "arrowshape.turn.up.left")
                                        }
                                        
                                        Button(role: .destructive) {
                                            viewModel.deleteMessage(message)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                            
                            // Bottom spacer to ensure scrolling to the very end works reliably
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 20)
                    }
                    .defaultScrollAnchor(.bottom)
                    .scrollDismissesKeyboard(.interactively)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        VStack(spacing: 0) {
                            if let reply = viewModel.replyingTo {
                                replyPreview(for: reply)
                                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                            }
                            
                            Divider()
                                .opacity(0.3)
                            
                            inputBar
                        }
                        .background(.regularMaterial)
                    }
                    .onTapGesture {
                        isInputFocused = false
                        // Don't dismiss search on tap, let user toggle it
                    }
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if !isSearching {
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }
                .onChange(of: isInputFocused) { _, isFocused in
                    if isFocused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 1)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: viewModel.replyingTo) { _, _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 1)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.replyingTo != nil)
        .animation(.easeInOut(duration: 0.2), value: isSearching)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.regularMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                appBarHeader
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation {
                        isSearching.toggle()
                        if !isSearching {
                            searchText = ""
                            searchResults = []
                        }
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
        }
        .onDisappear {
            isInputFocused = false
        }
        .sheet(item: $selectedMessage) { message in
            MessageDetailView(message: message)
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                guard let newItem = newItem else { return }
                
                // Check for video first
                if newItem.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) }) {
                    do {
                        if let movie = try? await newItem.loadTransferable(type: Movie.self) {
                            let data = try Data(contentsOf: movie.url)
                            await MainActor.run { viewModel.sendVideo(data) }
                        }
                    } catch {
                        print("Failed to load video: \(error)")
                    }
                } else {
                    // Fallback to image
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run { viewModel.sendImage(data) }
                    }
                }
                
                selectedItem = nil
            }
        }
    }
    
    // MARK: - Search Bar
    
    private func searchBar(proxy: ScrollViewProxy) -> some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        performSearch(query: newValue, proxy: proxy)
                    }
                
                if !searchText.isEmpty {
                    Text("\(currentSearchIndex + 1) of \(searchResults.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 0) {
                        Button {
                            navigateSearch(direction: -1, proxy: proxy)
                        } label: {
                            Image(systemName: "chevron.up")
                                .padding(8)
                        }
                        .disabled(searchResults.isEmpty)
                        
                        Button {
                            navigateSearch(direction: 1, proxy: proxy)
                        } label: {
                            Image(systemName: "chevron.down")
                                .padding(8)
                        }
                        .disabled(searchResults.isEmpty)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            Button("Cancel") {
                withAnimation {
                    isSearching = false
                    searchText = ""
                    searchResults = []
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.regularMaterial)
    }
    
    private func performSearch(query: String, proxy: ScrollViewProxy) {
        if query.isEmpty {
            searchResults = []
            return
        }
        
        // Find matches (reversed so index 0 is the newest message, which feels more natural for "prev/next" in chat)
        let matches = viewModel.messages.filter { $0.content?.localizedCaseInsensitiveContains(query) == true }
        searchResults = matches.compactMap { $0.id }
        
        if !searchResults.isEmpty {
            currentSearchIndex = searchResults.count - 1 // Start at the most recent message (bottom)
            if let id = searchResults.last {
                 withAnimation {
                     proxy.scrollTo(id, anchor: .center)
                 }
            }
        }
    }
    
    private func navigateSearch(direction: Int, proxy: ScrollViewProxy) {
        guard !searchResults.isEmpty else { return }
        
        currentSearchIndex += direction
        
        if currentSearchIndex < 0 {
            currentSearchIndex = searchResults.count - 1
        } else if currentSearchIndex >= searchResults.count {
            currentSearchIndex = 0
        }
        
        let id = searchResults[currentSearchIndex]
        withAnimation {
            proxy.scrollTo(id, anchor: .center)
        }
    }
    
    // MARK: - App Bar Header
    
    private var appBarHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: avatarColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(viewModel.contactInitials)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.contactName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Online")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.leading, -8)
    }
    
    // MARK: - Reply Preview
    
    private func replyPreview(for reply: Message) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.blue)
                .frame(width: 2)
                .padding(.vertical, 2)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(reply.senderDisplayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.blue)
                
                Text(reply.content ?? "")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                withAnimation {
                    viewModel.cancelReply()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .fixedSize(horizontal: false, vertical: true) // Prevents infinite vertical expansion
        .onAppear {
            isInputFocused = true
        }
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(6)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Attach media")
            
            HStack(spacing: 8) {
                TextField("Message…", text: $viewModel.messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .font(.system(.body, design: .rounded))
                    .focused($isInputFocused)
                    .frame(minHeight: 36)
                    .onSubmit {
                        viewModel.sendMessage()
                    }
                
                if !viewModel.messageText.isEmpty {
                    Button {
                        viewModel.sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.blue)
                            .symbolEffect(.bounce, value: viewModel.messages.count)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    // MARK: - Helpers
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        let bottomID = "bottom"
        if animated {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }
    }
}

/// Helper for loading video data from PhotosPicker
struct Movie: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let fileName = received.file.lastPathComponent
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            if FileManager.default.fileExists(atPath: copy.path) {
                try? FileManager.default.removeItem(at: copy)
            }
            
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}
