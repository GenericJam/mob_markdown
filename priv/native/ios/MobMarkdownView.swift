import SwiftUI
import UIKit

// The iOS side of MobMarkdown.View (see the MobMarkdown moduledoc for the
// props), the counterpart of MobMarkdown.kt: Foundation's Markdown parser
// (CommonMark + GFM tables, strikethrough and autolinks) into an attributed
// string in a read-only, selectable UITextView, so inline styles wrap like
// prose and any range can be drag-selected and copied.
//
// UIKit has no table layout for attributed text, so tables are drawn as
// box-drawing text in the code (monospace) face, columns shrunk widest-first
// to the view's width and cells wrapped inside their column; they select and
// copy as text. Rules are drawn the same way.
//
// mob_dev's generated mob_register_plugins() registers this struct under
// "MobMarkdown_View" and hands it only the props, so link taps reach the BEAM
// through mob_send_component_event with the props' component_handle (what
// MobNativeViewRegistry's own send closure calls).
//
// A view's text view is created once and only re-rendered when its `text`,
// style props or width in code columns change (a streaming reply grows a few
// times a second; finished ones never change).
struct MobMarkdownView: UIViewRepresentable {
    let props: [String: Any]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        // TextKit 1: TextKit 2 lays out lazily, and its sizeThatFits
        // under-measures long text (the view's bottom gets cut off).
        let view = UITextView(usingTextLayoutManager: false)
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.dataDetectorTypes = []
        view.delegate = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.handle = mobMarkdownInt(props["component_handle"]) ?? -1
        coordinator.update(view, text: props["text"] as? String ?? "", style: MobMdStyle(props))
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView view: UITextView, context: Context) -> CGSize? {
        let width = proposal.width.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
            ?? view.window?.bounds.width ?? UIScreen.main.bounds.width
        context.coordinator.layout(view, width: width)
        let fitted = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var handle = -1
        private var text: String?
        private var style: MobMdStyle?
        private var columns = 0

        func update(_ view: UITextView, text: String, style: MobMdStyle) {
            if style != self.style {
                view.tintColor = style.selectionColor
                view.linkTextAttributes = [
                    .foregroundColor: style.linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                ]
            }
            guard text != self.text || style != self.style else { return }
            self.text = text
            self.style = style
            render(view)
        }

        /// Called with the width SwiftUI offers; re-renders only when the
        /// view's width in code columns changes (tables and rules depend on it).
        func layout(_ view: UITextView, width: CGFloat) {
            guard let style else { return }
            let columns = max(1, Int((width / style.codeCharWidth).rounded(.down)))
            guard columns != self.columns else { return }
            self.columns = columns
            render(view)
        }

        private func render(_ view: UITextView) {
            guard let text, let style else { return }
            view.attributedText = MobMdRenderer(style: style, columns: columns > 0 ? columns : 40).render(text)
        }

        // Links go to the BEAM (MobMarkdown.View handles "open_link" and
        // opens only web and mail links): never let UIKit open the text's
        // URLs itself, by tap or by the long-press menu.
        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem,
                      defaultAction: UIAction) -> UIAction? {
            guard case let .link(url) = textItem.content else { return defaultAction }
            return UIAction { [weak self] _ in self?.open(url) }
        }

        func textView(_ textView: UITextView, menuConfigurationFor textItem: UITextItem,
                      defaultMenu: UIMenu) -> UITextItem.MenuConfiguration? {
            guard case let .link(url) = textItem.content else {
                return UITextItem.MenuConfiguration(menu: defaultMenu)
            }
            let open = UIAction(title: "Open Link", image: UIImage(systemName: "safari")) { [weak self] _ in
                self?.open(url)
            }
            let copy = UIAction(title: "Copy Link", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.url = url
            }
            return UITextItem.MenuConfiguration(menu: UIMenu(title: url.absoluteString, children: [open, copy]))
        }

        private func open(_ url: URL) {
            // -1: the BEAM had no component slot for this view (MOB-100).
            guard handle >= 0,
                  let data = try? JSONSerialization.data(withJSONObject: ["url": url.absoluteString]),
                  let json = String(data: data, encoding: .utf8) else { return }
            mob_send_component_event(Int32(handle), "open_link", json)
        }
    }
}

