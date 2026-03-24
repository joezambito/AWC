import SwiftUI

extension View {
    @ViewBuilder
    func awcAccountFieldInputBehavior() -> some View {
#if targetEnvironment(macCatalyst)
        self
#else
        self
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
#endif
    }

    @ViewBuilder
    func awcHostFieldInputBehavior() -> some View {
#if targetEnvironment(macCatalyst)
        self
#else
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
#endif
    }
}
