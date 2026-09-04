import SwiftUI

struct NudgeSheet: View {
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }

    private var task: GTask? { store.selectedTask() }
    private var nudgeMessage: String {
        guard let t = task else { return "" }
        let notePart: String
        if let note = t.waitingNote, !note.isEmpty {
            let trimmed = note.trimmingCharacters(in: .whitespaces)
            let punctuated = trimmed.last.map { ".!?".contains($0) } == true ? trimmed : "\(trimmed)."
            notePart = " \(punctuated)"
        } else {
            notePart = ""
        }
        return "Hey \(t.waitingOn ?? "there"), just following up on \"\(t.title)\".\(notePart) Thanks!"
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                if let t = task {
                    Text("Following up with \(t.waitingOn ?? "someone") about:")
                        .font(.system(size: 14))
                        .foregroundColor(C.sub)

                    Text(t.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(C.text)

                    // Pre-filled message
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MESSAGE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(C.muted)
                            .tracking(0.8)
                        Text(nudgeMessage)
                            .font(.system(size: 14))
                            .foregroundColor(C.text)
                            .lineSpacing(4)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(C.bg)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(C.border, lineWidth: 1.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Action buttons
                    VStack(spacing: 10) {
                        nudgeButton(label: "💬 Messages", bg: C.green) {
                            let encoded = nudgeMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            if let url = URL(string: "sms:?body=\(encoded)") {
                                UIApplication.shared.open(url)
                            }
                            store.showNudgeSheet = false
                        }
                        nudgeButton(label: "✉ Mail", bg: C.primary) {
                            let subject = "Following up: \(t.title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            let body = nudgeMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            if let url = URL(string: "mailto:?subject=\(subject)&body=\(body)") {
                                UIApplication.shared.open(url)
                            }
                            store.showNudgeSheet = false
                        }
                        nudgeButton(label: "📋 Copy", bg: C.card, fgColor: C.text, bordered: true) {
                            UIPasteboard.general.string = nudgeMessage
                            store.showNudgeSheet = false
                        }
                    }
                }
                Spacer()
            }
            .padding(24)
            .background(C.bg)
            .navigationTitle("Nudge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.showNudgeSheet = false }
                        .foregroundColor(C.primary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(C.bg)
    }

    @ViewBuilder
    func nudgeButton(label: String, bg: Color, fgColor: Color = .white, bordered: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(fgColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(bg)
                .overlay(bordered ? RoundedRectangle(cornerRadius: 16).stroke(C.border, lineWidth: 1.5) : nil)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
