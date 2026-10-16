# Changelog

All notable changes to **mob_markdown** are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `MobMarkdown.view/3` and `MobMarkdown.View`: a native Markdown view,
  extracted from Operator's. Android: Markwon 4.6.2 (tables, strikethrough,
  autolinks, inline HTML) in a selectable `TextView`, tables wrapping their
  cells to the view's width. iOS: Foundation's Markdown parser in a
  read-only selectable `UITextView`, tables as box-drawing text in the code
  face fitted to the view's width.
- Style props: sizes, colours (ARGB), and six faces (regular, bold, italic,
  bold italic, heading, code) by platform name; a missing italic is
  slanted from the upright face; code defaults to the system monospace.
- Link taps open only `http`, `https` and `mailto` (`MobMarkdown.openable?/1`),
  through `Mob.Device.open_url/1` or `config :mob_markdown, :open_url`.
- Registration by mob_dev's generated bootstraps (`ui_components` with
  `ios.swift_struct` and `android.factory`): no host code.
