import SwiftUI

extension WealthSystemParametersSection {
    func protectionInputCard<Field: View>(title: String, detail: String, fieldTitle: String, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(detail)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(WealthTheme.grey)

            VStack(alignment: .leading, spacing: 6) {
                Text(fieldTitle)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.62))
                field
            }
        }
        .padding(12)
        .background(cardShell(cornerRadius: 22))
    }

    func percentField(value: Binding<Double>, tint: Color) -> some View {
        HStack {
            TextField("", value: value, format: .number)
                .awcDecimalPadInputBehavior()
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(tint)
                .multilineTextAlignment(.center)
            Text("%")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(tint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(sectionGlowShell(cornerRadius: 16, tint: tint))
    }

    func moneyField(value: Binding<Double>, tint: Color) -> some View {
        HStack(spacing: 10) {
            Text("A$")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(tint)
            TextField("", value: value, format: .number)
                .awcDecimalPadInputBehavior()
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(tint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardShell(cornerRadius: 16))
    }

    func minutesField(value: Binding<Double>, tint: Color) -> some View {
        HStack(spacing: 10) {
            TextField("", value: value, format: .number)
                .awcDecimalPadInputBehavior()
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(tint)
                .multilineTextAlignment(.center)
            Text("min")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(tint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardShell(cornerRadius: 16))
    }
}
