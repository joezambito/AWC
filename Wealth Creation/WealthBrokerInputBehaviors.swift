import SwiftUI

extension View {
    @ViewBuilder
    func awcAccountFieldInputBehavior() -> some View {
#if os(iOS) && !targetEnvironment(macCatalyst)
        self
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
#else
        self
#endif
    }

    @ViewBuilder
    func awcHostFieldInputBehavior() -> some View {
#if os(iOS) && !targetEnvironment(macCatalyst)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
#else
        self
#endif
    }

    @ViewBuilder
    func awcDecimalPadInputBehavior() -> some View {
#if os(iOS) && !targetEnvironment(macCatalyst)
        self.keyboardType(.decimalPad)
#else
        self
#endif
    }

    @ViewBuilder
    func awcNumberPadInputBehavior() -> some View {
#if os(iOS) && !targetEnvironment(macCatalyst)
        self.keyboardType(.numberPad)
#else
        self
#endif
    }

    @ViewBuilder
    func awcOneTimeCodeInputBehavior() -> some View {
#if os(iOS) && !targetEnvironment(macCatalyst)
        self.textContentType(.oneTimeCode)
#else
        self
#endif
    }
}
