# frozen_string_literal: true

require 'socket'
require 'tmpdir'
require 'timeout'
require_relative '../../../lib/launcher/browser_window'

RSpec.describe Raintron::BrowserWindow do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      path = ENV.fetch('PATH')
      ENV['PATH'] = File.join(dir, 'bin')
      ENV['XDG_DATA_HOME'] = File.join(dir, 'data')
      example.run
    ensure
      ENV['PATH'] = path
      ENV.delete('XDG_DATA_HOME')
    end
  end

  # A stand-in for a browser or opener on the PATH, which writes the arguments it was run with.
  def program(name)
    FileUtils.mkdir_p(File.join(@dir, 'bin'))
    File.join(@dir, 'bin', name).tap do |path|
      File.write(path, "#!/bin/sh\nprintf '%s\\n' \"$@\" > #{File.join(@dir, "#{name}.args")}\n")
      File.chmod(0o755, path)
    end
  end

  def args_of(name)
    file = File.join(@dir, "#{name}.args")
    Timeout.timeout(3) { sleep 0.05 until File.exist?(file) && !File.empty?(file) }
    File.read(file).lines(chomp: true)
  end

  around do |example|
    @server = TCPServer.new('127.0.0.1', 0)
    @app_url = "http://127.0.0.1:#{@server.addr[1]}/"
    example.run
  ensure
    @server.close
  end

  def window
    described_class.new(title: 'My App', app_url: @app_url, size: [900, 600])
  end

  it "opens the app in a Chromium-based browser's app window, with the app's own profile, until it closes" do
    program('chromium')

    expect(window.run).to be(true)
    expect(args_of('chromium')).to include("--app=#{@app_url}", '--window-size=900,600',
                                           "--user-data-dir=#{File.join(@dir, 'data', 'raintron', 'my-app')}")
  end

  it 'opens the app in a tab of the default browser without one' do
    program('xdg-open')

    expect(window.run).to be(false)
    expect(args_of('xdg-open')).to eq([@app_url])
  end

  it 'says what it needs when there is no browser to open' do
    expect { window.run }.to raise_error(Raintron::Error, /needs WebKitGTK, a Chromium-based browser or xdg-open/)
  end
end
