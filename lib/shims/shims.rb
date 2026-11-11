# frozen_string_literal: true

module Raintron
  # Applies the environment-compatibility patches a desktop-launched server needs.
  # Never applied by a plain `require 'raintron'` -- only Launcher#start_server calls
  # this, and only inside the forked server child, so a normal `rain server` dev
  # workflow with raintron in the Gemfile is completely unaffected by its presence.
  #
  # Even the packed shims are individually inert on an ordinary filesystem (the chdir
  # and Prism fallbacks only fire on ENOENT; PwdOverride only overrides Dir.pwd when
  # TEBAKO_APP_ROOT is set), so the `packed:` gate here is belt-and-suspenders on top
  # of that, not the only thing preventing interference with normal development.
  module Shims
    def self.apply!(packed: packed?)
      require_relative 'packed_fs_shim' if packed
    end

    # Tebako doesn't document any Ruby-level "am I packed" marker (checked directly
    # against its README/spec docs) -- but every file loaded from inside a packed image,
    # gem code included, resolves to a path containing "/__tfs__/" (confirmed directly
    # against this session's own crash logs from a real pressed build, e.g.
    # ".../__tfs__/lib/ruby/gems/.../raindeer-0.9.9/lib/raindeer/boot.rb"). Checking
    # THIS file's own __dir__ is self-contained -- it doesn't depend on the consuming
    # app's entry point cooperating -- but it is pinned to a specific Tebako version's
    # internal mount name, not a documented stable API, so RAINTRON_FORCE_PACKED is an
    # escape hatch if a future Tebako release ever changes it.
    def self.packed?
      return true if ENV['RAINTRON_FORCE_PACKED']

      __dir__.include?('/__tfs__/')
    end
  end
end
