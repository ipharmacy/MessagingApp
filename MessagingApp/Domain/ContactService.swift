import Foundation
import Contacts
import Combine

/// Specific errors that can occur during contact fetching.
enum ContactError: LocalizedError {
    case permissionDenied
    case fetchFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Contact access denied. Please enable it in Settings."
        case .fetchFailed(let error):
            return "Failed to fetch contacts: \(error.localizedDescription)"
        }
    }
}

/// Manages access to the device's Contacts framework.
///
/// Handles permission requests, real contact fetching, and provides mock
/// fallback data when permission is denied or fetching fails.
class ContactService: ObservableObject {
    
    // MARK: - Published State
    
    /// The list of available contacts (real or mock).
    @Published var contacts: [CNContact] = []
    
    /// Indicates whether access to contacts was denied by the user.
    @Published var permissionDenied: Bool = false
    
    /// A user-facing error message, if any.
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let contactStore = CNContactStore()
    
    // MARK: - Permission & Fetch
    
    /// Requests access to the user's contacts.
    ///
    /// - If granted, fetches real contacts.
    /// - If denied or on error, falls back to mock data so the app remains usable.
    func requestAccess() {
        contactStore.requestAccess(for: .contacts) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.handleError(.fetchFailed(error))
                    return
                }
                
                if granted {
                    self?.permissionDenied = false
                    self?.errorMessage = nil
                    self?.fetchContacts()
                } else {
                    self?.handleError(.permissionDenied)
                }
            }
        }
    }
    
    /// Fetches contacts from the device's address book.
    private func fetchContacts() {
        // Run fetch on a background queue to avoid blocking the main thread.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactImageDataAvailableKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)
            request.sortOrder = .givenName
            
            do {
                var fetched: [CNContact] = []
                try self.contactStore.enumerateContacts(with: request) { contact, _ in
                    // Only include contacts that have a name.
                    if !contact.givenName.isEmpty || !contact.familyName.isEmpty {
                        fetched.append(contact)
                    }
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.contacts = fetched
                    
                    // If the user has zero contacts, provide mock data for demonstration.
                    if self.contacts.isEmpty {
                        self.loadMockContacts()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.handleError(.fetchFailed(error))
                }
            }
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: ContactError) {
        self.errorMessage = error.localizedDescription
        self.permissionDenied = true
        self.loadMockContacts()
    }
    
    // MARK: - Mock Data
    
    /// Provides a realistic set of mock contacts when real data is unavailable.
    private func loadMockContacts() {
        let mockData: [(String, String)] = [
            ("Alice", "Johnson"),
            ("Bob", "Smith"),
            ("Charlie", "Brown"),
            ("Diana", "Ross"),
            ("Eve", "Martinez"),
            ("Frank", "Wilson"),
            ("Grace", "Lee"),
            ("Henry", "Taylor")
        ]
        
        contacts = mockData.map { first, last in
            let contact = CNMutableContact()
            contact.givenName = first
            contact.familyName = last
            contact.phoneNumbers = [
                CNLabeledValue(label: CNLabelPhoneNumberMobile,
                               value: CNPhoneNumber(stringValue: "+1 555-\(Int.random(in: 1000...9999))"))
            ]
            return contact as CNContact
        }
    }
    
    /// Returns the full name for a contact.
    static func fullName(for contact: CNContact) -> String {
        "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
    }
}
