import SwiftUI

struct CategorySheet: View {
    @Environment(AppStore.self) var store
    @Environment(SubscriptionStore.self) var subStore
    private var C: GColors { store.C }
    @State private var showDeleteConfirm = false

    private let swatches = [
        "#3D5AFE","#4CAF50","#FF9800","#FF6B9D","#9C27B0",
        "#EF5350","#00BCD4","#FF5722","#607D8B","#795548"
    ]

    private var isNew: Bool { store.editingCategoryId == nil }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    fieldLabel("Name")
                    TextField("Category name…", text: $store.catForm.name)
                        .font(.subheadline.bold())
                        .foregroundColor(C.text)
                        .tint(C.primary)
                        .padding(14)
                        .background(C.bg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(store.catForm.name.isEmpty ? C.border : C.primary, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Color swatches
                    fieldLabel("Color")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                        ForEach(swatches, id: \.self) { color in
                            Button { store.catForm.color = color } label: {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(store.catForm.color == color ? C.text : Color.clear, lineWidth: 3)
                                    )
                                    .shadow(color: store.catForm.color == color ? .black.opacity(0.25) : .clear, radius: 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Preview
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: store.catForm.color))
                            .frame(width: 12, height: 12)
                        Text(store.catForm.name.isEmpty ? "Preview" : store.catForm.name)
                            .font(.callout.bold())
                            .foregroundColor(C.text)
                        Text("· category tag")
                            .font(.caption)
                            .foregroundColor(C.muted)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(C.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Category limit notice for free users
                    let atFreeLimit = isNew && store.categories.count >= 3 && !subStore.isPro
                    if atFreeLimit {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#1547CC"))
                            Text("Free plan includes up to 3 categories. Upgrade to Pro for unlimited.")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#1547CC"))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "#EEF1FB"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Save button
                    Button {
                        if atFreeLimit {
                            subStore.showPaywall = true
                        } else {
                            store.saveCategory()
                        }
                    } label: {
                        Text(atFreeLimit ? "Upgrade to Add More" : (isNew ? "Add Category" : "Save Changes"))
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(store.catForm.name.isEmpty ? C.border :
                                        atFreeLimit ? Color(hex: "#1547CC") : C.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.catForm.name.isEmpty && !atFreeLimit)

                    // Delete button (edit mode only)
                    if !isNew {
                        Button { showDeleteConfirm = true } label: {
                            Text("Delete Category")
                                .font(.callout.bold())
                                .foregroundColor(C.high)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog("Delete this category?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                            Button("Delete", role: .destructive) {
                                if let id = store.editingCategoryId { store.deleteCategory(id) }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Tasks in this category will become uncategorized.")
                        }
                    }
                }
                .padding(24)
            }
            .background(C.bg)
            .navigationTitle(isNew ? "New Category" : "Edit Category")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.showCategorySheet = false
                        store.catForm = CatForm()
                        store.editingCategoryId = nil
                    }
                    .foregroundColor(C.primary)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(C.bg)
        #endif
    }

    @ViewBuilder func fieldLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.caption2.bold())
            .foregroundColor(C.muted)
            .tracking(0.8)
    }
}
