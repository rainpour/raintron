# frozen_string_literal: true

require 'json'

module Raintron
  # The system's dialogs, which the page opens, on macOS. window.raintron.pickFolder is true where there's one, and
  # window.raintronPickFolder() opens a folder picker in front of the window, which calls window.raintronFolderPicked(path)
  # with the folder chosen, or null when it's cancelled, as a bound call can't answer the page itself. Elsewhere the
  # page asks for a folder some other way, like a path typed in.
  #
  # Required only by Launcher#open_window, after webview_ruby, in the window's process.
  module Dialogs
    module_function

    def bind(webview)
      dialogs = platform_dialogs
      return unless dialogs

      webview.bind('raintronPickFolder') { |*| answer_folder(webview) { dialogs.pick_folder } }
      webview.init('window.raintron = Object.assign(window.raintron ?? {}, { pickFolder: true })')
    end

    # A bound call that raises closes the window, so the page's told nothing was chosen instead.
    def answer_folder(webview)
      path = begin
        yield
      rescue StandardError
        nil
      end
      webview.eval("window.raintronFolderPicked?.(#{JSON.generate(path)})")
    end

    def platform_dialogs
      return unless RbConfig::CONFIG['host_os'].match?(/darwin/)

      require_relative 'mac_dialogs'
      MacDialogs
    end
  end
end
