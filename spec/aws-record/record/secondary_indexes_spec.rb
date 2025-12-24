# frozen_string_literal: true

require 'spec_helper'

module Aws
  module Record
    describe 'SecondaryIndexes' do
      let(:klass) do
        Class.new do
          include(Aws::Record)

          set_table_name('TestTable')
          integer_attr(:forum_id, hash_key: true)
          integer_attr(:post_id, range_key: true)
          string_attr(:forum_name)
          string_attr(:post_title)
          integer_attr(:author_id, database_attribute_name: 'a_id')
          string_attr(:author_name, database_attribute_name: 'a_name')
          string_attr(:post_body)
        end
      end

      let(:api_requests) { [] }

      let(:stub_client) do
        requests = api_requests
        client = Aws::DynamoDB::Client.new(stub_responses: true)
        client.handle do |context|
          requests << context.params
          @handler.call(context)
        end
        client
      end

      context 'Local Secondary Index' do
        describe '#local_secondary_index' do
          it 'allows you to define a local secondary index on the model' do
            klass.local_secondary_index(
              :title,
              range_key: :post_title,
              projection: {
                projection_type: 'ALL'
              }
            )
            expect(klass.local_secondary_indexes[:title]).not_to eq(nil)
          end

          it 'requires that a range key is provided' do
            expect {
              klass.local_secondary_index(
                :fail,
                projection: { projection_type: 'ALL' }
              )
            }.to raise_error(ArgumentError)
          end

          it 'requires use of an attribute that exists in the model' do
            expect {
              klass.local_secondary_index(
                :fail,
                range_key: :missingno,
                projection: { projection_type: 'ALL' }
              )
            }.to raise_error(ArgumentError)
          end
        end

        describe '#local_secondary_indexes_for_migration' do
          it 'correctly translates database names for migration' do
            klass.local_secondary_index(
              :author,
              range_key: :author_id,
              projection: {
                projection_type: 'ALL'
              }
            )
            migration = klass.local_secondary_indexes_for_migration
            expect(migration.size).to eq(1)
            expect(migration.first).to eq(
              index_name: :author,
              key_schema: [
                { key_type: 'HASH', attribute_name: 'forum_id' },
                { key_type: 'RANGE', attribute_name: 'a_id' }
              ],
              projection: { projection_type: 'ALL' }
            )
          end
        end
      end

      context 'Global Secondary Indexes' do
        describe '#global_secondary_index' do
          it 'allows you to define a global secondary index on the model' do
            klass.global_secondary_index(
              :author,
              hash_key: :forum_name,
              range_key: :author_name,
              projection: {
                projection_type: 'ALL'
              }
            )
            expect(klass.global_secondary_indexes[:author]).not_to eq(nil)
          end

          it 'requires that a hash key is provided' do
            expect {
              klass.global_secondary_index(
                :fail,
                projection: { projection_type: 'ALL' }
              )
            }.to raise_error(ArgumentError)
          end

          it 'requires that the hash key exists in the model' do
            expect {
              klass.global_secondary_index(
                :fail,
                hash_key: :missingno,
                projection: { projection_type: 'ALL' }
              )
            }.to raise_error(ArgumentError)
          end

          it 'requires that the range key exists in the model' do
            expect {
              klass.global_secondary_index(
                :fail,
                hash_key: :forum_name,
                range_key: :missingno,
                projection: { projection_type: 'ALL' }
              )
            }.to raise_error(ArgumentError)
          end
        end

        describe '#global_secondary_indexes_for_migration' do
          it 'correctly translates database names for migration' do
            klass.global_secondary_index(
              :author,
              hash_key: :forum_name,
              range_key: :author_name,
              projection: {
                projection_type: 'ALL'
              }
            )
            migration = klass.global_secondary_indexes_for_migration
            expect(migration.size).to eq(1)
            expect(migration.first).to eq(
              index_name: :author,
              key_schema: [
                { key_type: 'HASH', attribute_name: 'forum_name' },
                { key_type: 'RANGE', attribute_name: 'a_name' }
              ],
              projection: { projection_type: 'ALL' }
            )
          end
        end
      end
    end

    describe 'inheritance support' do
      let(:parent_model) do
        Class.new do
          include(Aws::Record)

          integer_attr(:id, hash_key: true)
          string_attr(:name, range_key: true)
          string_attr(:message)
        end
      end

      let(:child_model) do
        Class.new(parent_model) do
          include(Aws::Record)

          string_attr(:foo)
          string_attr(:bar)
        end
      end

      it 'should have child model inherit secondary indexes from parent model' do
        parent_model.local_secondary_index(:local_index, hash_key: :id, range_key: :message)
        parent_model.global_secondary_index(:global_index, hash_key: :name, range_key: :message)

        expect(child_model.local_secondary_indexes).to eq(parent_model.local_secondary_indexes)
        expect(child_model.global_secondary_indexes).to eq(parent_model.global_secondary_indexes)
      end

      it 'allows the child model override parent indexes' do
        parent_model.local_secondary_index(:local_index, hash_key: :id, range_key: :message)
        parent_model.global_secondary_index(:global_index, hash_key: :name, range_key: :message)
        child_model.local_secondary_index(:local_index, hash_key: :id, range_key: :foo)
        child_model.global_secondary_index(:global_index, hash_key: :bar, range_key: :foo)

        expect(child_model.local_secondary_indexes).to eq(local_index: { hash_key: :id, range_key: :foo })
        expect(child_model.global_secondary_indexes).to eq(global_index: { hash_key: :bar, range_key: :foo })
      end
    end
  end
end
