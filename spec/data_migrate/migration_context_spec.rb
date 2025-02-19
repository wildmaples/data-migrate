# frozen_string_literal: true

require "spec_helper"

describe DataMigrate::DataMigrator do
  let(:context) { DataMigrate::MigrationContext.new("spec/db/data") }
  let(:schema_context) { ActiveRecord::MigrationContext.new("spec/db/migrate", ActiveRecord::Base.connection.schema_migration) }

  before do
    ActiveRecord::SchemaMigration.create_table
    DataMigrate::DataSchemaMigration.create_table
  end

  after do
    ActiveRecord::Migration.drop_table("data_migrations") rescue nil
    ActiveRecord::Migration.drop_table("schema_migrations") rescue nil
  end

  describe "migrate" do
    it "migrates existing file" do
      context.migrate(nil)
      context.migrations_status
      versions = DataMigrate::DataSchemaMigration.normalized_versions
      expect(versions.count).to eq(2)
      expect(versions).to include("20091231235959")
      expect(versions).to include("20171231235959")
    end

    it "undo migration" do
      context.migrate(nil)
      context.run(:down, 20171231235959)
      versions = DataMigrate::DataSchemaMigration.normalized_versions
      expect(versions.count).to eq(1)
      expect(versions).to include("20091231235959")
    end

    it "does not do anything if migration is undone twice" do
      context.migrate(nil)
      expect {
        context.run(:down, 20171231235959)
      }.to output(/Undoing SuperUpdate/).to_stdout
      expect {
        context.run(:down, 20171231235959)
      }.not_to output(/Undoing SuperUpdate/).to_stdout
    end

    it "runs a specific migration" do
      context.run(:up, 20171231235959)
      versions = DataMigrate::DataSchemaMigration.normalized_versions
      expect(versions.count).to eq(1)
      expect(versions).to include("20171231235959")
    end

    it "does not do anything if migration is ran twice" do
      expect {
        context.run(:up, 20171231235959)
      }.to output(/Doing SuperUpdate/).to_stdout
      expect {
        context.run(:down, 20171231235959)
      }.not_to output(/Doing SuperUpdate/).to_stdout
    end

    it "alerts for an invalid specific migration" do
      expect {
        context.run(:up, 201712312)
      }.to raise_error(
        ActiveRecord::UnknownMigrationVersionError,
        /No migration with version number 201712312/
      )
    end

    it "rolls back latest migration" do
      context.migrate(nil)
      expect {
        context.rollback
      }.to output(/Undoing SuperUpdate/).to_stdout
      versions = DataMigrate::DataSchemaMigration.normalized_versions
      expect(versions.count).to eq(1)
      expect(versions).to include("20091231235959")
    end

    it "rolls back 2 migrations" do
      context.migrate(nil)
      schema_context.migrate(nil)
      expect {
        context.rollback(2)
      }.to output(/Undoing SomeName/).to_stdout
      versions = DataMigrate::DataSchemaMigration.normalized_versions
      expect(versions.count).to eq(0)
    end

    it "rolls back 2 migrations" do
      context.migrate(nil)
      expect {
        context.rollback(2)
      }.to output(/Undoing SomeName/).to_stdout
      versions = DataMigrate::DataSchemaMigration.normalized_versions
      expect(versions.count).to eq(0)
    end
  end
end
