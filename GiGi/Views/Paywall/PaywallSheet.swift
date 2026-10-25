import SwiftUI
import StoreKit

private struct ProFeature: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

private let proFeatures: [ProFeature] = [
    ProFeature(icon: "hourglass",              text: "Waiting workflow with follow-up dates"),
    ProFeature(icon: "bell.fill",              text: "Morning brief notification"),
    ProFeature(icon: "chart.bar.fill",         text: "Weekly performance stats"),
    ProFeature(icon: "mic.fill",               text: "Siri voice integration"),
    ProFeature(icon: "clock.arrow.circlepath", text: "Task history"),
    ProFeature(icon: "infinity",               text: "Unlimited categories"),
    ProFeature(icon: "star.fill",              text: "All future Pro features"),
]

struct PaywallSheet: View {
    @Environment(AppStore.self) var store
    @Environment(SubscriptionStore.self) var subStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: String = SubscriptionStore.annualId

    private var C: GColors { store.C }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    paywallHeader
                    paywallContent
                }
            }
            .background(C.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                        .foregroundColor(C.primary)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
    }

    var paywallHeader: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1547CC"), Color(hex: "#6B3FD4")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 10) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.white.opacity(0.95))
                Text("GiGi Pro")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text("Get the complete accountability system")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 36)
        }
    }

    var paywallContent: some View {
        VStack(spacing: 24) {
            featureList
            planSelector
            purchaseButton
            if let err = subStore.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            legalFooter
        }
        .padding(20)
    }

    var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(proFeatures) { f in
                HStack(spacing: 12) {
                    Image(systemName: f.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#1547CC"))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: "#EEF1FB"))
                        .clipShape(Circle())
                    Text(f.text)
                        .font(.subheadline)
                        .foregroundColor(C.text)
                }
            }
        }
        .padding(20)
        .background(C.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    var planSelector: some View {
        VStack(spacing: 10) {
            planCard(
                id: SubscriptionStore.annualId,
                title: "Annual",
                price: subStore.annual?.displayPrice ?? "$14.99",
                period: "per year",
                badge: "Save 37%"
            )
            planCard(
                id: SubscriptionStore.monthlyId,
                title: "Monthly",
                price: subStore.monthly?.displayPrice ?? "$1.99",
                period: "per month",
                badge: nil
            )
        }
    }

    var purchaseButton: some View {
        Button {
            Task {
                let product = selectedPlan == SubscriptionStore.annualId
                    ? subStore.annual : subStore.monthly
                if let p = product { await subStore.purchase(p) }
            }
        } label: {
            Group {
                if subStore.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Start Pro")
                        .font(.callout.weight(.heavy))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#1547CC"), Color(hex: "#6B3FD4")],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color(hex: "#1547CC").opacity(0.35), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(subStore.isLoading)
    }

    var legalFooter: some View {
        VStack(spacing: 8) {
            Button {
                Task { await subStore.restore() }
            } label: {
                Text("Restore Purchases")
                    .font(.footnote)
                    .foregroundColor(C.muted)
                    .underline()
            }
            .buttonStyle(.plain)

            Text("Subscriptions auto-renew unless cancelled. Cancel any time in Settings → Apple ID.")
                .font(.caption2)
                .foregroundColor(C.muted)
                .multilineTextAlignment(.center)
        }
    }

    func planCard(id: String, title: String, price: String, period: String, badge: String?) -> some View {
        let isSelected = selectedPlan == id
        return Button { selectedPlan = id } label: {
            HStack(spacing: 14) {
                radioCircle(selected: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(C.text)
                        if let badge = badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: "#059669"))
                                .clipShape(Capsule())
                        }
                    }
                    Text(period)
                        .font(.caption)
                        .foregroundColor(C.muted)
                }

                Spacer()

                Text(price)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(C.text)
            }
            .padding(16)
            .background(C.card)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color(hex: "#1547CC") : C.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    func radioCircle(selected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(selected ? Color(hex: "#1547CC") : C.border, lineWidth: 2)
                .background(Circle().fill(selected ? Color(hex: "#1547CC") : Color.clear))
                .frame(width: 20, height: 20)
            Circle()
                .fill(selected ? Color.white : Color.clear)
                .frame(width: 8, height: 8)
        }
    }
}

// Locked placeholder shown in place of Pro content
struct ProLockedView: View {
    @Environment(AppStore.self) var store
    @Environment(SubscriptionStore.self) var subStore
    let featureName: String
    let icon: String

    private var C: GColors { store.C }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(C.muted)
            Text(featureName)
                .font(.title3.weight(.heavy))
                .foregroundColor(C.text)
            Text("This feature is included with GiGi Pro.")
                .font(.callout)
                .foregroundColor(C.muted)
                .multilineTextAlignment(.center)
            Button {
                subStore.showPaywall = true
            } label: {
                Label("Upgrade to Pro", systemImage: "star.circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#1547CC"), Color(hex: "#6B3FD4")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}
