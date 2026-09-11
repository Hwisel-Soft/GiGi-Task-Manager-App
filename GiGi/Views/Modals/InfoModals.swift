import SwiftUI

struct SiriInfoModal: View {
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("🎙")
                        .font(.title2)
                        .frame(width: 48, height: 48)
                        .background(Color(hex: "#FCE4EC"))
                        .clipShape(Circle())
                }

                Text("Siri Shortcut")
                    .font(.title3.weight(.heavy))
                    .foregroundColor(C.text)
                    .tracking(-0.4)

                Text("Tapping Set up opens iOS Shortcuts where you record a custom phrase — e.g. \"Hey Siri, add task.\" From then on, speaking that phrase creates an Unscheduled task directly in GiGi without opening the app.")
                    .font(.callout)
                    .foregroundColor(C.sub)
                    .lineSpacing(4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("EXAMPLE")
                        .font(.caption2.bold())
                        .foregroundColor(C.primary)
                        .tracking(0.5)
                    Text("\"Hey Siri, add task — send invoice to client\"")
                        .font(.callout)
                        .italic()
                        .foregroundColor(C.text)
                    Text("→ Creates task in GiGi, Medium priority")
                        .font(.caption)
                        .foregroundColor(C.muted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(C.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Spacer()

                Button { store.showSiriInfo = false } label: {
                    Text("Got it")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(C.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(C.bg)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
        .presentationBackground(C.bg)
    }
}

struct MicInfoModal: View {
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    Circle().fill(C.primaryLight).frame(width: 48, height: 48)
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .foregroundColor(C.primary)
                }

                Text("Voice Input")
                    .font(.title3.weight(.heavy))
                    .foregroundColor(C.text)
                    .tracking(-0.4)

                Text("Tapping the mic uses on-device speech recognition to transcribe your task title — no network required. Just speak naturally; punctuation is handled automatically.")
                    .font(.callout)
                    .foregroundColor(C.sub)
                    .lineSpacing(4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("EXAMPLE")
                        .font(.caption2.bold())
                        .foregroundColor(C.primary)
                        .tracking(0.5)
                    Text("🎙 \"Send invoice to Acme by Friday\"")
                        .font(.callout)
                        .italic()
                        .foregroundColor(C.text)
                    Text("→ Title filled in, ready to set priority")
                        .font(.caption)
                        .foregroundColor(C.muted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(C.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Spacer()

                Button { store.showMicInfo = false } label: {
                    Text("Got it")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(C.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(C.bg)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
        .presentationBackground(C.bg)
    }
}
