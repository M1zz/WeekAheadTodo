import SwiftUI
import AppKit

// MARK: - 보고 습관 실천 아이템 모델

struct ReportingHabitItem: Identifiable {
    let id: Int
    let number: String
    let title: String
    let action: String
    let tip: String
    let icon: String
}

// MARK: - 보고 습관 View

/// 야근 없이 인정받는 7가지 보고 습관 실천 도구
struct ReportingHabitsView: View {
    @EnvironmentObject var notificationService: NotificationService

    // 오늘 날짜 기반 체크 상태 (날짜 바뀌면 자동 초기화)
    @AppStorage("reportingHabitsCheckDate") private var checkDate: String = ""
    @AppStorage("reportingHabitsCheckedItems") private var checkedItemsData: Data = Data()

    @State private var checkedItems: Set<Int> = []
    @State private var showingTemplateSheet = false
    @State private var selectedTemplate: ReportTemplate?
    @State private var psarProblem = ""
    @State private var psarSolution = ""
    @State private var psarAction = ""
    @State private var psarRecommend = ""
    @State private var psarCopied = false
    @State private var copiedTemplateId: String?

    private let habits: [ReportingHabitItem] = [
        ReportingHabitItem(id: 1, number: "01", title: "결론 먼저 말하기",
                           action: "다음 보고 때 첫 문장을 결론으로 시작한다",
                           tip: "보고 전 1분, 핵심 한 줄 써두기",
                           icon: "text.alignleft"),
        ReportingHabitItem(id: 2, number: "02", title: "선제적 착수 보고",
                           action: "업무 받은 후 1시간 내 착수 메시지 보낸다",
                           tip: "태스크 추가 시 알림 예약 기능 활용",
                           icon: "arrow.up.circle.fill"),
        ReportingHabitItem(id: 3, number: "03", title: "수치 변환 연습",
                           action: "형용사/부사를 숫자로 바꾸어 말한다",
                           tip: "초안에서 '많이/약간/빨리' 단어 검색",
                           icon: "number.circle.fill"),
        ReportingHabitItem(id: 4, number: "04", title: "문제+해결안 세트",
                           action: "문제 보고 시 반드시 대안 1개 이상 준비",
                           tip: "아래 PSAR 메모로 빠르게 정리",
                           icon: "exclamationmark.triangle.fill"),
        ReportingHabitItem(id: 5, number: "05", title: "주간 루틴 실행",
                           action: "월/수/금 간단 보고 루틴 실행",
                           tip: "설정에서 루틴 알림 켜두기",
                           icon: "calendar.badge.checkmark"),
        ReportingHabitItem(id: 6, number: "06", title: "80% 완료 시점에 공유",
                           action: "100% 완성 전 초안을 먼저 공유한다",
                           tip: "\"아직 완성은 아닌데…\" 한 마디로 시작",
                           icon: "chart.pie.fill"),
        ReportingHabitItem(id: 7, number: "07", title: "보고 후 피드백 요청",
                           action: "보고 후 '개선할 점 있으면 알려주세요' 추가",
                           tip: "마지막 문장 템플릿 저장해두기",
                           icon: "bubble.left.and.bubble.right.fill")
    ]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // 헤더
                headerSection

                Divider()

                // 오늘의 실천 체크리스트
                checklistSection

                Divider()

                // 보고 템플릿
                templateSection

                Divider()

