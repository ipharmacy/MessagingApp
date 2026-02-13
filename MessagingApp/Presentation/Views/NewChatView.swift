import SwiftUI
import Contacts

/// A sheet for selecting a contact to start a new conversation.
///
/// Loads contacts from the `ContactService` (real or mock, depending on permission).
/// Shows a permission warning banner when access has been denied.
struct NewChatView: View {
    @ObservedObject var contactService: ContactService
    @Environment(\.dismiss) private var dismiss
    
    /// Callback invoked when a contact is selected, passing the full name.
    var onSelectContact: (String) -> Void
    
    @State private var searchText: String = ""
    
    /// Contacts filtered by the search text.
    private var filteredContacts: [CNContact] {
        if searchText.isEmpty {
            return contactService.contacts
        }
        return contactService.contacts.filter { contact in
            let fullName = ContactService.fullName(for: contact)
            return fullName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Permission warning
                if contactService.permissionDenied {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Contacts Access Denied")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text("Using sample contacts. Enable access in Settings to use your real contacts.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityIdentifier("permissionWarning")
                }
                
                // Contact list
                Section {
                    ForEach(filteredContacts, id: \.identifier) { contact in
                        Button {
                            let fullName = ContactService.fullName(for: contact)
                            onSelectContact(fullName)
                        } label: {
                            contactRow(for: contact)
                        }
                    }
                } header: {
                    if !filteredContacts.isEmpty {
                        Text("\(filteredContacts.count) contacts")
                    }
                }
                
                // Empty state
                if filteredContacts.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Search contacts")
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancelNewChat")
                }
            }
            .onAppear {
                contactService.requestAccess()
            }
        }
    }
    
    // MARK: - Contact Row
    
    private func contactRow(for contact: CNContact) -> some View {
        HStack(spacing: 14) {
            // Avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: avatarColors(for: contact),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Text(contactInitials(for: contact))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(ContactService.fullName(for: contact))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let phone = contact.phoneNumbers.first?.value.stringValue {
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Contact: \(ContactService.fullName(for: contact))")
        .accessibilityIdentifier("contactRow_\(contact.identifier)")
    }
    
    // MARK: - Helpers
    
    private func contactInitials(for contact: CNContact) -> String {
        let first = contact.givenName.first.map(String.init) ?? ""
        let last = contact.familyName.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
    
    private func avatarColors(for contact: CNContact) -> [Color] {
        let name = ContactService.fullName(for: contact)
        let hash = abs(name.hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = Double((hash / 360) % 360) / 360.0
        return [
            Color(hue: hue1, saturation: 0.55, brightness: 0.8),
            Color(hue: hue2, saturation: 0.65, brightness: 0.7)
        ]
    }
}
