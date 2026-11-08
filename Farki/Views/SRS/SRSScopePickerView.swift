import SwiftUI

struct SRSScopePickerView: View {
    @ObservedObject var viewModel: SRSViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var settingsManager = AppSettingsManager.shared

    @State private var pickerMode: PickerMode = .single
    @State private var selectedChapter: Int = 1

    private enum PickerMode: String, CaseIterable {
        case single = "単一課"
        case multi = "複数課"
        case presets = "プリセット"

        var romaji: String {
            switch self {
            case .single: return "Tan'itsu Ka"
            case .multi: return "Fukusuu Ka"
            case .presets: return "Purisetto"
            }
        }

        var english: String {
            switch self {
            case .single: return "Single Chapter"
            case .multi: return "Multiple Chapters"
            case .presets: return "Presets"
            }
        }
    }

    private var inkColor: Color { themeManager.inkColor }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.canvasColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // All Chapters Default Option
                        allChaptersCard

                        // Mode Segmented Picker
                        VStack(spacing: 6) {
                            Picker("Scope Mode", selection: $pickerMode) {
                                ForEach(PickerMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 16)

                            if settingsManager.showAppRomaji || settingsManager.showAppEnglishMeaning {
                                VStack(spacing: 2) {
                                    if settingsManager.showAppRomaji {
                                        Text(pickerMode.romaji)
                                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                                            .foregroundColor(themeManager.mutedColor)
                                    }
                                    if settingsManager.showAppEnglishMeaning {
                                        Text(pickerMode.english)
                                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                                            .foregroundColor(themeManager.mutedColor.opacity(0.85))
                                    }
                                }
                            }
                        }

                        // Mode Content
                        switch pickerMode {
                        case .single:
                            singleChapterSection
                        case .multi:
                            multiChapterSection
                        case .presets:
                            presetsSection
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("学習範囲")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(inkColor)

                        if settingsManager.showAppRomaji {
                            Text("Gakushuu Hani")
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .foregroundColor(themeManager.mutedColor)
                        }

                        if settingsManager.showAppEnglishMeaning {
                            Text("Study Scope")
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .foregroundColor(themeManager.mutedColor.opacity(0.85))
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
            }
        }
    }