                // PSAR 문제 메모
                psarSection
            }
            .padding(28)
        }
        .onAppear { loadCheckedItems() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "star.circle.fill")
                    .font(.title)
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("보고 습관")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("야근 없이, 인정받으며, 지속 가능하게 일하기")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.callout)
                Text("오늘 완료: \(checkedItems.count) / 7")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(checkedItems.count == 7 ? .green : .secondary)

                if checkedItems.count == 7 {
                    Text("완벽한 하루!")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
        }
    }

    // MARK: - 체크리스트

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘의 실천 체크리스트")
                .font(.title3)
                .fontWeight(.semibold)

            Text("매일 자정에 초기화됩니다")
                .font(.callout)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                ForEach(habits) { habit in
                    HabitCheckRow(
                        habit: habit,
                        isChecked: checkedItems.contains(habit.id),
                        onToggle: { toggleItem(habit.id) }
                    )
                }
            }
        }
    }

    // MARK: - 보고 템플릿

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("보고 템플릿 — 복사해서 바로 사용")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 10) {
                ForEach(ReportTemplate.allTemplates) { template in
                    TemplateCard(
                        template: template,
                        isCopied: copiedTemplateId == template.id,
                        onCopy: {
                            copyToClipboard(template.body)
                            withAnimation {
                                copiedTemplateId = template.id
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { copiedTemplateId = nil }
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - PSAR 메모

    private var psarSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PSAR 문제 메모")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    generateAndCopyPSAR()
                } label: {
                    Label(psarCopied ? "복사됨!" : "보고문 복사", systemImage: psarCopied ? "checkmark" : "doc.on.doc")
                        .font(.callout)
                }
                .buttonStyle(.borderedProminent)
                .tint(psarCopied ? .green : .blue)
                .disabled(psarProblem.isEmpty)
            }

            Text("문제 보고 시 '문제+해결안 세트'를 빠르게 작성하세요")
                .font(.callout)
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                PSARField(label: "P  문제 상황", placeholder: "어떤 문제가 발생했나요? (수치 포함)", text: $psarProblem, color: .red)
                PSARField(label: "S  해결 방안", placeholder: "가능한 대안 1~2개를 나열하세요", text: $psarSolution, color: .orange)
                PSARField(label: "A  취할 행동", placeholder: "구체적으로 무엇을 할 건지", text: $psarAction, color: .blue)
                PSARField(label: "R  권고 사항", placeholder: "추천 옵션과 이유 (결론 먼저!)", text: $psarRecommend, color: .green)
            }

            if !psarProblem.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("미리보기")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text(buildPSARText())
                        .font(.callout)
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Logic

    private func toggleItem(_ id: Int) {
        if checkedItems.contains(id) {
            checkedItems.remove(id)
        } else {
            checkedItems.insert(id)
        }
        saveCheckedItems()
    }

    private func loadCheckedItems() {
        let today = todayString()
        if checkDate != today {
            // 날짜가 바뀌었으면 초기화
            checkedItems = []
            checkDate = today
            saveCheckedItems()
        } else {
            if let ids = try? JSONDecoder().decode(Set<Int>.self, from: checkedItemsData) {
                checkedItems = ids
            }
        }
    }

    private func saveCheckedItems() {
        if let data = try? JSONEncoder().encode(checkedItems) {
            checkedItemsData = data
        }
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func generateAndCopyPSAR() {
        let text = buildPSARText()
        copyToClipboard(text)
        withAnimation { psarCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { psarCopied = false }
        }
    }

    private func buildPSARText() -> String {
        var lines: [String] = []
        if !psarProblem.isEmpty { lines.append("【문제】\(psarProblem)") }
        if !psarSolution.isEmpty { lines.append("【해결안】\(psarSolution)") }
        if !psarAction.isEmpty { lines.append("【행동】\(psarAction)") }
        if !psarRecommend.isEmpty { lines.append("【권고】\(psarRecommend)") }
        return lines.joined(separator: "\n")
    }
}

// MARK: - HabitCheckRow

private struct HabitCheckRow: View {
    let habit: ReportingHabitItem
    let isChecked: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // 체크 아이콘
                ZStack {
                    Circle()
                        .fill(isChecked ? Color.green : Color(NSColor.controlBackgroundColor))
                        .frame(width: 32, height: 32)
                    Image(systemName: isChecked ? "checkmark" : habit.icon)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(isChecked ? .white : .secondary)
                }

                // 번호 + 내용
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(habit.number)
                            .font(.callout)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .frame(width: 22, alignment: .leading)
                        Text(habit.title)
                            .font(.body)
                            .fontWeight(.semibold)
                            .strikethrough(isChecked, color: .secondary)
                            .foregroundColor(isChecked ? .secondary : .primary)
                    }
                    Text(habit.action)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                    Text("팁: \(habit.tip)")
                        .font(.callout)
                        .foregroundColor(.blue.opacity(0.8))
                        .padding(.leading, 28)
                }

                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isChecked ? Color.green.opacity(0.08) : Color(NSColor.controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 보고 템플릿 모델

struct ReportTemplate: Identifiable {
    let id: String
    let icon: String
    let title: String
    let color: Color
    let body: String

    static let allTemplates: [ReportTemplate] = [
        ReportTemplate(
            id: "start",
            icon: "arrow.up.circle.fill",
            title: "착수 보고",
            color: .blue,
            body: "[업무명] 착수 보고드립니다.\n\n현재 상황: [현황]\n예상 완료: [날짜]\n\n진행하면서 중간 공유 드리겠습니다."
        ),
        ReportTemplate(
            id: "progress",
            icon: "chart.line.uptrend.xyaxis",
            title: "중간 진행 보고 (80% 공유)",
            color: .orange,
            body: "[업무명] 진행 현황 공유드립니다.\n\n아직 완성은 아닌데, 현재까지 작업한 내용 먼저 공유드립니다.\n\n완료: [완료 내용]\n진행 중: [진행 중인 것]\n예상 완료: [날짜]\n\n피드백 주시면 반영하겠습니다."
        ),
        ReportTemplate(
            id: "complete",
            icon: "checkmark.circle.fill",
            title: "완료 보고",
            color: .green,
            body: "[업무명] 완료 보고드립니다.\n\n결과: [결과 요약]\n주요 성과: [수치/결과]\n\n개선할 점 있으시면 알려주세요."
        ),
        ReportTemplate(
            id: "issue",
            icon: "exclamationmark.triangle.fill",
            title: "이슈 보고 (문제+해결안)",
            color: .red,
            body: "[업무명] 관련 이슈 보고드립니다.\n\n결론: [권고하는 해결안 먼저]\n\n문제: [상황 + 수치]\n원인: [분석]\n해결안:\n  A안) [옵션1] — [장단점]\n  B안) [옵션2] — [장단점]\n권고: A안 추진 권고 (이유: [이유])\n\n검토 후 방향 지시 부탁드립니다."
        )
    ]
}

// MARK: - TemplateCard

private struct TemplateCard: View {
    let template: ReportTemplate
    let isCopied: Bool
    let onCopy: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더 (항상 표시)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: template.icon)
                        .font(.title3)
                        .foregroundColor(template.color)
                        .frame(width: 28)

                    Text(template.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // 본문 (펼쳐질 때 표시)
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 10) {
                    Text(template.body)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Spacer()
                        Button {
                            onCopy()
                        } label: {
                            Label(isCopied ? "클립보드에 복사됨!" : "복사", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isCopied ? .green : template.color)
                    }
                }
                .padding(16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(template.color.opacity(isExpanded ? 0.4 : 0.15), lineWidth: 1)
        )
    }
}

// MARK: - PSARField

private struct PSARField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 4, height: 18)
                Text(label)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.callout)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
    }
}
