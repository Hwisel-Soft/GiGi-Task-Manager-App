import SwiftUI

struct PriorityPickerView: View {
    @Binding var selected: Priority
    let C: GColors

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Priority.allCases, id: \.self) { p in
                Button {
                    selected = p
                } label: {
                    Text(p.label)
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundColor(selected == p ? C.priorityColor(p) : C.muted)
                        .background(selected == p ? C.priorityLightColor(p) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected == p ? C.priorityColor(p) : C.border, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
