defmodule MobMarkdown.View do
  @moduledoc """
  The `Mob.Component` behind `MobMarkdown.view/2`. Its native views register
  under `"MobMarkdown_View"`: Android's `io.mob.markdown.MobMarkdownView`
  (Markwon in a selectable `TextView`), iOS's `MobMarkdownView` (Foundation's
  Markdown parser in a read-only selectable `UITextView`).

  The props reach the native view as they are (see `MobMarkdown` for the
  list). A tapped link arrives as `"open_link"` with `%{"url" => url}` and is
  opened only when `MobMarkdown.openable?/1` says so: the text is usually a
  model's, so `intent:`, `file:`, `javascript:` and app-scheme links are
  dropped.
  """
  use Mob.Component

  require Logger

  @impl true
  def mount(props, socket),
    do: {:ok, Mob.Socket.assign(socket, :props, Map.drop(props, [:module, :id]))}

  @impl true
  def render(%{props: props}), do: props

  @impl true
  def handle_event("open_link", %{"url" => url}, socket) when is_binary(url) do
    if MobMarkdown.openable?(url) do
      MobMarkdown.open(url)
    else
      Logger.info("[mob_markdown] not opening a #{inspect(URI.parse(url).scheme)} link")
    end

    {:noreply, socket}
  end

  def handle_event(_event, _payload, socket), do: {:noreply, socket}
end
