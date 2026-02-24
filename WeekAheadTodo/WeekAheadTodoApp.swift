import SwiftUI
import SwiftData
import Foundation

@main
struct WeekAheadTodoApp: App {
    let modelContainer: ModelContainer

    init() {

        let schema = Schema([
            ApprovedPattern.self,
            TaskItem.self,
            ProjectItem.self,
        ])

        // SwiftData 로컬 저장 (CloudKit 동기화는 기존 수동 CKRecord 방식 사용)
        let persistentConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        var container: ModelContainer?

        // First attempt: Normal persistent storage with CloudKit sync
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [persistentConfig]
            )
        } catch {
            print("❌ [ModelContainer] 첫 번째 시도 실패: \(error)")

            // Delete old SwiftData files
            Self.deleteSwiftDataStore()

            // Second attempt: Try persistent again after deletion
            do {
                container = try ModelContainer(
                    for: schema,
                    configurations: [persistentConfig]
                )
            } catch {
                print("❌ [ModelContainer] 두 번째 시도 실패: \(error)")

                // Third attempt: Fall back to in-memory storage (CloudKit 없이)
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
                    print("⚠️ [ModelContainer] 인메모리 모드로 폴백 (동기화 불가)")
                } catch {
                    print("❌ [ModelContainer] 인메모리 시도도 실패: \(error)")
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
