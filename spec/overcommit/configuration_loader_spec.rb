# frozen_string_literal: true

require 'spec_helper'

describe Overcommit::ConfigurationLoader do
  let(:output) { StringIO.new }
  let(:logger) { Overcommit::Logger.new(output) }

  describe '#load_repo_config' do
    subject { described_class.new(logger).load_repo_config }

    context 'when repo does not contain a configuration file' do
      around do |example|
        repo do
          example.run
        end
      end

      it 'returns the default configuration' do
        subject.should == described_class.default_configuration
      end
    end

    context 'when repo contains a configuration file' do
      let(:config_contents) { <<-CFG }
        plugin_directory: 'some-directory'
      CFG

      around do |example|
        repo do
          File.open('.overcommit.yml', 'w') { |f| f.write(config_contents) }
          example.run
        end
      end

      it 'loads the file' do
        Overcommit::ConfigurationLoader.any_instance.
          should_receive(:load_file).
          with(File.expand_path('.overcommit.yml'))
        subject
      end

      it 'merges the loaded file with the default configuration' do
        subject.plugin_directory.should == File.expand_path('some-directory')
      end

      context 'and the configuration file contains a hook with no `enabled` option' do
        let(:config_contents) { <<-CFG }
          PreCommit:
            ScssLint:
              command: ['bundle', 'exec', 'scss-lint']
        CFG

        it 'displays a warning' do
          subject
          output.string.should =~ /PreCommit::ScssLint.*not.*enabled/i
        end
      end
    end

    context 'when repo only contains a repo level configuration file' do
      let(:config_contents) { <<-CFG }
        PreCommit:
          Rubocop:
            enabled: true
      CFG

      around do |example|
        repo do
          File.open('.overcommit.yml', 'w') { |f| f.write(config_contents) }
          example.run
        end
      end

      it 'includes default settings' do
        subject
        subject.for_hook('CapitalizedSubject', 'CommitMsg').should include('enabled' => true)
      end

      it 'includes .overwrite.yml configs' do
        subject
        subject.for_hook('Rubocop', 'PreCommit').should include('enabled' => true)
      end
    end

    context 'when repo also contains a local configuration file' do
      let(:local_config_contents) { <<-CFG }
        plugin_directory: 'some-different-directory'
      CFG

      around do |example|
        repo do
          File.open('.overcommit.yml', 'w') { |f| f.write(config_contents) }
          File.open('.local-overcommit.yml', 'w') { |f| f.write(local_config_contents) }
          example.run
        end
      end

      let(:config_contents) { <<-CFG }
        PreCommit:
          ScssLint:
            enabled: true
      CFG

      let(:local_config_contents) { <<-CFG }
        PreCommit:
          Rubocop:
            enabled: true
      CFG

      it 'includes default settings' do
        subject
        subject.for_hook('CapitalizedSubject', 'CommitMsg').should include('enabled' => true)
      end

      it 'includes .overwrite.yml configs' do
        subject
        subject.for_hook('ScssLint', 'PreCommit').should include('enabled' => true)
      end

      it 'includes .local-overwrite.yml configs' do
        subject
        subject.for_hook('Rubocop', 'PreCommit').should include('enabled' => true)
      end
    end
  end
end
