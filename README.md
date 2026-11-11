# Raintron

<a href="https://github.com/raindeer-rb/raintron" title="GitHub"><img src="https://img.shields.io/badge/github-%23121011.svg?style=for-the-badge&logo=github&logoColor=white" alt="GitHub repo" height="18"></a>

Raintron enables desktop applications to be made with web technologies and Ruby. It uses [Tebako](https://github.com/tamatebako/tebako) so no system Ruby is required on the end user's machine. It can also be used with the [Raindeer](https://github.com/raindeer-rb/raindeer) web framework as a back-end server for your front-end web app.

**✨ Features:**
- Uses the OS's existing webview
- Much smaller app size due to not bundling Chromium
- Similar levels of performance
- [Raindeer](https://github.com/raindeer-rb/raindeer) integration

## Installation

Add to an existing app's Gemfile:

```ruby
gem 'raintron'
```

Run commands:
```
bundle install
bundle exec raintron install
bundle exec bin/desktop
```

If `bundle install` fails there, see **Prerequisites** below, or run `bundle exec raintron doctor` for a diagnosis.

## CLI

### `raintron install :app_name`

Wires desktop-app capability into the app in the current directory. Idempotent -- re-running skips files that already exist.

Writes: `bin/desktop` (thin -- all real logic is `Raintron.launch`, from this gem), `<Name>.app/` (a macOS dev bundle: `Info.plist`, a `launch` script, and an icon), `icons/<name>.{icns,ico,png,desktop}`, and `.github/workflows/build.yml` (a Tebako packing CI matrix).

App name resolution: positional argument → `--name` → current directory's name → interactive prompt (only if a tty and nothing else was given, so non-interactive/CI installs never hang).

Flags: `--name NAME`, `--width N` (default 900), `--height N` (default 600), `--bundle-id ID` (default `dev.local.<name>`), `--icon PATH` (a source logo to convert instead of generating a placeholder), `--force` (overwrite existing files).

### `raintron press`

Wraps `tebako press` with sensible defaults, so you don't need to memorize its flags. Ruby version resolves from `.ruby-version` → `.tool-versions` → the running interpreter; output defaults to `dist/<app_name>-<os>`.

Flags: `--ruby VERSION`, `--output PATH`.

### `raintron icons :app_name`

Regenerates icons standalone (e.g. after swapping in a new logo), without touching anything else `install` writes.

Flags: `--name NAME`, `--source PATH`.

### `raintron doctor`

Checks native-toolkit prerequisites for `webview_ruby` on demand.

## Prerequisites

`webview_ruby` needs a working C++ toolchain and your platform's GUI toolkit headers:

- **macOS**: Xcode Command Line Tools (`xcode-select --install`).
- **Linux**: GTK3 + WebKit2GTK dev headers, e.g. Debian/Ubuntu: `sudo apt-get install -y build-essential libgtk-3-dev libwebkit2gtk-4.0-dev`.
- **Windows**: not supported today -- confirmed via a real CI run, not assumed. `webview_ruby` does attempt a Windows build (via `ffi-compiler`'s generic MinGW path), but `webview.h`'s Windows/Edge backend `#include`s `winrt/Windows.Foundation.Collections.h`, a C++/WinRT header that isn't available under the MinGW toolchain RubyInstaller for Windows ships -- it needs MSVC + the Windows SDK instead. Independent of Tebako's own Windows gap.

`raintron install` inserts a toolkit check at the top of your Gemfile, which prints an actionable message instead of a cryptic compiler error buried in `bundle install` output -- but only protects *subsequent* installs, since the very first compile of `webview_ruby` happens before `raintron install` can ever run. Run `raintron doctor` beforehand if you want to check first. (This check is a small self-contained snippet, not a call into raintron's own code: Bundler resolves and activates gems *after* evaluating the whole Gemfile, so a Gemfile can't `require` a gem declared in that same Gemfile.)

## Packaging cross-platform (Tebako)

The CI workflow `raintron install` generates presses your app into a single self-contained executable per OS. Two things worth knowing:

- **Linux opens in a browser when GTK3 + WebKit2GTK aren't installed**, so a packed executable needs nothing beside it -- `webview_ruby`'s Linux backend loads them at runtime, and Tebako can't statically bundle a GUI toolkit away. Without them, the app opens in a Chromium-based browser's app window (Chrome, Chromium, Brave or Edge), a window without tabs or an address bar, with a profile of its own, and stops when it closes; with none of those, in a tab of the default browser, running until Ctrl+C. Either way it opens once the server answers, without the rain cloud, as Chromium won't let a `data:` page reach `127.0.0.1`. macOS and Windows use the OS's own built-in WebKit/WebView2.
- **Windows is best-effort** in the generated CI (`continue-on-error`), because both Tebako's own Windows release leg and `webview_ruby`'s native build are incomplete today. It'll start passing on its own once either upstream gap closes.

## How it works

- `Raintron.launch` forks the Raindeer server into a real child process rather than a `Thread` in the same process: `webview_ruby`'s native window loop holds Ruby's GVL for as long as the window is open, which would otherwise starve a `Thread`-based server. A separate OS process also sidesteps Tebako's packed executables having no resolvable script path for `Process.spawn` to exec.
- The window opens at once on a loading page, Raindown's rain cloud (`lib/launcher/loading.html`), while the server boots, then switches to the app when it answers. The page is self-contained, opened as a `data:` URL with the app's URL as its fragment, as nothing's serving yet; it's built by `bin/build-loading` in [raindown-app](../raindown-app), whose grid draws it.
- `titlebar: hidden` in the app's `config/config.yaml` gives the window no title bar on macOS, like Obsidian's: the page runs under a transparent title bar with only the traffic lights over it (`Raintron::WindowChrome`, through `webview_get_window` and the Objective-C runtime). The page is told with `window.raintron = { titlebar: 'hidden' }`, and calls `window.raintronDragWindow()` on a mouse down where the window should drag from, since WebKit takes the title bar's mouse events. Other platforms keep their title bar.
- `webview_ruby` is required only in the parent process, only after the fork: macOS's Cocoa/WebKit frameworks are not fork-safe.
- Merely adding `gem 'raintron'` to a Gemfile changes nothing about `rain server` -- shims and `webview_ruby` only ever load from inside `Raintron.launch`'s forked child, never on a plain `require 'raintron'`.
- Environment-compatibility shims (`lib/shims/`) patch around real, specific gaps between Raindeer's assumptions (a controlling terminal exists; `Dir.pwd` == the app root; gems can `chdir` to glob their own lib directories) and what a packed executable's environment actually provides (none of that). Each patch is a narrow, documented fallback -- read the comments in those files before changing boot order.
- Icon generation (`lib/icons/`) is pure Ruby with zero external dependencies: hand-rolled `.png`/`.ico`/`.icns` writers (stdlib `zlib` only, no ImageMagick/Pillow/`sips`/`iconutil`), plus a hand-rolled PNG decoder and box-average resizer for converting a supplied source logo into the required icon sizes.
