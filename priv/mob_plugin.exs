%{
  name: :mob_markdown,
  mob_version: "~> 0.9",
  plugin_spec_version: 1,
  description:
    "Native Markdown views: Markwon in a selectable TextView (Android), Foundation's " <>
      "Markdown parser in a selectable UITextView (iOS)",
  ui_components: [
    %{
      tag: "MobMarkdown",
      atom: :mob_markdown,
      props: [
        :text,
        :text_size,
        :line_height,
        :text_color,
        :heading_color,
        :link_color,
        :code_color,
        :code_background,
        :quote_color,
        :rule_color,
        :selection_color,
        :font_regular,
        :font_bold,
        :font_italic,
        :font_bold_italic,
        :font_heading,
        :font_code
      ],
      # Registry key = the component's Elixir module, dots → underscores
      # (MobMarkdown.View → "MobMarkdown_View"). mob_dev's generated
      # bootstraps register both sides: iOS `MobMarkdownView(props:)`,
      # Android `io.mob.markdown.MobMarkdownView(props, send)`.
      ios: %{view_module: "MobMarkdown_View", swift_struct: "MobMarkdownView"},
      android: %{composable: "MobMarkdown_View", factory: "io.mob.markdown.MobMarkdownView"}
    }
  ],
  android: %{
    # The Compose factory and the Markwon setup. No bridge_class: the
    # factory above is fully qualified, so nothing calls register().
    bridge_kt: "priv/native/android/MobMarkdown.kt",
    # Markwon 4.6.2 (Apache 2.0, see NOTICE).
    gradle_deps: [
      "io.noties.markwon:core:4.6.2",
      "io.noties.markwon:ext-tables:4.6.2",
      "io.noties.markwon:ext-strikethrough:4.6.2",
      "io.noties.markwon:linkify:4.6.2",
      "io.noties.markwon:html:4.6.2"
    ]
  },
  ios: %{
    swift_files: ["priv/native/ios/MobMarkdownView.swift"],
    # Table cells are measured and wrapped with CoreText's typesetter.
    frameworks: ["CoreText"]
  },
  host_requirements: [
    "mob_dev >= 0.7.29: the generated MobPluginBootstrap (Android) and " <>
      "mob_register_plugins (iOS) register the view; the host's MainActivity calls " <>
      "MobPluginBootstrap.registerAll(this) and its AppDelegate mob_register_plugins()."
  ]
}
