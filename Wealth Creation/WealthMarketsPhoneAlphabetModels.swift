import Foundation

enum PhoneMarketBucketStyle {
    case grouped
    case singleLetter
}

struct PhoneMarketLetterBucket: Identifiable, Hashable {
    let id: String
    let title: String
    let letters: Set<Character>
    let includesOther: Bool

    func matches(symbol: String) -> Bool {
        guard let firstLetter = symbol.uppercased().first(where: \.isLetter) else {
            return includesOther
        }
        return letters.contains(firstLetter)
    }

    static func buckets(for style: PhoneMarketBucketStyle, includeOther: Bool) -> [PhoneMarketLetterBucket] {
        switch style {
        case .grouped:
            return [
                .init(id: "A-B", title: "A-B", letters: Set("AB"), includesOther: false),
                .init(id: "C-D", title: "C-D", letters: Set("CD"), includesOther: false),
                .init(id: "E-F", title: "E-F", letters: Set("EF"), includesOther: false),
                .init(id: "G-H", title: "G-H", letters: Set("GH"), includesOther: false),
                .init(id: "I-L", title: "I-L", letters: Set("IJKL"), includesOther: false),
                .init(id: "M-O", title: "M-O", letters: Set("MNO"), includesOther: false),
                .init(id: "P-R", title: "P-R", letters: Set("PQR"), includesOther: false),
                .init(id: "S-T", title: "S-T", letters: Set("ST"), includesOther: false),
                .init(id: "U-Z", title: "U-Z", letters: Set("UVWXYZ"), includesOther: false)
            ] + (includeOther ? [.init(id: "OTHER", title: "OTHER", letters: [], includesOther: true)] : [])
        case .singleLetter:
            let alphabetBuckets = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { letter in
                PhoneMarketLetterBucket(
                    id: String(letter),
                    title: String(letter),
                    letters: [letter],
                    includesOther: false
                )
            }
            return alphabetBuckets + (includeOther ? [.init(id: "OTHER", title: "OTHER", letters: [], includesOther: true)] : [])
        }
    }
}

struct PhoneMarketSummary: Identifiable, Hashable {
    let code: String
    let count: Int
    let style: PhoneMarketBucketStyle

    var id: String { code }
    var title: String { code }
}
