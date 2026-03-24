import SwiftUI

struct OpportunityDetailView: View {
    let opportunity: Opportunity
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            WealthTheme.background
                .ignoresSafeArea()

            GeometryReader { proxy in
                let isWide = proxy.size.width >= 980

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        detailHero

                        if isWide {
                            HStack(alignment: .top, spacing: 14) {
                                VStack(spacing: 14) {
                                    timingPanel
                                    researchPanel
                                }
                                .frame(maxWidth: .infinity, alignment: .top)

                                tradeIntelPanel
                                    .frame(maxWidth: .infinity, alignment: .top)
                            }
                        } else {
                            timingPanel
                            researchPanel
                            tradeIntelPanel
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 110)
                    .padding(.bottom, 40)
                    .frame(maxWidth: isWide ? 1180 : .infinity)
                    .frame(maxWidth: .infinity)
                }
            }

            backButton
        }
        .navigationBarBackButtonHidden(true)
    }

    var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.white)
                .frame(width: 66, height: 66)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.leading, 18)
        .padding(.top, 48)
    }
}
