# frozen_string_literal: true

require 'timeout'

RSpec.describe Raintron::Launcher do
  after { ENV.delete('RAINTRON_APP_ROOT') }

  describe '#start_server' do
    it 'sets RAINTRON_APP_ROOT before forking, so the child (and PwdOverride) inherit it' do
      launcher = described_class.new(title: 'Test', app_root: '/tmp/some_app') { nil }
      seen_app_root = nil
      allow(launcher).to receive(:fork) do
        seen_app_root = ENV.fetch('RAINTRON_APP_ROOT', nil)
        42
      end

      launcher.start_server

      expect(seen_app_root).to eq('/tmp/some_app')
    end

    it 'runs the server block inside the forked child, after applying shims' do
      ran_block = false
      launcher = described_class.new(title: 'Test', app_root: '/tmp/some_app') { ran_block = true }
      allow(launcher).to receive(:fork) do |&block|
        block.call
        42
      end
      allow(Raintron::Shims).to receive(:apply!)
      allow(Raintron).to receive(:packed?).and_return(false)
      allow(launcher).to receive(:stop_with_parent)

      launcher.start_server

      expect(ran_block).to be true
      expect(Raintron::Shims).to have_received(:apply!).with(packed: false)
    end

    it 'does not require webview_ruby (that only happens in #open_window, in the parent)' do
      launcher = described_class.new(title: 'Test', app_root: '/tmp/some_app') { nil }
      allow(launcher).to receive(:fork).and_return(42)

      launcher.start_server

      expect($LOADED_FEATURES.grep(/webview_ruby/)).to be_empty
    end
  end

  describe 'the forked server' do
    # The window's process can end without returning to Ruby, like macOS's [NSApp terminate:] when its window closes.
    it 'stops itself once the window process is gone' do
      launcher = described_class.new(title: 'Test') { nil }
      reader, writer = IO.pipe
      window = fork do
        fork do
          launcher.send(:stop_with_parent, Process.ppid)
          writer.puts(Process.pid)
          sleep
        end
        sleep
      end
      server = reader.gets.to_i

      Process.kill('KILL', window)
      Process.wait(window)

      expect(Timeout.timeout(3) { sleep 0.1 while running?(server) }).to be_nil
    end

    def running?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    end
  end

  describe '#open_window' do
    it "opens a browser window where there's no web view, like Linux without WebKitGTK" do
      launcher = described_class.new(title: 'Test', port: 4133) { nil }
      window = instance_double(Raintron::BrowserWindow, run: true)
      allow(launcher).to receive(:require).and_call_original
      allow(launcher).to receive(:require).with('webview_ruby').and_raise(LoadError, 'libwebkit2gtk-4.0.so.37: not found')
      allow(Raintron::BrowserWindow).to receive(:new).and_return(window)

      launcher.open_window

      expect(Raintron::BrowserWindow).to have_received(:new)
        .with(title: 'Test', app_url: 'http://127.0.0.1:4133/', size: [900, 600])
    end
  end

  describe '#stop_server' do
    it 'sends TERM and waits for the pid' do
      launcher = described_class.new(title: 'Test') { nil }
      launcher.instance_variable_set(:@pid, 123)
      allow(Process).to receive(:kill).with('TERM', 123)
      allow(Process).to receive(:wait).with(123)

      launcher.stop_server

      expect(Process).to have_received(:kill).with('TERM', 123)
      expect(Process).to have_received(:wait).with(123)
    end

    it 'is a no-op if the server was never started' do
      launcher = described_class.new(title: 'Test') { nil }
      expect { launcher.stop_server }.not_to raise_error
    end

    it 'swallows Errno::ESRCH (process already gone)' do
      launcher = described_class.new(title: 'Test') { nil }
      launcher.instance_variable_set(:@pid, 123)
      allow(Process).to receive(:kill).and_raise(Errno::ESRCH)

      expect { launcher.stop_server }.not_to raise_error
    end

    it 'swallows Errno::ECHILD (already reaped)' do
      launcher = described_class.new(title: 'Test') { nil }
      launcher.instance_variable_set(:@pid, 123)
      allow(Process).to receive(:kill)
      allow(Process).to receive(:wait).and_raise(Errno::ECHILD)

      expect { launcher.stop_server }.not_to raise_error
    end
  end

  describe '#loading_url' do
    it 'opens the rain cloud page as a data: URL, with the app as its fragment for the page to switch to' do
      launcher = described_class.new(title: 'Test', host: '127.0.0.1', port: 4133) { nil }

      data, fragment = launcher.loading_url.delete_prefix('data:text/html;charset=utf-8;base64,').split('#', 2)

      expect(data.unpack1('m0').force_encoding('UTF-8')).to eq(File.read(described_class::LOADING_PAGE))
      expect(fragment).to eq('http://127.0.0.1:4133/')
    end
  end
end
