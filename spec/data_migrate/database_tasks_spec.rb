# frozen_string_literal: true

require "spec_helper"

describe DataMigrate::DatabaseTasks do
  let(:subject) { DataMigrate::DatabaseTasks }
  let(:migration_path) { "spec/db/migrate" }
  let(:data_migrations_path) {
    DataMigrate.config.data_migrations_path
  }
  let(:db_config) do
    {
      adapter: "sqlite3",
      database: "spec/db/test.db"
    }
  end

  before do
    # In a normal Rails installation, db_dir would defer to
    # Rails.application.config.paths["db"].first
    # @see https://github.com/rails/rails/blob/a7d49ef78c36df2d1ca876451f30915ada1079a5/activerecord/lib/active_record/tasks/database_tasks.rb#L54
    allow(subject).to receive(:db_dir).and_return("db")
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:db_dir).and_return("db")
  end

  before do
    allow(DataMigrate::Tasks::DataMigrateTasks).to receive(:migrations_paths) {
      data_migrations_path
    }
    ActiveRecord::Base.establish_connection(db_config)
    if Gem::Dependency.new("rails", ">= 6.1").match?("rails", Gem.loaded_specs["rails"].version)
      hash_config = ActiveRecord::DatabaseConfigurations::HashConfig.new('test', 'test', db_config)
      config_obj = ActiveRecord::DatabaseConfigurations.new([hash_config])
      allow(ActiveRecord::Base).to receive(:configurations).and_return(config_obj)
    else
      ActiveRecord::Base.configurations[:test] = db_config
    end
  end

  context "migrations" do
    after do
      ActiveRecord::Migration.drop_table("data_migrations") rescue nil
      ActiveRecord::Migration.drop_table("schema_migrations") rescue nil
    end

    before do
      ActiveRecord::SchemaMigration.create_table

      allow(DataMigrate::SchemaMigration).to receive(:migrations_paths) {
        migration_path
      }
      allow(DataMigrate::DatabaseTasks).to receive(:data_migrations_path) {
        data_migrations_path
      }.at_least(:once)
    end

    describe :past_migrations do
      it "returns past migration records" do
        subject.forward
        migrations = subject.past_migrations
        expect(migrations.count).to eq 1
        expect(migrations.first[:version]).to eq 20091231235959
      end

      it "shows nothing without any migrations" do
        migrations = subject.past_migrations
        expect(migrations.count).to eq 0
      end
    end

    describe :forward do

      it "run forward default amount of times" do
        subject.forward
        versions = DataMigrate::DataSchemaMigration.normalized_versions
        expect(versions.count).to eq(1)
      end

      it "run forward defined number of times" do
        subject.forward(2)
        versions = DataMigrate::DataSchemaMigration.normalized_versions
        expect(versions.count).to eq(1)
        expect(versions.first).to eq "20091231235959"
        versions = ActiveRecord::SchemaMigration.normalized_versions
        expect(versions.count).to eq(1)
        expect(versions.first).to eq "20131111111111"
      end
    end
  end

  describe ".run_migration" do
    context "with db_config provided" do
      let(:second_db_config) do
        ActiveRecord::DatabaseConfigurations::HashConfig.new('test', 'test1', { database: "spec/db/test.db", adapter: "sqlite3", version: "20230601191158", migrations_paths: "thing/db/migration"})
      end

      context 'for a schema migration' do
        let(:migration) do
          { version: "20230601191158", kind: :schema, direction: :up }
        end

        it 'runs schema migration' do
          allow(::DataMigrate::SchemaMigration).to receive(:run)
          subject.run_migration(migration, :up, second_db_config)
          expect(::DataMigrate::SchemaMigration).to have_received(:run).with(
            :up, "thing/db/migration", "20230601191158"
          )
        end
      end

      context 'for a data migration' do
        let(:migration) do
          { version: "20230601191158", kind: :data, direction: :up }
        end

        it 'runs data migration' do
          allow(::DataMigrate::DataMigrator).to receive(:run)
          subject.run_migration(migration, :up, second_db_config)
          expect(::DataMigrate::DataMigrator).to have_received(:run).with(:up, "spec/db/data", "20230601191158")
        end
      end
    end

    context "with no custom db_config" do
      context 'for a schema migration' do
        let(:migration) do
          { version: "20230601191158", kind: :schema, direction: :up }
        end

        it 'runs migration with original config' do
          allow(DataMigrate::SchemaMigration).to receive(:migrations_paths).and_return(migration_path)
          allow(::DataMigrate::SchemaMigration).to receive(:run)
          subject.run_migration(migration, :up)
          expect(::DataMigrate::SchemaMigration).to have_received(:run).with(
            :up, "spec/db/migrate", "20230601191158"
          )
        end
      end

      context 'for a data migration' do
        let(:migration) do
          { version: "20230601191158", kind: :data, direction: :up }
        end

        it 'runs migration with original config' do
          allow(DataMigrate::SchemaMigration).to receive(:migrations_paths).and_return(migration_path)
          allow(::DataMigrate::DataMigrator).to receive(:run)
          subject.run_migration(migration, :up)
          expect(::DataMigrate::DataMigrator).to have_received(:run).with(:up, "spec/db/data", "20230601191158")
        end
      end
    end
  end

end
