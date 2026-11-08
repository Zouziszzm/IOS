import SwiftUI

struct BottomNavBarView: View {
    @ObservedObject var navVM: NavigationViewModel
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared

    private var itemColor: Color {
        themeManager.inkColor
    }

    var body: some View {
        VStack(spacing: 0) {
            // Subtle frosted glass hairline top divider
            Rectangle()
                .fill(themeManager.hairlineColor)
                .frame(height: 0.5)

            HStack(spacing: 0) {
                ForEach(NavMenuItem.allCases) { item in
                    let isActive = (!navVM.isMenuOpen && navVM.activePage == .tab(item))

                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            navVM.selectItem(item)
                        }
                    } label: {
                        Text(item.english)
                            .font(.english(size: 14, weight: isActive ? .bold : .medium))
                            .foregroundColor(itemColor)
                            .opacity(isActive ? 1.0 : 0.5)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .safeAreaPadding(.bottom)
        .background {
            ZStack {
                // Reduced blur intensity and increased transparency
                VisualEffectBlur(
                    blurStyle: themeManager.activeTheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight,
                    intensity: 0.85
                )

                // Minimal translucent tint so underlying content remains clearly visible
                (themeManager.activeTheme == .dark ? Color.black.opacity(0.08) : Color.white.opacity(0.12))
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}
