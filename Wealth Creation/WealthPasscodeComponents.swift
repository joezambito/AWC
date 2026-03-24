import SwiftUI

struct WealthSheetKeypadButton: View {
    let title: String?
    let systemName: String?
    let action: () -> Void

    init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.systemName = nil
        self.action = action
    }

    init(systemName: String, action: @escaping () -> Void) {
        self.title = nil
        self.systemName = systemName
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )

                if let title {
                    Text(title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                } else if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.plain)
    }
}
