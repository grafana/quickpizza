import SwiftUI

/// Expandable section for customizing pizza restrictions.
struct CustomizeSection: View {
    @Binding var restrictions: Restrictions
    let availableTools: [String]

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(AppColors.textSecondary)
                    Text("Customize Your Pizza")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(AppColors.textSecondary)
                        .font(.caption)
                }
                .padding(16)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 20) {
                    // Max calories
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max calories per slice")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            Text("\(restrictions.maxCaloriesPerSlice)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColors.primary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(restrictions.maxCaloriesPerSlice) },
                                set: { restrictions.maxCaloriesPerSlice = Int($0) }
                            ),
                            in: 100...2000,
                            step: 50
                        )
                        .tint(AppColors.primary)
                    }

                    Divider()

                    // Toppings range
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Min toppings")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            Stepper(
                                "\(restrictions.minNumberOfToppings)",
                                value: $restrictions.minNumberOfToppings,
                                in: 1...10
                            )
                            .font(.subheadline)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Max toppings")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            Stepper(
                                "\(restrictions.maxNumberOfToppings)",
                                value: $restrictions.maxNumberOfToppings,
                                in: 1...10
                            )
                            .font(.subheadline)
                        }
                    }

                    Divider()

                    // Vegetarian toggle
                    Toggle(isOn: $restrictions.mustBeVegetarian) {
                        HStack(spacing: 8) {
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(.green)
                            Text("Vegetarian only")
                                .font(.subheadline)
                        }
                    }
                    .tint(AppColors.primary)

                    // Excluded tools
                    if !availableTools.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Exclude tools")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textPrimary)
                            FlowLayout(spacing: 8) {
                                ForEach(availableTools, id: \.self) { tool in
                                    let isExcluded = restrictions.excludedTools.contains(tool)
                                    Button {
                                        if isExcluded {
                                            restrictions.excludedTools.removeAll { $0 == tool }
                                        } else {
                                            restrictions.excludedTools.append(tool)
                                        }
                                    } label: {
                                        Text(tool)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(isExcluded ? AppColors.primary.opacity(0.15) : Color.gray.opacity(0.1))
                                            .foregroundStyle(isExcluded ? AppColors.primary : AppColors.textSecondary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Custom name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom pizza name")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        TextField("Leave empty for random name", text: $restrictions.customName)
                            .textFieldStyle(.roundedBorder)
                            .font(.subheadline)
                    }
                }
                .padding(16)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// Simple flow layout for wrapping chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}
