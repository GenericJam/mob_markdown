# Changelog

All notable changes to **mob_markdown** are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `MobMarkdown.view/3` and `MobMarkdown.View`: a native Markdown view,
  extracted from Operator's. Android: Markwon 4.6.2 (tables, strikethrough,
  autolinks, inline HTML) in selectable `TextView`s. iOS: Foundation's
  Markdown parser in read-only selectable `UITextView`s, tables as
  box-drawing text in the code face (measured in points, so Hebrew cells
  line up; right-to-left cells isolated).
- Tables scroll sideways: the prose wraps to the view's width, and each
  table sits at its natural width (a column up to 32 code columns, longer
  cells wrapping) in a horizontal scroller of its own; a table narrower
  than the view doesn't scroll. Links inside Android table cells are
  tappable.
- Style props: sizes, colours (ARGB), and six faces (regular, bold, italic,
  bold italic, heading, code) by platform name; a missing italic is
  slanted from the upright face; code defaults to the system monospace.
- Link taps open only `http`, `https` and `mailto` (`MobMarkdown.openable?/1`),
  through `Mob.Device.open_url/1` or `config :mob_markdown, :open_url`.
- Registration by mob_dev's generated bootstraps (`ui_components` with
  `ios.swift_struct` and `android.factory`): no host code.