struct MobMdStyle: Equatable {
    var textSize: CGFloat
    var lineHeight: CGFloat
    var textColor: UIColor
    var headingColor: UIColor
    var linkColor: UIColor
    var codeColor: UIColor
    var codeBackground: UIColor
    var quoteColor: UIColor
    var ruleColor: UIColor
    var selectionColor: UIColor
    var fontRegular: String
    var fontBold: String
    var fontItalic: String
    var fontBoldItalic: String
    var fontHeading: String
    var fontCode: String

    init(_ props: [String: Any]) {
        textSize = mobMarkdownFloat(props["text_size"], default: 15)
        lineHeight = mobMarkdownFloat(props["line_height"], default: 1.4)
        textColor = mobMarkdownColor(props["text_color"], default: 0xFF1E1E1E)
        headingColor = mobMarkdownColor(props["heading_color"], default: 0xFF1E1E1E)
        linkColor = mobMarkdownColor(props["link_color"], default: 0xFF1A5FB4)
        codeColor = mobMarkdownColor(props["code_color"], default: 0xFF1E1E1E)
        codeBackground = mobMarkdownColor(props["code_background"], default: 0x14000000)
        quoteColor = mobMarkdownColor(props["quote_color"], default: 0xFF6B6B6B)
        ruleColor = mobMarkdownColor(props["rule_color"], default: 0xFFCCCCCC)
        selectionColor = mobMarkdownColor(props["selection_color"], default: 0xFF1A5FB4)
        fontRegular = props["font_regular"] as? String ?? ""
        fontBold = props["font_bold"] as? String ?? ""
        fontItalic = props["font_italic"] as? String ?? ""
        fontBoldItalic = props["font_bold_italic"] as? String ?? ""
        fontHeading = props["font_heading"] as? String ?? ""
        fontCode = props["font_code"] as? String ?? ""
    }

    /// Monospace at the body size reads large next to a proportional face.
    var codeSize: CGFloat { textSize * 0.9 }

    func face(bold: Bool, italic: Bool, size: CGFloat) -> UIFont {
        switch (bold, italic) {
        case (true, true):
            return mobMarkdownFont(fontBoldItalic, size: size)
                ?? mobMarkdownSlanted(face(bold: true, italic: false, size: size))
        case (true, false):
            return mobMarkdownFont(fontBold, size: size) ?? .systemFont(ofSize: size, weight: .semibold)
        case (false, true):
            return mobMarkdownFont(fontItalic, size: size)
                ?? mobMarkdownSlanted(face(bold: false, italic: false, size: size))
        case (false, false):
            return mobMarkdownFont(fontRegular, size: size) ?? .systemFont(ofSize: size)
        }
    }

    func heading(size: CGFloat) -> UIFont {
        mobMarkdownFont(fontHeading, size: size) ?? face(bold: true, italic: false, size: size)
    }

    func code(bold: Bool = false) -> UIFont {
        if let named = mobMarkdownFont(fontCode, size: codeSize) {
            return bold ? (mobMarkdownWithTraits(named, .traitBold) ?? named) : named
        }
        return .monospacedSystemFont(ofSize: codeSize, weight: bold ? .semibold : .regular)
    }

    /// The advance of one character of the code face: the width of a table
    /// or rule column.
    var codeCharWidth: CGFloat {
        ("0" as NSString).size(withAttributes: [.font: code()]).width
    }
}

/// Markdown to an attributed string for one view: Foundation's parse, then
/// one pass over its runs laying out blocks, lists, quotes and tables.
struct MobMdRenderer {
    let style: MobMdStyle
    let columns: Int  // the view's width in code-face characters
    private let faces: [UIFont]  // regular, bold, italic, bold italic at the text size
    private let regular: UIFont
    private let code: UIFont
    private let codeBold: UIFont

    init(style: MobMdStyle, columns: Int) {
        self.style = style
        self.columns = columns
        faces = [(false, false), (true, false), (false, true), (true, true)].map {
            style.face(bold: $0.0, italic: $0.1, size: style.textSize)
        }
        regular = faces[0]
        code = style.code()
        codeBold = style.code(bold: true)
    }

    private func face(bold: Bool, italic: Bool) -> UIFont {
        faces[(bold ? 1 : 0) + (italic ? 2 : 0)]
    }

