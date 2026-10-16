defmodule MobMarkdown do
  @moduledoc """
  Native Markdown for Mob apps: CommonMark plus GitHub tables and
  strikethrough, autolinked URLs, drawn by the platform's own text view so
  inline styles wrap like prose and the text selects and copies.

      MobMarkdown.view(:reply_1, "## Exodus 31\\n\\n**Bezalel** is *filled*.",
        text_size: 15,
        text_color: 0xFF1E1A16
      )

  Android renders with [Markwon](https://github.com/noties/Markwon) in
  selectable `TextView`s. iOS parses with Foundation's
  `AttributedString(markdown:)` into read-only selectable `UITextView`s;
  UIKit has no table layout for attributed text, so tables are box-drawing
  text in the code face. On both, the prose wraps to the view's width and
  each table sits at its natural width (a column up to 32 code columns) in a
  horizontal scroller of its own: a table wider than the view scrolls
  sideways.

  ## Props

  Everything but `:id` is optional.

    * `:text`: the Markdown source
    * `:text_size` (sp / pt, default 15), `:line_height` (a multiplier,
      default 1.4)
    * Colours, ARGB integers (`0xAARRGGBB`): `:text_color`,
      `:heading_color`, `:link_color`, `:code_color`, `:code_background`,
      `:quote_color` (block quotes and list markers), `:rule_color` (rules
      and table borders), `:selection_color`
    * Faces, each the name the platform loads it by (an iOS PostScript
      name, an Android `res/font` resource name), `""` or absent for the
      system face: `:font_regular`, `:font_bold`, `:font_italic`,
      `:font_bold_italic`, `:font_heading` (default: the bold face),
      `:font_code` (default: the system monospace). A missing italic face
      is slanted from the regular or bold one.

  Faces differ per platform, so pass them in mob's platform blocks, which
  the renderer resolves before the props reach the phone:

      MobMarkdown.view(:reply_1, text,
        ios: %{font_regular: "InstrumentSans-Regular"},
        android: %{font_regular: "instrumentsans_regular"}
      )

  ## Links

  A tapped link is opened only when `openable?/1` allows it (`http`,
  `https`, `mailto`), by `Mob.Device.open_url/1`, or by the function in
  `config :mob_markdown, :open_url` (a 1-arity function or
  `{module, function}`).

  ## Cost

  Each view is one of mob's native component slots (256 per app); a native
  view re-renders only when its `text` or style props change.
  """

  @openable ~w(http https mailto)

  @doc """
  A `Mob.UI.native_view` node that renders `text` as Markdown. `id` must be
  unique on the screen and stable across renders (the view keeps its state
  under it).
  """
  @spec view(atom(), String.t(), keyword() | map()) :: map()
  def view(id, text, props \\ []) when is_atom(id) and is_binary(text) do
    Mob.UI.native_view(MobMarkdown.View, props |> Map.new() |> Map.merge(%{id: id, text: text}))
  end

  @doc "Whether a tapped link may be opened: web and mail links only."
  @spec openable?(String.t()) :: boolean()
  def openable?(url) when is_binary(url),
    do: String.downcase(URI.parse(url).scheme || "") in @openable

  @doc false
  @spec open(String.t()) :: term()
  def open(url) do
    case Application.get_env(:mob_markdown, :open_url) do
      nil -> Mob.Device.open_url(url)
      fun when is_function(fun, 1) -> fun.(url)
      {module, function} -> apply(module, function, [url])
    end
  end
end
