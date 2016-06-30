require 'spec_helper'
require 'rake'

describe 'gitlab:app namespace rake task' do
  let(:enable_registry) { true }

  before :all do
    Rake.application.rake_require 'tasks/gitlab/task_helpers'
    Rake.application.rake_require 'tasks/gitlab/backup'
    Rake.application.rake_require 'tasks/gitlab/shell'
    Rake.application.rake_require 'tasks/gitlab/db'

    # empty task as env is already loaded
    Rake::Task.define_task :environment

    # We need this directory to run `gitlab:backup:create` task
    FileUtils.mkdir_p('public/uploads')
  end

  before do
    stub_container_registry_config(enabled: enable_registry)
  end

  def run_rake_task(task_name)
    Rake::Task[task_name].reenable
    Rake.application.invoke_task task_name
  end

  def reenable_backup_sub_tasks
    %w{db repo uploads builds artifacts lfs registry}.each do |subtask|
      Rake::Task["gitlab:backup:#{subtask}:create"].reenable
    end
  end

  describe 'backup_restore' do
    before do
      # avoid writing task output to spec progress
      allow($stdout).to receive :write
    end

    context 'gitlab version' do
      before do
        allow(Dir).to receive(:glob).and_return([])
        allow(Dir).to receive(:chdir)
        allow(File).to receive(:exists?).and_return(true)
        allow(Kernel).to receive(:system).and_return(true)
        allow(FileUtils).to receive(:cp_r).and_return(true)
        allow(FileUtils).to receive(:mv).and_return(true)
        allow(Rake::Task["gitlab:shell:setup"]).
          to receive(:invoke).and_return(true)
        ENV['force'] = 'yes'
      end

      let(:gitlab_version) { Gitlab::VERSION }

      it 'should fail on mismatch' do
        allow(YAML).to receive(:load_file).
          and_return({ gitlab_version: "not #{gitlab_version}" })

        expect { run_rake_task('gitlab:backup:restore') }.
          to raise_error(SystemExit)
      end

      it 'should invoke restoration on match' do
        allow(YAML).to receive(:load_file).
          and_return({ gitlab_version: gitlab_version })
        expect(Rake::Task['gitlab:db:drop_tables']).to receive(:invoke)
        expect(Rake::Task['gitlab:backup:db:restore']).to receive(:invoke)
        expect(Rake::Task['gitlab:backup:repo:restore']).to receive(:invoke)
        expect(Rake::Task['gitlab:backup:builds:restore']).to receive(:invoke)
        expect(Rake::Task['gitlab:backup:uploads:restore']).to receive(:invoke)
        expect(Rake::Task['gitlab:backup:artifacts:restore']).to receive(:invoke)
        expect(Rake::Task['gitlab:backup:lfs:restore']).to receive(:invoke)
        expect(Rake::Task['gitlab:backup:registry:restore']).to receive(:invoke)
        expect(Rake::Task['gitlab:shell:setup']).to receive(:invoke)
        expect { run_rake_task('gitlab:backup:restore') }.not_to raise_error
      end
    end

  end # backup_restore task

  describe 'backup_create' do
    def tars_glob
      Dir.glob(File.join(Gitlab.config.backup.path, '*_gitlab_backup.tar'))
    end

    def create_backup
      puts "creating backup"
      FileUtils.rm tars_glob
      puts "after deleting the old tars"

      # Redirect STDOUT and run the rake task
      #orig_stdout = $stdout
      #puts "after getting stdout (stdout is #{orig_stdout})"
      #$stdout = StringIO.new
      #puts "after assigning new stdout"
      reenable_backup_sub_tasks
      puts "after reenable"
      run_rake_task('gitlab:backup:create')
      puts "after run rake task"
      reenable_backup_sub_tasks
      puts "after reenable again"
      #$stdout = orig_stdout
      #puts "after restoring stdout"

      @backup_tar = tars_glob.first
      puts "after backup, now glob is #{tars_glob.inspect} and backup_tar is #{@backup_tar}"
    end

    context 'tar creation' do
      before do
        create_backup
      end

      after do
        FileUtils.rm(@backup_tar)
      end

      context 'archive file permissions' do
        it 'should set correct permissions on the tar file' do
          expect(File.exist?(@backup_tar)).to be_truthy
          expect(File::Stat.new(@backup_tar).mode.to_s(8)).to eq('100600')
        end

        context 'with custom archive_permissions' do
          before do
            allow(Gitlab.config.backup).to receive(:archive_permissions).and_return(0651)
            # We created a backup in a before(:all) so it got the default permissions.
            # We now need to do some work to create a _new_ backup file using our stub.
            FileUtils.rm(@backup_tar)
            create_backup
          end

          it 'uses the custom permissions' do
            expect(File::Stat.new(@backup_tar).mode.to_s(8)).to eq('100651')
          end
        end
      end

      it 'should set correct permissions on the tar contents' do
        tar_contents, exit_status = Gitlab::Popen.popen(
          %W{tar -tvf #{@backup_tar} db uploads.tar.gz repositories builds.tar.gz artifacts.tar.gz lfs.tar.gz registry.tar.gz}
        )
        expect(exit_status).to eq(0)
        expect(tar_contents).to match('db/')
        expect(tar_contents).to match('uploads.tar.gz')
        expect(tar_contents).to match('repositories/')
        expect(tar_contents).to match('builds.tar.gz')
        expect(tar_contents).to match('artifacts.tar.gz')
        expect(tar_contents).to match('lfs.tar.gz')
        expect(tar_contents).to match('registry.tar.gz')
        expect(tar_contents).not_to match(/^.{4,9}[rwx].* (database.sql.gz|uploads.tar.gz|repositories|builds.tar.gz|artifacts.tar.gz|registry.tar.gz)\/$/)
      end

      it 'should delete temp directories' do
        temp_dirs = Dir.glob(
          File.join(Gitlab.config.backup.path, '{db,repositories,uploads,builds,artifacts,lfs,registry}')
        )

        expect(temp_dirs).to be_empty
      end

      context 'registry disabled' do
        let(:enable_registry) { false }

        it 'should not create registry.tar.gz' do
          tar_contents, exit_status = Gitlab::Popen.popen(
            %W{tar -tvf #{@backup_tar}}
          )
          expect(exit_status).to eq(0)
          expect(tar_contents).not_to match('registry.tar.gz')
        end
      end
    end

    context 'multiple repository storages' do
      puts "context"
      let(:project_a) { puts "creating a"; create(:project, repository_storage: 'default') }
      let(:project_b) { puts "creating b"; create(:project, repository_storage: 'custom') }

      before do
        puts "before"
        FileUtils.mkdir('tmp/tests/default_storage')
        FileUtils.mkdir('tmp/tests/custom_storage')
        puts "after creating dirs"
        storages = {
          'default' => 'tmp/tests/default_storage',
          'custom' => 'tmp/tests/custom_storage'
        }
        allow(Gitlab.config.repositories).to receive(:storages).and_return(storages)
        puts "after mocking storages"

        # Create the projects now, after mocking the settings but before doing the backup
        project_a
        project_b
        puts "after creating projects"

        create_backup
        puts "end before"
      end

      after do
        puts "after"
        FileUtils.rm_rf('tmp/tests/default_storage')
        FileUtils.rm_rf('tmp/tests/custom_storage')
        FileUtils.rm(@backup_tar)
        puts "end after"
      end

      it 'should include repositories in all repository storages' do
        puts "it example"
        tar_contents, exit_status = Gitlab::Popen.popen(
          %W{tar -tvf #{@backup_tar} repositories}
        )
        puts "after command"
        expect(exit_status).to eq(0)
        puts "expect(exit_status).to eq(0)"
        expect(tar_contents).to match("repositories/#{project_a.path_with_namespace}.bundle")
        puts "first match"
        expect(tar_contents).to match("repositories/#{project_b.path_with_namespace}.bundle")
        puts "end it"
      end
      puts "end context"
    end
  end # backup_create task

  describe "Skipping items" do
    def tars_glob
      Dir.glob(File.join(Gitlab.config.backup.path, '*_gitlab_backup.tar'))
    end

    before :all do
      @origin_cd = Dir.pwd

      reenable_backup_sub_tasks

      FileUtils.rm tars_glob

      # Redirect STDOUT and run the rake task
      orig_stdout = $stdout
      $stdout = StringIO.new
      ENV["SKIP"] = "repositories,uploads"
      run_rake_task('gitlab:backup:create')
      $stdout = orig_stdout

      @backup_tar = tars_glob.first
    end

    after :all do
      FileUtils.rm(@backup_tar)
      Dir.chdir @origin_cd
    end

    it "does not contain skipped item" do
      tar_contents, _exit_status = Gitlab::Popen.popen(
        %W{tar -tvf #{@backup_tar} db uploads.tar.gz repositories builds.tar.gz artifacts.tar.gz lfs.tar.gz registry.tar.gz}
      )

      expect(tar_contents).to match('db/')
      expect(tar_contents).to match('uploads.tar.gz')
      expect(tar_contents).to match('builds.tar.gz')
      expect(tar_contents).to match('artifacts.tar.gz')
      expect(tar_contents).to match('lfs.tar.gz')
      expect(tar_contents).to match('registry.tar.gz')
      expect(tar_contents).not_to match('repositories/')
    end

    it 'does not invoke repositories restore' do
      allow(Rake::Task['gitlab:shell:setup']).
        to receive(:invoke).and_return(true)
      allow($stdout).to receive :write

      expect(Rake::Task['gitlab:db:drop_tables']).to receive :invoke
      expect(Rake::Task['gitlab:backup:db:restore']).to receive :invoke
      expect(Rake::Task['gitlab:backup:repo:restore']).not_to receive :invoke
      expect(Rake::Task['gitlab:backup:uploads:restore']).not_to receive :invoke
      expect(Rake::Task['gitlab:backup:builds:restore']).to receive :invoke
      expect(Rake::Task['gitlab:backup:artifacts:restore']).to receive :invoke
      expect(Rake::Task['gitlab:backup:lfs:restore']).to receive :invoke
      expect(Rake::Task['gitlab:backup:registry:restore']).to receive :invoke
      expect(Rake::Task['gitlab:shell:setup']).to receive :invoke
      expect { run_rake_task('gitlab:backup:restore') }.not_to raise_error
    end
  end
end # gitlab:app namespace
