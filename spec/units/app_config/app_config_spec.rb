# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Raintron::AppConfig do
  describe '.host and .port' do
    it 'reads values from config/config.yaml when present' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, 'config'))
        File.write(File.join(dir, 'config', 'config.yaml'), "host: '0.0.0.0'\nport: 9999\n")

        expect(described_class.host(app_root: dir)).to eq('0.0.0.0')
        expect(described_class.port(app_root: dir)).to eq(9999)
      end
    end

    it 'falls back to defaults when config/config.yaml is absent' do
      Dir.mktmpdir do |dir|
        expect(described_class.host(app_root: dir)).to eq(Raintron::AppConfig::DEFAULT_HOST)
        expect(described_class.port(app_root: dir)).to eq(Raintron::AppConfig::DEFAULT_PORT)
      end
    end

    it 'falls back to defaults for keys missing from an existing config file' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, 'config'))
        File.write(File.join(dir, 'config', 'config.yaml'), "web_root: './public'\n")

        expect(described_class.host(app_root: dir)).to eq(Raintron::AppConfig::DEFAULT_HOST)
        expect(described_class.port(app_root: dir)).to eq(Raintron::AppConfig::DEFAULT_PORT)
      end
    end
  end

  describe '.titlebar' do
    it 'reads titlebar from config/config.yaml' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, 'config'))
        File.write(File.join(dir, 'config', 'config.yaml'), "titlebar: hidden\n")

        expect(described_class.titlebar(app_root: dir)).to eq('hidden')
      end
    end

    it 'keeps the native title bar by default' do
      Dir.mktmpdir do |dir|
        expect(described_class.titlebar(app_root: dir)).to eq('native')
      end
    end
  end
end
