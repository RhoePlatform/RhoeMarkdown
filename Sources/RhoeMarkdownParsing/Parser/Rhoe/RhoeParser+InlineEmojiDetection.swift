import Foundation
import RhoeMarkdownModel

private let gfmEmojiMap: [String: String] = [
    "smile": "😄",
    "heart": "❤️",
    "rocket": "🚀",
    "happy": "😊",
    "+1": "👍",
    "thumbsup": "👍",
    "-1": "👎",
    "thumbsdown": "👎",
    "100": "💯",
    "fire": "🔥",
    "tada": "🎉",
    "x": "❌",
    "white_check_mark": "✅",
    "hourglass": "⏳",
    "star": "⭐",
    "bug": "🐛",
    "book": "📖",
    "memo": "📝",
    "pencil": "✏️",
    "warning": "⚠️",
    "bulb": "💡",
    "pushpin": "📌",
    "construction": "🚧",
    "heavy_check_mark": "✔️",
    "eyes": "👀",
    "email": "📧",
    "exclamation": "❗",
    "sparkles": "✨",
    "computer": "💻",
    "laptop": "💻",
    "desktop": "🖥️",
    "mobile": "📱",
    "wave": "👋",
    "clap": "👏",
    "muscle": "💪",
    "trophy": "🏆",
    "crown": "👑",
    "gem": "💎",
    "zap": "⚡",
    "boom": "💥",
    "dizzy": "💫",
    "unicorn": "🦄",
    "rainbow": "🌈"
]

extension RhoeParser {
    func detectEmoji(in text: String, at position: String.Index) -> (inline: Inline, endIndex: String.Index)? {
        guard text[position] == ":" else { return nil }
        guard position < text.index(before: text.endIndex) else { return nil }

        var endPos = text.index(after: position)
        while endPos < text.endIndex {
            let char = text[endPos]
            if char == ":" {
                let emojiName = String(text[text.index(after: position)..<endPos])
                if !emojiName.isEmpty && emojiName.allSatisfy({ isEmojiNameCharacter($0) }) {
                    return (
                        .emoji(
                            name: emojiName,
                            unicode: gfmEmojiMap[emojiName]
                        ),
                        text.index(after: endPos)
                    )
                }
                break
            }
            if !isEmojiNameCharacter(char) {
                break
            }
            endPos = text.index(after: endPos)
        }

        return nil
    }
}
