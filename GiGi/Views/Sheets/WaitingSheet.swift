import SwiftUI

struct WaitingSheet: View {
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    fieldLabel("Waiting on")
                    TextField("Person's name…", text: $store.waitForm.name)
                        .font(.system(size: 15))
                        .foregroundColor(C.text)
                        .tint(C.purple)
                        .padding(14)
                        .background(C.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(store.waitForm.name.isEmpty ? C.border : C.purple, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    fieldLabel("What you need")
                    TextField("Describe what you're waiting for…", text: $store.waitForm.note, axis: .vertical)
                        .font(.system(size: 14))
                        .foregroundColor(C.text)
                        .tint(C.purple)
                        .lineLimit(2...4)
                        .padding(14)
                        .background(C.card)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(C.border, lineWidth: 1.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    fieldLabel("Follow up on (optional)")
                    HStack {
                        TextField("YYYY-MM-DD", text: $store.waitForm.followUpDate)
                            .font(.system(size: 14))
                            .foregroundColor(C.text)
                            .tint(C.purple)
                            .keyboardType(.numbersAndPunctuation)
                        if !store.waitForm.followUpDate.isEmpty {
                            Button { store.waitForm.followUpDate = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(C.muted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(C.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(C.border, lineWidth: 1.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        if let id = store.selectedTaskId { store.moveToWaiting(id) }
                        else { store.showWaitingSheet = false }
                    } label: {
                        Text("Park in Waiting")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(C.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(24)
            }
            .background(C.bg)
            .navigationTitle("Mark as Waiting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.showWaitingSheet = false }
                        .foregroundColor(C.purple)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(C.bg)
    }

    @ViewBuilder func fieldLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(C.muted)
            .tracking(0.8)
    }
}
