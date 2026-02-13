import SwiftUI
import CoreData

/// The main entry point for the Messaging App.
///
/// Sets up the dependency graph (persistence → repository → services → view models)
/// and injects them into the root view.
@main
struct MessagingAppApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            let context = persistenceController.container.viewContext
            let repository = ConversationRepository(context: context)
            let contactService = ContactService()
            let chatService = ChatService(repository: repository)
            let viewModel = ConversationListViewModel(
                repository: repository,
                contactService: contactService
            )
            
            ConversationListView(
                viewModel: viewModel,
                repository: repository,
                chatService: chatService
            )
            .environment(\.managedObjectContext, context)
        }
    }
}
