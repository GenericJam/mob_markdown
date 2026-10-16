# AGENTS.md — orientation for AI agents working on mob_markdown

You're in **mob_markdown**, a Mob plugin (a native UI component) that renders Markdown in the platform's own text view: `MobMarkdown.view/3` → `MobMarkdown.View` (a `Mob.Component`) → Markwon in a selectable `TextView` on Android, Foundation's Markdown parser in a selectable `UITextView` on iOS. The README has the props and the host setup; this file is what you need to change it safely.

**Also read [`~/code/mob/AGENTS.md`](../mob/AGENTS.md)** for the system view and [`~/code/mob/guides/plugins.md`](../mob/guides/plugins.md) for plugin signing and activation.

> **Keep this file current.** When you change the props contract, either native side, or hit a gotcha, fix it here in the same commit.

## Anatomy

* `lib/mob_markdown.ex` — `view/3` (the node), `openable?/1` (the link filter), `open/1` (the configured opener).
* `lib/mob_markdown/view.ex` — the component: forwards every prop but `:module`/`:id`; handles `"open_link"`.
* `priv/native/android/MobMarkdown.kt` — `io.mob.markdown.MobMarkdownView(props, send)`, the Compose factory; one Markwon per style; faces from `res/font` by name.
* `priv/native/ios/MobMarkdownView.swift` — `MobMarkdownView(props:)`, a `UIViewRepresentable` over a TextKit 1 `UITextView`; `MobMdRenderer` walks Foundation's runs (blocks, lists, quotes, inline HTML subset, tables as box-drawing text).
* `priv/mob_plugin.exs` — one `ui_components` entry (`ios.swift_struct`, `android.factory`: mob_dev's generated bootstraps register it), `bridge_kt` (copies the Kotlin file), the Markwon Gradle deps, `swift_files`.
* `ci/` — compile checks for the native files: a Gradle library project over `priv/native/android` (versions of mob_new's app template), and a stand-in bridging header for `swiftc -typecheck`.

## Rules that matter here

1. **The text is untrusted.** Links go to the BEAM and open only through `openable?/1`. Never let a native view open a URL itself (Android: the `linkResolver`; iOS: the `primaryActionFor` / `menuConfigurationFor` delegate methods).
2. **iOS gets no `send`.** mob_dev's iOS bootstrap instantiates `MobMarkdownView(props: props)` and drops the registry's send closure, so the view sends events itself: `mob_send_component_event(component_handle, …)`, the call MobNativeViewRegistry's closure makes. `component_handle` is in the props (`Mob.Component` adds it). If mob_dev starts passing `send`, switch to it.
3. **Re-render only on change.** Both sides keep what they last rendered and re-parse only when `text` or the style changes (iOS also when the width in code columns changes). A streaming host re-renders often; keep it that way.
4. **iOS tables and rules are measured in code-face columns.** Everything inside a table is the code face (bold for the header), or the columns don't line up.
5. **Native changes need a native build and a device.** `mix test` covers the Elixir half; CI only compiles the native files. Re-verify in a host app on an Android emulator and an iOS simulator (`mix mob.deploy --native --device <id>`): headings, lists, a table wider than the phone, code, a quote, a link tap, text selection, a theme change.
6. **No compile-time `~r//` literals** in `lib/` (the device runs OTP 28).

## Testing

```bash
mix test
mix format --check-formatted
mix credo --strict
mix mob.validate_plugin
```

No self-test yet: nothing on the device can say whether a native view key is registered without a screen showing it, so `mix mob.validate_plugin` warns.

## Release

Not released yet; no release workflow. Version bumps and Hex publishes need Kevin's approval. When it's released, add the first-party `release.yml` (as in `mob_biometric`), which signs with the shared mob key (`priv/mob_plugin.pub` is that key) and publishes on a version bump. Never commit `priv/mob_plugin.sig`.
