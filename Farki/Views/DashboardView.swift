import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared

    private var inkColor: Color {
        themeManager.inkColor
    }

    private var mutedColor: Color {
        themeManager.mutedColor
    }

    init(viewModel: DashboardViewModel, themeManager: ThemeManager = .shared) {
        self.viewModel = viewModel
        self.themeManager = themeManager
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Top Header spacing placeholder (Persistent header is pinned at zIndex 10)
                Color.clear
                    .frame(height: 24)
                    .padding(.top, 14)
                    .padding(.bottom, 22)

                // High-Tech Performance Overview & Analytics (Matching Reference Image)
                PerformanceOverviewView(themeManager: themeManager)
                    .padding(.bottom, 120) // Clearance for bottom menu
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            viewModel.refreshData()
        }
    }
}
