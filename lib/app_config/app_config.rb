# frozen_string_literal: true

require 'yaml'

module Raintron
  # Reads a consuming app's own config/config.yaml so bin/desktop and `raintron press`
  # stay in sync with whatever `rain server` actually uses, instead of hardcoding
  # host/port separately from the app's real configuration.
  module AppConfig
    DEFAULT_HOST = '127.0.0.1'
    DEFAULT_PORT = 4133

    def self.host(app_root: Dir.pwd)
      read(app_root).fetch('host', DEFAULT_HOST)
    end

    def self.port(app_root: Dir.pwd)
      read(app_root).fetch('port', DEFAULT_PORT)
    end

    # "hidden" for a window without a title bar, on macOS, which the page takes the place of; see WindowChrome.
    def self.titlebar(app_root: Dir.pwd)
      read(app_root).fetch('titlebar', 'native')
    end

    def self.read(app_root)
      path = File.join(app_root, 'config', 'config.yaml')
      return {} unless File.exist?(path)

      YAML.safe_load_file(path) || {}
    end
  end
end
