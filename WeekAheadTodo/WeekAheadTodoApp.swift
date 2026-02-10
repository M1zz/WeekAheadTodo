import SwiftUI
import SwiftData
import Foundation

@main
struct WeekAheadTodoApp: App {
    let modelContainer: ModelContainer

    init() {

        let schema = Schema([
            ApprovedPattern.self,
        ])

        // Try persistent storage first (WITHOUT CloudKit sync)
        let persistentConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // Disable CloudKit integration for SwiftData
        )

        var container: ModelContainer?

        // First attempt: Normal persistent storage
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [persistentConfig]
            )
        } catch {

            // Delete old SwiftData files
            Self.deleteSwiftDataStore()

            // Second attempt: Try persistent again after deletion
            do {
                container = try ModelContainer(
                    for: schema,
                    configurations: [persistentConfig]
                )
            } catch {

                // Third attempt: Fall back to in-memory storage
                do {
                    let inMemoryConfig = ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: true,
                        cloudKitDatabase: .none
                    )
                    container = try ModelContainer(
                        for: schema,
                        configurations: [inMemoryConfig]
                    )
                } catch {

                    // Last resort: Don't set container here, will be handled below
                    container = nil
                }
            }
        }

        // Use the container we managed to create, or create a minimal one
        if let container = container {
            self.modelContainer = container
        } else {
            do {
                self.modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: true,
                        cloudKitDatabase: .none
                    )]
                )
            } catch {
                // Absolute last resort - create simplest possible container
                self.modelContainer = (try? ModelContainer(for: schema)) ?? {
                    fatalError("Cannot initialize any ModelContainer. SwiftData is completely broken.")
                }()
            }
        }

    }

    static func deleteSwiftDataStore() {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return
        }

        // SwiftData stores are typically in Application Support/default.store
        let storeURL = appSupport.appendingPathComponent("default.store")

        do {
            if FileManager.default.fileExists(atPath: storeURL.path) {
                try FileManager.default.removeItem(at: storeURL)
            }

            // Also delete related files
            let storeSHM = appSupport.appendingPathComponent("default.store-shm")
            let storeWAL = appSupport.appendingPathComponent("default.store-wal")

            for url in [storeSHM, storeWAL] {
                if FileManager.default.fileExists(atPath: url.path) {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        } catch {
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandMenu("태스크") {
                Button("빠른 추가...") {
                    NotificationCenter.default.post(name: .showQuickAdd, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showQuickAdd = Notification.Name("showQuickAdd")
}

// Root View with font scaling
struct RootView: View {
    @AppStorage("appFontSizeLevel") private var appFontSizeLevel: Int = 1

    var body: some View {
        ContentView()
            .applyDynamicFont()
            .id(appFontSizeLevel) // 폰트 크기 변경 시 모든 텍스트가 즉시 반응
    }
}