    private static let headingSizes: [CGFloat] = [1.3, 1.18, 1.08, 1, 1, 1]
    private static let bullets = ["•", "◦", "▪"]
    private static let tagPattern = try! NSRegularExpression(pattern: "^<(/?)([a-zA-Z][a-zA-Z0-9]*)[^>]*?(/?)>$")
    private static let anyTag = try! NSRegularExpression(pattern: "<[^>]*>")

    func render(_ markdown: String) -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: false,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let parsed = try? AttributedString(markdown: markdown, options: options) else {
            return NSAttributedString(string: markdown, attributes: base())
        }
        var state = State()
        for run in parsed.runs {
            add(String(parsed[run.range].characters), run: run, state: &state)
        }
        flushTable(&state)
        endBlock(&state)
        return state.out
    }

    // ── one pass over the runs ──

    private struct State {
        let out = NSMutableAttributedString()
        var block: Int?             // identity of the innermost block on the go
        var blockStart = 0
        var blockKind: BlockKind = .paragraph
        var lists: [Int] = []       // list identities around that block
        var indent: CGFloat = 0     // its hanging indent, in points
        var markers: [Int: NSAttributedString] = [:]  // list item identity → its marker
        var html = HtmlStyle()
        var table: Table?
        var synthetic = -1          // identities for blocks the parser gives none
    }

    private enum BlockKind { case paragraph, heading(Int), code, rule, quote, table }

    private struct HtmlStyle {
        var bold = 0, italic = 0, underline = 0, strike = 0, code = 0
    }

    private func add(_ text: String, run: AttributedString.Runs.Run, state: inout State) {
        let components = run.presentationIntent?.components ?? []

        if let table = components.first(where: { if case .table = $0.kind { true } else { false } }) {
            addTableText(text, run: run, components: components, table: table, state: &state)
            return
        }
        flushTable(&state)

        let inline = run.inlinePresentationIntent ?? []
        let identity: Int
        if let innermost = components.first {
            identity = innermost.identity
        } else if let current = state.block, current < 0, !inline.contains(.blockHTML) {
            // Loose text after block HTML stays in that block.
            identity = current
        } else {
            identity = state.synthetic
            state.synthetic -= 1
        }

        if identity != state.block { beginBlock(identity, components: components, state: &state) }

        if inline.contains(.blockHTML) {
            let stripped = Self.anyTag.stringByReplacingMatches(
                in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
            state.out.append(NSAttributedString(
                string: stripped.trimmingCharacters(in: .whitespacesAndNewlines), attributes: base()))
            return
        }
        if inline.contains(.inlineHTML) {
            html(text, state: &state)
            return
        }

        var piece = text
        if inline.contains(.lineBreak) { piece = "\u{2028}" }
        if case .code = state.blockKind {
            // The code block's text ends with its newline; the block break adds one.
            if piece.hasSuffix("\n") { piece.removeLast() }
            piece = piece.replacingOccurrences(of: "\n", with: "\u{2028}")
        }
        if case .rule = state.blockKind {
            state.out.append(NSAttributedString(
                string: String(repeating: "─", count: columns),
                attributes: base(color: style.ruleColor, font: code)))
            return
        }
        state.out.append(NSAttributedString(string: piece, attributes: inlineAttributes(inline, link: run.link, state: state)))
    }

    private func beginBlock(_ identity: Int, components: [PresentationIntent.IntentType], state: inout State) {
        let lists = components.compactMap { c -> Int? in
            switch c.kind {
            case .orderedList, .unorderedList: return c.identity
            default: return nil
            }
        }
        if state.block != nil {
            endBlock(&state)
            // Items of one list sit line by line; other blocks get a blank line.
            let tight = !lists.isEmpty && lists.last == state.lists.last
            state.out.append(NSAttributedString(string: tight ? "\n" : "\n\n", attributes: base()))
        }
        state.block = identity
        state.lists = lists
        state.blockStart = state.out.length
        state.blockKind = .paragraph

        // Prefixes, outermost first: a bar per quote, a marker (or blank
        // space as wide as it, past the item's first block) per list item.
        let prefix = NSMutableAttributedString()
        var depth = 0
        for (index, component) in components.enumerated().reversed() {
            switch component.kind {
            case .blockQuote:
                prefix.append(NSAttributedString(string: "┃ ", attributes: base(color: style.quoteColor)))
                state.blockKind = .quote
            case let .listItem(ordinal):
                if let marker = state.markers[component.identity] {
                    // Later blocks of the item: one space stretched to the
                    // marker's width, so they line up and copy as a space.
                    let blank = NSMutableAttributedString(string: " ", attributes: base())
                    let stretch = marker.size().width - blank.size().width
                    blank.addAttribute(.kern, value: max(0, stretch), range: NSRange(location: 0, length: 1))
                    prefix.append(blank)
                } else {
                    // The list right outside the item says how it's marked.
                    var ordered = false
                    if index + 1 < components.count, case .orderedList = components[index + 1].kind { ordered = true }
                    let text = ordered ? "\(ordinal). " : "\(Self.bullets[min(depth, Self.bullets.count - 1)]) "
                    let marker = NSAttributedString(string: text, attributes: base(color: style.quoteColor))
                    state.markers[component.identity] = marker
                    prefix.append(marker)
                }
                depth += 1
            case let .header(level):
                state.blockKind = .heading(level)
            case .codeBlock:
                state.blockKind = .code
            case .thematicBreak:
                state.blockKind = .rule
            case .table:
                state.blockKind = .table
            default:
                break
            }
        }
        state.indent = prefix.length > 0 ? ceil(prefix.size().width) : 0
        state.out.append(prefix)
    }

    private func endBlock(_ state: inout State) {
        guard state.block != nil else { return }
        // A table brings its own paragraph style.
        if case .table = state.blockKind { return }
        let range = NSRange(location: state.blockStart, length: state.out.length - state.blockStart)
        guard range.length > 0 else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = style.lineHeight
        paragraph.headIndent = state.indent
        if case .rule = state.blockKind { paragraph.lineBreakMode = .byClipping }
        state.out.addAttribute(.paragraphStyle, value: paragraph, range: range)
    }

    // ── inline styles ──

    private func base(color: UIColor? = nil, font: UIFont? = nil) -> [NSAttributedString.Key: Any] {
        [
            .font: font ?? regular,
            .foregroundColor: color ?? style.textColor,
        ]
    }

    private func inlineAttributes(_ inline: InlinePresentationIntent, link: URL?, state: State) -> [NSAttributedString.Key: Any] {
        let bold = inline.contains(.stronglyEmphasized) || state.html.bold > 0
        let italic = inline.contains(.emphasized) || state.html.italic > 0
        let isCode = inline.contains(.code) || state.html.code > 0
        var codeBlock = false
        if case .code = state.blockKind { codeBlock = true }

        var attributes: [NSAttributedString.Key: Any]
        if isCode || codeBlock {
            attributes = base(color: style.codeColor, font: code)
            attributes[.backgroundColor] = style.codeBackground
        } else if case let .heading(level) = state.blockKind {
            let size = style.textSize * Self.headingSizes[min(max(level - 1, 0), Self.headingSizes.count - 1)]
            attributes = base(color: style.headingColor, font: style.heading(size: size))
        } else if case .quote = state.blockKind {
            attributes = base(color: style.quoteColor, font: face(bold: bold, italic: italic))
        } else {
            attributes = base(font: face(bold: bold, italic: italic))
        }
        if inline.contains(.strikethrough) || state.html.strike > 0 {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if state.html.underline > 0 {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if let link { attributes[.link] = link }
        return attributes
    }

    /// Inline HTML: `<br>` breaks the line, the style tags nest, anything
    /// else is dropped (the text between stays).
    private func html(_ tag: String, state: inout State) {
        let range = NSRange(tag.startIndex..., in: tag)
        guard let match = Self.tagPattern.firstMatch(in: tag, range: range),
              let closeRange = Range(match.range(at: 1), in: tag),
              let nameRange = Range(match.range(at: 2), in: tag) else { return }
        let closing = !tag[closeRange].isEmpty
        let name = tag[nameRange].lowercased()
        let step = closing ? -1 : 1

        func bump(_ value: inout Int) { value = max(0, value + step) }
        switch name {
        case "br":
            state.out.append(NSAttributedString(string: "\u{2028}", attributes: base()))
        case "b", "strong":
            bump(&state.html.bold)
        case "i", "em":
            bump(&state.html.italic)
        case "u", "ins":
            bump(&state.html.underline)
        case "s", "del", "strike":
            bump(&state.html.strike)
        case "code", "kbd", "tt":
            bump(&state.html.code)
        default:
            break
        }
    }

    // ── tables ──

    private struct Table {
        let identity: Int
        let alignments: [PresentationIntent.TableColumn.Alignment]
        var rows: [(identity: Int, header: Bool, cells: [Int: NSMutableAttributedString])] = []
    }

    private func addTableText(_ text: String, run: AttributedString.Runs.Run, components: [PresentationIntent.IntentType],
                              table: PresentationIntent.IntentType, state: inout State) {
        if state.table?.identity != table.identity {
            flushTable(&state)
            beginBlock(table.identity, components: Array(components.drop { $0.identity != table.identity }), state: &state)
            guard case let .table(columns) = table.kind else { return }
            state.table = Table(identity: table.identity, alignments: columns.map(\.alignment))
        }
        var row: (Int, Bool)?
        var column = 0
        for component in components {
            switch component.kind {
            case .tableHeaderRow: row = (component.identity, true)
            case .tableRow: row = (component.identity, false)
            case let .tableCell(index): column = index
            default: break
            }
        }
        guard let (rowIdentity, header) = row else { return }
        if state.table!.rows.last?.identity != rowIdentity {
            state.table!.rows.append((rowIdentity, header, [:]))
        }

        let inline = run.inlinePresentationIntent ?? []
        var piece = text
        if inline.contains(.inlineHTML) {
            // Tables keep only line breaks of the inline HTML, as spaces.
            piece = text.lowercased().hasPrefix("<br") ? " " : ""
        }
        // Every cell is in the code face, so the columns line up; bold
        // (and the header row) in its bold weight.
        var attributes = base(font: header || inline.contains(.stronglyEmphasized) ? codeBold : code)
        if inline.contains(.code) { attributes[.foregroundColor] = style.codeColor }
        if inline.contains(.strikethrough) {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if let link = run.link { attributes[.link] = link }
        let last = state.table!.rows.count - 1
        let cell = state.table!.rows[last].cells[column] ?? NSMutableAttributedString()
        cell.append(NSAttributedString(string: piece.replacingOccurrences(of: "\n", with: " "), attributes: attributes))
        state.table!.rows[last].cells[column] = cell
    }

    private func flushTable(_ state: inout State) {
        guard let table = state.table else { return }
        state.table = nil
        state.out.append(layoutTable(table))
    }

    /// The table as box-drawing lines, columns shrunk widest-first to fit
    /// the view and cells wrapped inside them.
    private func layoutTable(_ table: Table) -> NSAttributedString {
        let count = max(table.alignments.count, (table.rows.flatMap { $0.cells.keys }.max() ?? -1) + 1)
        guard count > 0 else { return NSAttributedString() }
        var widths = (0..<count).map { column in
            max(1, table.rows.map { $0.cells[column]?.length ?? 0 }.max() ?? 0)
        }
        let available = max(count, columns - (3 * count + 1))
        while widths.reduce(0, +) > available, let widest = widths.indices.max(by: { widths[$0] < widths[$1] }),
              widths[widest] > 1 {
            widths[widest] -= 1
        }

        let border = base(color: style.ruleColor, font: code)
        let space = base(font: code)
        let out = NSMutableAttributedString()
        func rule(_ left: String, _ middle: String, _ right: String) {
            let line = left + widths.map { String(repeating: "─", count: $0 + 2) }.joined(separator: middle) + right
            if out.length > 0 { out.append(NSAttributedString(string: "\n", attributes: border)) }
            out.append(NSAttributedString(string: line, attributes: border))
        }

        rule("┌", "┬", "┐")
        for (index, row) in table.rows.enumerated() {
            let cells = (0..<count).map { wrap(row.cells[$0] ?? NSAttributedString(), width: widths[$0]) }
            let height = cells.map(\.count).max() ?? 1
            for line in 0..<max(1, height) {
                let text = NSMutableAttributedString(string: "│", attributes: border)
                for column in 0..<count {
                    let part = line < cells[column].count ? cells[column][line] : NSAttributedString()
                    let alignment = column < table.alignments.count ? table.alignments[column] : .left
                    text.append(NSAttributedString(string: " ", attributes: space))
                    text.append(pad(part, to: widths[column], alignment: alignment, space: space))
                    text.append(NSAttributedString(string: " │", attributes: border))
                }
                if row.header {
                    // Inside the outer borders: a background on the last
                    // glyph of a line runs on to the view's edge.
                    text.addAttribute(.backgroundColor, value: style.codeBackground,
                                      range: NSRange(location: 1, length: text.length - 2))
                }
                out.append(NSAttributedString(string: "\n", attributes: border))
                out.append(text)
            }
            // A rule under every row but the last, the grid Markwon draws.
            if index < table.rows.count - 1 { rule("├", "┼", "┤") }
        }
        rule("└", "┴", "┘")

        // A line a hair too wide must clip, not wrap and break the box.
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byClipping
        out.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: out.length))
        return out
    }

    /// Greedy word wrap at `width` characters (UTF-16 units: wide emoji
    /// count two, close to their two-column width).
    private func wrap(_ cell: NSAttributedString, width: Int) -> [NSAttributedString] {
        let string = cell.string as NSString
        let space = UInt16(UnicodeScalar(" ").value)
        var lines: [NSAttributedString] = []
        var start = 0
        while start < string.length {
            while start < string.length, string.character(at: start) == space { start += 1 }
            guard start < string.length else { break }
            if string.length - start <= width {
                lines.append(cell.attributedSubstring(from: NSRange(location: start, length: string.length - start)))
                break
            }
            var cut = start + width
            var index = cut
            while index > start, string.character(at: index) != space { index -= 1 }
            if index > start { cut = index }
            lines.append(cell.attributedSubstring(from: NSRange(location: start, length: cut - start)))
            start = cut
        }
        return lines
    }

    private func pad(_ text: NSAttributedString, to width: Int, alignment: PresentationIntent.TableColumn.Alignment,
                     space: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let missing = max(0, width - text.length)
        let left: Int
        switch alignment {
        case .right: left = missing
        case .center: left = missing / 2
        default: left = 0
        }
        let out = NSMutableAttributedString(string: String(repeating: " ", count: left), attributes: space)
        out.append(text)
        out.append(NSAttributedString(string: String(repeating: " ", count: missing - left), attributes: space))
        return out
    }
}

// ── prop helpers ──

func mobMarkdownInt(_ value: Any?) -> Int? {
    (value as? NSNumber)?.intValue
}

func mobMarkdownFloat(_ value: Any?, default fallback: CGFloat) -> CGFloat {
    guard let number = value as? NSNumber else { return fallback }
    return CGFloat(number.doubleValue)
}

/// An ARGB integer (0xAARRGGBB) as a UIColor.
func mobMarkdownColor(_ value: Any?, default fallback: UInt32) -> UIColor {
    let argb = (value as? NSNumber).map { UInt32(truncatingIfNeeded: $0.int64Value) } ?? fallback
    return UIColor(
        red: CGFloat((argb >> 16) & 0xFF) / 255,
        green: CGFloat((argb >> 8) & 0xFF) / 255,
        blue: CGFloat(argb & 0xFF) / 255,
        alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
}

/// A bundled face by PostScript name, or nil for "" and a face the app
/// doesn't have.
func mobMarkdownFont(_ name: String, size: CGFloat) -> UIFont? {
    name.isEmpty ? nil : UIFont(name: name, size: size)
}

func mobMarkdownWithTraits(_ font: UIFont, _ traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
    font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(traits))
        .map { UIFont(descriptor: $0, size: font.pointSize) }
}

/// The face's italic if it has one, else the face slanted 12°.
func mobMarkdownSlanted(_ font: UIFont) -> UIFont {
    if let italic = mobMarkdownWithTraits(font, .traitItalic),
       italic.fontDescriptor.symbolicTraits.contains(.traitItalic),
       italic.fontName != font.fontName {
        return italic
    }
    let skew = CGAffineTransform(a: 1, b: 0, c: tan(12 * .pi / 180), d: 1, tx: 0, ty: 0)
    return UIFont(descriptor: font.fontDescriptor.withMatrix(skew), size: font.pointSize)
}
