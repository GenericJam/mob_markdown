defmodule MobMarkdownTest do
  # async: false: the link opener is app-wide config.
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MobDev.Plugin.{Manifest, Validator}

  @plugin_dir Path.expand("..", __DIR__)

  describe "openable?/1" do
    test "web and mail links open, whatever the scheme's case" do
      for url <- ~w(http://example.com https://example.com/a?b=1 HTTPS://EXAMPLE.COM mailto:a@b.c),
          do: assert(MobMarkdown.openable?(url), url)
    end

    test "every other scheme, and a link without one, is refused" do
      urls = [
        "javascript:alert(1)",
        "intent://scan/#Intent;scheme=zxing;end",
        "file:///etc/passwd",
        "tel:+15551234",
        "bezalel://open",
        "data:text/html,hi",
        "example.com",
        "/relative",
        ""
      ]

      for url <- urls, do: refute(MobMarkdown.openable?(url), url)
    end
  end

  describe "a tapped link" do
    setup do
      test = self()
      Application.put_env(:mob_markdown, :open_url, &send(test, {:opened, &1}))
      on_exit(fn -> Application.delete_env(:mob_markdown, :open_url) end)
    end

    test "opens a web link and drops anything else" do
      socket = mounted()

      assert {:noreply, ^socket} =
               MobMarkdown.View.handle_event("open_link", %{"url" => "https://x.org"}, socket)

      assert_received {:opened, "https://x.org"}

      assert {:noreply, ^socket} =
               MobMarkdown.View.handle_event("open_link", %{"url" => "file:///x"}, socket)

      refute_received {:opened, _}
    end

    test "an event without a URL string is ignored" do
      socket = mounted()

      for payload <- [%{}, %{"url" => 1}],
          do:
            assert(
              {:noreply, ^socket} = MobMarkdown.View.handle_event("open_link", payload, socket)
            )

      refute_received {:opened, _}
    end
  end

  describe "view/3" do
    test "a native view of MobMarkdown.View carrying the text and the style" do
      node =
        MobMarkdown.view(:reply, "**hi**",
          text_size: 15,
          ios: %{font_regular: "Face-Regular"},
          text: "ignored"
        )

      assert node.type == :native_view

      assert node.props == %{
               module: MobMarkdown.View,
               id: :reply,
               text: "**hi**",
               text_size: 15,
               ios: %{font_regular: "Face-Regular"}
             }
    end

    test "the component hands every prop but its identity to the native view" do
      props = %{module: MobMarkdown.View, id: :reply, text: "x", text_color: 0xFF000000}
      {:ok, socket} = MobMarkdown.View.mount(props, Mob.Socket.new(MobMarkdown.View))

      assert MobMarkdown.View.render(socket.assigns) == %{text: "x", text_color: 0xFF000000}
    end
  end

  describe "plugin manifest" do
    setup do
      {:ok, manifest} = Manifest.load(@plugin_dir)
      %{manifest: manifest}
    end

    test "passes the pre-publish validator", %{manifest: m} do
      assert {:ok, ^m} = Manifest.validate(m)
      assert %{errors: []} = Validator.validate_plugin(m, @plugin_dir)
    end

    test "both platforms register the view under the key mob renders it by", %{manifest: m} do
      # Mob.Component's native key: the module name, dots → underscores.
      key = MobMarkdown.View |> inspect() |> String.replace(".", "_")
      assert [component] = m.ui_components
      assert component.ios.view_module == key
      assert component.android.composable == key
      assert component.ios.swift_struct == "MobMarkdownView"
      assert component.android.factory == "io.mob.markdown.MobMarkdownView"
    end
  end

  defp mounted do
    {:ok, socket} =
      MobMarkdown.View.mount(%{text: "[a](https://x.org)"}, Mob.Socket.new(MobMarkdown.View))

    socket
  end
end
