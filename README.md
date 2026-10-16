# mob_markdown

Native Markdown for [Mob](https://github.com/GenericJam/mob) apps: CommonMark
plus GitHub tables and strikethrough, with autolinked URLs, drawn by the
platform's own text view. Inline styles wrap like prose, the text selects and
copies, and links open only when they're web or mail links.

```elixir
MobMarkdown.view(:reply, """
## Exodus 31:3

**Bezalel** is *filled* with the Spirit of God.

| Hebrew | Gloss |
|--|--|
| רוּחַ | spirit |
""")
```

| Platform | Renderer |
|--|--|
| Android | [Markwon](https://github.com/noties/Markwon) 4.6.2 in selectable `TextView`s. The text is cut at its tables: the prose wraps to the view's width, and each table (Markwon's table plugin, columns split evenly) sits at its natural width, at least the view's, in a horizontal scroller of its own. A table wider than the view scrolls sideways; a narrower one fills the width and doesn't scroll. |
| iOS | Foundation's `AttributedString(markdown:)` in read-only selectable `UITextView`s (TextKit 1), cut the same way. UIKit has no table layout for attributed text, so a table is box-drawing text in the code face at its natural width, in a horizontal `ScrollView`. |

On both, a column grows to its widest cell up to 32 code columns, past
which its cells wrap; a horizontal swipe on a table scrolls it, a vertical
one scrolls the screen. Selection works within one block of prose or one
table, not across them.

## Props

`MobMarkdown.view(id, text, props)`; `id` is an atom unique on the screen and
stable across renders. Every prop is optional.

| Prop | Meaning | Default |
|--|--|--|
| `text_size` | body size, sp / pt | 15 |
| `line_height` | multiplier | 1.4 |
| `text_color`, `heading_color`, `link_color`, `code_color`, `code_background`, `quote_color`, `rule_color`, `selection_color` | ARGB integers (`0xAARRGGBB`); `quote_color` also marks list items, `rule_color` draws rules and table borders | dark text on light |
| `font_regular`, `font_bold`, `font_italic`, `font_bold_italic` | body faces | the system face; a missing italic is slanted from the upright face |
| `font_heading` | headings (sized 1.45×, 1.3×, 1.18×, 1.08× for levels 1–4) | the bold face |
| `font_code` | inline code, code blocks, iOS tables | the system monospace, at 0.9× |

Faces are named the way each platform loads them: an iOS PostScript name, an
Android `res/font` resource name. Pass them in mob's platform blocks, which
the renderer resolves before the props reach the phone:

```elixir
MobMarkdown.view(:reply, text,
  text_color: 0xFF1E1A16,
  ios: %{font_regular: "InstrumentSans-Regular"},
  android: %{font_regular: "instrumentsans_regular"}
)
```

A theme's font token (`Mob.Theme.font/2`) is already that pair:
`%{ios: ios_name, android: android_name}`.

## Links

A tapped link reaches `MobMarkdown.View` as an `"open_link"` event and opens
only if `MobMarkdown.openable?/1` allows it (`http`, `https`, `mailto`):
the text is often a model's, so `intent:`, `file:`, `javascript:` and app
schemes are dropped. It opens with `Mob.Device.open_url/1`, or with
`config :mob_markdown, :open_url, fun_or_{module, function}`. On iOS the
long-press menu offers Open Link (the same path) and Copy Link.

## Installing

Not on Hex yet; depend on a commit:

```elixir
# mix.exs
{:mob_markdown, github: "GenericJam/mob_markdown", ref: "<sha>"}

# mob.exs
config :mob, :plugins, [..., :mob_markdown]
# unsigned until it's released:
config :mob, :acknowledge_unsafe_plugins, [..., :mob_markdown]
```

Then `mix deps.get` and `mix mob.deploy --native` on each platform: the view
is native code. mob_dev's generated bootstraps register it (Android
`MobPluginBootstrap.registerAll`, iOS `mob_register_plugins()`); the app
needs no code of its own. Needs mob ~> 0.9 and mob_dev 0.7.29 or later.

## Cost

Each view takes one of mob's native component slots (256 per app; past that
a view renders nothing). A view re-parses only when its `text` or style
changes, so a long finished reply costs nothing on the next render; a
streaming one re-parses on each update.

## Development

```bash
mix setup
mix test
mix mob.validate_plugin
# the native sources, as CI compiles them:
xcrun --sdk iphonesimulator swiftc -typecheck -warnings-as-errors \
  -target arm64-apple-ios17.0-simulator -import-objc-header ci/ios/Bridging-Header.h \
  priv/native/ios/MobMarkdownView.swift
gradle -p ci/android compileDebugKotlin   # Gradle 8.2, an Android SDK
```

## Licence

MIT (`LICENSE`). Markwon is Apache 2.0, fetched by the host's Gradle build;
see `NOTICE`.
