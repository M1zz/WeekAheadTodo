import WeekAheadShared
import SwiftUI

// MARK: - Wiki View (메인 컨테이너)

struct WikiView: View {
    @EnvironmentObject var wikiViewModel: WikiViewModel

    var body: some View {
        HSplitView {
            WikiSidebarView()
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 350)

            WikiContentView()
                .frame(minWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
