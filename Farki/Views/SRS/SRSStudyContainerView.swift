import SwiftUI

struct SRSStudyContainerView: View {
    @ObservedObject var viewModel: SRSViewModel
    @ObservedObject var navVM: NavigationViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var settingsManager = AppSettingsManager.shared

    private var canvasColor: Color { themeManager.canvasColor }
    private var inkColor: Color { themeManager.inkColor }
    private var mutedColor: Color { themeManager.mutedColor }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Section 1: Top Section (Timer, Icon Tools, Card Number & Queue)
                // Padded at top 68pt so it NEVER touches or overlaps the pinned 日本 logo / level text
                topHeaderSection
                    .padding(.top, 68)
                    .padding(.bottom, 24)

                // Section 2: Progress Section (Practice, percentage, SegmentedProgressBar)
                progressSection
                    .padding(.bottom, 22)

                // Section 3: Word Content (Directly on canvas, NO CARD-LIKE RECTANGLE!)
                if let item = viewModel.currentItem {
                    wordDetailsSection(for: item)
                        .id(item.id)
                        .padding(.bottom, 120) // Space above bottom menu
                } else {
                    allCaughtUpView
                        .padding(.bottom, 120)
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            if !navVM.isRenshuuMenuVisible {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                    navVM.isRenshuuMenuVisible = true
                }
            }
        }
        // Modals & Sheets
        .sheet(isPresented: $viewModel.isScopePickerPresented) {
            SRSScopePickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isStatsPresented) {
            SRSStatsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            SRSSettingsView(viewModel: viewModel)
        }
        .alert("プリセットとして保存", isPresented: $viewModel.isPresetSavePresented) {
            TextField("プリセット名 (例: Chapters 1-3)", text: $viewModel.newPresetName)
            Button("保存") {
                viewModel.saveCurrentScopeAsPreset()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("現在の学習範囲を名前をつけて保存します。")
        }
    }

    // MARK: - Section 1: Top Section (Timer, Menu Icons, Card Counter)
    @ViewBuilder
    private var topHeaderSection: some View {
        HStack(alignment: .center) {
            // Left: Timer (Clickable to pause / resume)
            Button {
                viewModel.toggleTimer()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.isTimerPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(viewModel.isTimerPaused ? Color(hex: "#3B82F6") : inkColor)

                    Text(viewModel.formattedSessionTime)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundColor(inkColor)
                        .opacity(viewModel.isTimerPaused ? 0.75 : 1.0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            // Center: Menu Icons beside timer, justified between (Icons only!)
            HStack(spacing: 16) {
                // Undo
                Button {
                    viewModel.undoLastReview()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(inkColor)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Scope Filter
                Button {
                    viewModel.isScopePickerPresented = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(inkColor)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Stats
                Button {
                    viewModel.isStatsPresented = true
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(inkColor)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // SRS Settings
                Button {
                    viewModel.isSettingsPresented = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(inkColor)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Right: Active card number & Total count + SRS Queue Pills
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    if let item = viewModel.currentItem {
                        Rectangle()
                            .fill(item.vocabItem.reviewSquareColor)
                            .frame(width: 8, height: 8)
                    }

                    let totalInQueue = viewModel.currentQueue.count
                    let currentPos = viewModel.currentQueue.isEmpty ? 0 : min(viewModel.currentIndex + 1, totalInQueue)

                    Text("\(currentPos)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(inkColor)

                    Text("/\(viewModel.currentQueue.count)")
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundColor(mutedColor)
                }

                // Live SRS Queue Pills
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Circle().fill(Color(hex: "#3B82F6")).frame(width: 5, height: 5)
                        Text("\(viewModel.queueCounts.newCount)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#3B82F6"))
                    }

                    HStack(spacing: 3) {
                        Circle().fill(Color(hex: "#F59E0B")).frame(width: 5, height: 5)
                        Text("\(viewModel.queueCounts.learningCount)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#F59E0B"))
                    }

                    HStack(spacing: 3) {
                        Circle().fill(Color(hex: "#10B981")).frame(width: 5, height: 5)
                        Text("\(viewModel.queueCounts.reviewCount)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#10B981"))
                    }
                }
            }
        }
    }

    // MARK: - Section 2: Progress Section
    @ViewBuilder
    private var progressSection: some View {
        let total = viewModel.currentQueue.count
        let completed = min(viewModel.currentIndex, total)
        let progress = total > 0 ? Double(completed) / Double(total) : 0.0
        let pct = total > 0 ? Int(round(progress * 100)) : 0

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Practice")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(inkColor)

                    Text("You completed \(completed)/\(total) cards")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(mutedColor)
                }

                Spacer()

                Text(String(format: "%02d%%", pct))
                    .font(.system(size: 24, weight: .regular, design: .monospaced))
                    .foregroundColor(mutedColor)
            }

            SegmentedProgressBar(
                progress: progress,
                totalSegments: 30,
                height: 34
            )
        }
    }

    // MARK: - Section 3: Word Details (Directly on canvas - NO CARD-LIKE CONTAINER)
    @ViewBuilder
    private func wordDetailsSection(for item: SRSQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Chapter Tag & State Badge
            HStack(alignment: .firstTextBaseline) {
                Text("第\(item.vocabItem.chapterNumber)課 • \(item.vocabItem.categoryTag)")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(inkColor)

                Spacer()

                stateBadge(for: item.cardState.state)
            }

            // Interactive Flippable Word (Tap to reveal / flip in place, same as Vocab)
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    viewModel.ensureTimerRunning()
                    viewModel.revealAnswer()
                } label: {
                    ZStack(alignment: .leading) {
                        // Front Side: Japanese Word (36pt bold font)
                        Text(item.vocabItem.kanji ?? item.vocabItem.japanese)
                            .font(.japanese(size: 36, weight: .bold))
                            .foregroundColor(inkColor)
                            .lineLimit(2)
                            .minimumScaleFactor(0.70)
                            .modifier(CardFlipModifier(isFlipped: viewModel.isAnswerRevealed, isBack: false))

                        // Reverse Side: English Meaning (36pt bold font)
                        // If English is disabled in main settings, it remains hidden until revealed through Check Meaning
                        let showEnglish = settingsManager.showAppEnglishMeaning || viewModel.wasCheckedMeaning
                        Text(showEnglish ? item.vocabItem.meaning : "••••••")
                            .font(.english(size: 34, weight: .bold))
                            .foregroundColor(inkColor)
                            .lineLimit(2)
                            .minimumScaleFactor(0.70)
                            .modifier(CardFlipModifier(isFlipped: viewModel.isAnswerRevealed, isBack: true))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 46)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Kana Reading
                Text(item.vocabItem.kana)
                    .font(.japanese(size: 17, weight: .medium))
                    .foregroundColor(Color(hex: "#3B82F6"))

                // Romaji - Respects main settings preference
                if settingsManager.showAppRomaji {
                    Text(item.vocabItem.romaji)
                        .font(.english(size: 15, weight: .medium))
                        .foregroundColor(mutedColor)
                }
            }
            .padding(.bottom, 6)

            // Check & Next Controls (Above bottom menu)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    // Check Meaning Button
                    Button {
                        viewModel.ensureTimerRunning()
                        if !viewModel.isAnswerRevealed {
                            viewModel.checkMeaning()
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: viewModel.wasCheckedMeaning ? "checkmark.circle.fill" : "eye.fill")
                                .font(.system(size: 13, weight: .bold))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.wasCheckedMeaning ? "確認済み・難" : "意味を確認")
                                    .font(.japanese(size: 13, weight: .bold))

                                if settingsManager.showAppEnglishMeaning {
                                    Text(viewModel.wasCheckedMeaning ? "Checked • Hard" : "Check Meaning")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                }
                            }
                        }
                        .foregroundColor(viewModel.wasCheckedMeaning ? Color(hex: "#F59E0B") : canvasColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.wasCheckedMeaning
                                ? Color(hex: "#F59E0B").opacity(0.15)
                                : Color(hex: "#F59E0B")
                        )
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "#F59E0B"), lineWidth: viewModel.wasCheckedMeaning ? 1.2 : 0)
                        )
                    }
                    .buttonStyle(.plain)

                    // Next Button beside Check (shown when revealed)
                    if viewModel.isAnswerRevealed {
                        Button {
                            viewModel.ensureTimerRunning()
                            viewModel.answerCurrentCard(rating: viewModel.wasCheckedMeaning ? .hard : .good)
                        } label: {
                            HStack(spacing: 6) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("次へ")
                                        .font(.system(size: 13, weight: .bold))

                                    if settingsManager.showAppEnglishMeaning {
                                        Text("Next")
                                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    }
                                }

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(Color.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#10B981"))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }

                if viewModel.wasCheckedMeaning {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("※ 意味を確認したため「難しい」として自己評価が記録されます。")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#F59E0B"))

                        if settingsManager.showAppEnglishMeaning {
                            Text("Marked as Hard because meaning was revealed.")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(mutedColor)
                        }
                    }
                } else if !viewModel.isAnswerRevealed {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("※ 意味を確認すると自動的に「難しい」として評価されます。")
                            .font(.system(size: 11))
                            .foregroundColor(mutedColor)

                        if settingsManager.showAppEnglishMeaning {
                            Text("Checking meaning will automatically classify card as Hard.")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(mutedColor.opacity(0.85))
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - State Badge
    @ViewBuilder
    private func stateBadge(for state: CardStateEnum) -> some View {
        let badgeInfo: (text: String, color: Color) = {
            switch state {
            case .new:
                return ("NEW", Color(hex: "#3B82F6"))
            case .learning, .relearning:
                return ("LEARNING", Color(hex: "#F59E0B"))
            case .review:
                return ("REVIEW", Color(hex: "#10B981"))
            }
        }()

        Text(badgeInfo.text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(badgeInfo.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeInfo.color.opacity(0.12))
            .cornerRadius(4)
    }

    // MARK: - All Caught Up Empty State
    private var allCaughtUpView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 30)

            ZStack {
                Circle()
                    .fill(Color(hex: "#10B981").opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(hex: "#10B981"))
            }

            VStack(spacing: 8) {
                Text("本日の復習は完了しました！")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(inkColor)

                Text("選択中の学習範囲「\(viewModel.activeScope.displayName)」には、現在復習するカードはありません。")
                    .font(.system(size: 13))
                    .foregroundColor(mutedColor)
                    .multilineTextAlignment(.center)
            }

            Button {
                viewModel.isScopePickerPresented = true
            } label: {
                Text("他の課を選ぶ (Change Scope)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(canvasColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(inkColor)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }
}
