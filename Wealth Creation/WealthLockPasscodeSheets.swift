import SwiftUI

struct WealthPasscodePad: View {
    @Binding var value: String
    let onCommit: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            WealthPasscodeDots(count: value.count)

            VStack(spacing: 12) {
                ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(row, id: \.self) { number in
                            WealthSheetKeypadButton(title: "\(number)") {
                                append(number)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)

                    WealthSheetKeypadButton(title: "0") {
                        append(0)
                    }

                    WealthSheetKeypadButton(systemName: "delete.left") {
                        if !value.isEmpty {
                            value.removeLast()
                        }
                    }
                }
            }
        }
    }

    private func append(_ digit: Int) {
        guard value.count < 6 else { return }
        value.append(String(digit))
        if value.count == 6 {
            onCommit()
        }
    }
}