    // MARK: - All Chapters Card
    private var allChaptersCard: some View {
        let allCounts = viewModel.countsForScope(.all)
        let isSelected = (viewModel.activeScope == .all)

        return Button(action: {
            viewModel.activeScope = .all
            dismiss()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: "globe.asia.australia.fill")
                            .foregroundColor(Color(hex: "#3B82F6"))
                        Text("すべての課")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(inkColor)
                    }

                    if settingsManager.showAppRomaji {
                        Text("Subete no Ka")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(themeManager.mutedColor)
                    }

                    if settingsManager.showAppEnglishMeaning {
                        Text("All Chapters")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(themeManager.mutedColor.opacity(0.85))
                    }

                    Text("全章の単語を対象にして学習します")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.colorScheme == .dark ? Color(hex: "#94A3B8") : Color(hex: "#64748B"))
                        .padding(.top, 2)
                }

                Spacer()

                // Live counts pill
                liveCountsBadge(counts: allCounts)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#3B82F6"))
                        .font(.system(size: 20))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(themeManager.colorScheme == .dark ? Color(hex: "#1E222B") : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color(hex: "#3B82F6") : (themeManager.colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)), lineWidth: isSelected ? 2 : 1)
            )
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Single Chapter Selection
    private var singleChapterSection: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.availableChapters, id: \.self) { ch in
                let chScope = SRSScope.chapter(ch)
                let counts = viewModel.countsForScope(chScope)
                let isSelected: Bool = {
                    if case .chapter(let activeCh) = viewModel.activeScope {
                        return activeCh == ch
                    }
                    return false
                }()

                Button(action: {
                    viewModel.activeScope = chScope
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("第\(ch)課")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(inkColor)

                            if settingsManager.showAppRomaji {
                                Text("Dai \(ch) Ka")
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundColor(themeManager.mutedColor)
                            }

                            if settingsManager.showAppEnglishMeaning {
                                Text("Chapter \(ch)")
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundColor(themeManager.mutedColor.opacity(0.85))
                            }
                        }

                        Spacer()

                        liveCountsBadge(counts: counts)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "#3B82F6"))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(themeManager.colorScheme == .dark ? Color(hex: "#1E222B") : Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color(hex: "#3B82F6") : (themeManager.colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)), lineWidth: isSelected ? 1.5 : 1)
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Multi-Chapter Selection
    private var multiChapterSection: some View {
        VStack(spacing: 16) {
            // Apply & Save Selection Buttons
            HStack(spacing: 12) {
                Button(action: {
                    guard !viewModel.selectedMultiChapters.isEmpty else { return }
                    viewModel.activeScope = .selected(Array(viewModel.selectedMultiChapters))
                    dismiss()
                }) {
                    Text("選択した章を学習 (\(viewModel.selectedMultiChapters.count)課)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color(hex: "#3B82F6"))
                        .cornerRadius(12)
                }

                Button(action: {
                    viewModel.isPresetSavePresented = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("保存")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#3B82F6"))
                    .frame(width: 90, height: 44)
                    .background(Color(hex: "#3B82F6").opacity(0.12))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)

            // Chapter Grid Chips
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 75), spacing: 8)], spacing: 8) {
                ForEach(viewModel.availableChapters, id: \.self) { ch in
                    let isChecked = viewModel.selectedMultiChapters.contains(ch)
                    Button(action: {
                        if isChecked {
                            if viewModel.selectedMultiChapters.count > 1 {
                                viewModel.selectedMultiChapters.remove(ch)
                            }
                        } else {
                            viewModel.selectedMultiChapters.insert(ch)
                        }
                    }) {
                        Text("第\(ch)課")
                            .font(.system(size: 13, weight: isChecked ? .bold : .medium))
                            .foregroundColor(isChecked ? .white : inkColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isChecked ? Color(hex: "#3B82F6") : (themeManager.colorScheme == .dark ? Color(hex: "#1E222B") : Color.white))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(isChecked ? Color(hex: "#3B82F6") : Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Presets Section
    private var presetsSection: some View {
        VStack(spacing: 12) {
            if viewModel.presets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 32))
                        .foregroundColor(Color.gray.opacity(0.5))
                    Text("保存されたプリセットはありません")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text("「複数課」タブで章を選んで「保存」してください")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 40)
            } else {
                ForEach(viewModel.presets) { preset in
                    let presetScope = SRSScope.preset(id: preset.id, name: preset.name, chapters: preset.chapters)
                    let counts = viewModel.countsForScope(presetScope)
                    let isSelected: Bool = {
                        if case .preset(let id, _, _) = viewModel.activeScope {
                            return id == preset.id
                        }
                        return false
                    }()

                    HStack {
                        Button(action: {
                            viewModel.activeScope = presetScope
                            dismiss()
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(inkColor)

                                Text("Chapters: \(preset.chapters.map(String.init).joined(separator: ", "))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            liveCountsBadge(counts: counts)
                        }

                        Button(action: {
                            viewModel.deletePreset(id: preset.id)
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#EF4444"))
                                .padding(8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(themeManager.colorScheme == .dark ? Color(hex: "#1E222B") : Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color(hex: "#3B82F6") : Color.gray.opacity(0.15), lineWidth: isSelected ? 1.5 : 1)
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Live Counts Pill Badge
    private func liveCountsBadge(counts: SRSQueueCounts) -> some View {
        HStack(spacing: 6) {
            // New
            HStack(spacing: 2) {
                Circle().fill(Color(hex: "#3B82F6")).frame(width: 6, height: 6)
                Text("\(counts.newCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#3B82F6"))
            }

            // Learning
            HStack(spacing: 2) {
                Circle().fill(Color(hex: "#F59E0B")).frame(width: 6, height: 6)
                Text("\(counts.learningCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#F59E0B"))
            }

            // Due
            HStack(spacing: 2) {
                Circle().fill(Color(hex: "#10B981")).frame(width: 6, height: 6)
                Text("\(counts.reviewCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#10B981"))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(themeManager.colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
        )
    }
}
