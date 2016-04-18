# Copyright 2015-2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not
# use this file except in compliance with the License. A copy of the License is
# located at
#
#     http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied. See the License for the specific language governing permissions
# and limitations under the License.

require 'spec_helper'

module Aws
  module Record
    describe "ItemOperations" do

      let(:klass) do
        Class.new do
          include(Aws::Record)
          set_table_name("TestTable")
          integer_attr(:id, hash_key: true)
          date_attr(:date, range_key: true)
          string_attr(:body)
          boolean_attr(:bool, database_attribute_name: "my_boolean")
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

      describe "#save!" do
        it 'can save an item that does not yet exist to Amazon DynamoDB' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.body = 'Hello!'
          item.save!
          expect(api_requests).to eq([{
            table_name: "TestTable",
            item: {
              "id" => { n: "1" },
              "date" => { s: "2015-12-14" },
              "body" => { s: "Hello!" }
            },
            condition_expression: "attribute_not_exists(#H)"\
              " and attribute_not_exists(#R)",
            expression_attribute_names: {
              "#H" => "id",
              "#R" => "date"
            }
          }])
        end

        it 'raises an error when you try to save! without setting keys' do
          klass.configure_client(client: stub_client)
          no_keys = klass.new
          expect { no_keys.save! }.to raise_error(
            Errors::KeyMissing,
            "Missing required keys: id, date"
          )
          no_hash = klass.new
          no_hash.date = "2015-12-15"
          expect { no_hash.save! }.to raise_error(
            Errors::KeyMissing,
            "Missing required keys: id"
          )
          no_range = klass.new
          no_range.id = 5
          expect { no_range.save! }.to raise_error(
            Errors::KeyMissing,
            "Missing required keys: date"
          )
          # None of this should have reached the API
          expect(api_requests).to eq([])
        end
      end

      describe "#save" do
        it 'can save an item that does not yet exist to Amazon DynamoDB' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.body = 'Hello!'
          item.save
          expect(api_requests).to eq([{
            table_name: "TestTable",
            item: {
              "id" => { n: "1" },
              "date" => { s: "2015-12-14" },
              "body" => { s: "Hello!" }
            },
            condition_expression: "attribute_not_exists(#H)"\
              " and attribute_not_exists(#R)",
            expression_attribute_names: {
              "#H" => "id",
              "#R" => "date"
            }
          }])
        end

        it 'will call #put_item without conditions if :force is included' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.body = 'Hello!'
          item.save(force: true)
          expect(api_requests).to eq([{
            table_name: "TestTable",
            item: {
              "id" => { n: "1" },
              "date" => { s: "2015-12-14" },
              "body" => { s: "Hello!" }
            }
          }])
        end

        it 'will call #update_item for changes to existing items' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.body = 'Hello!'
          item.clean! # I'm claiming that it is this way in the DB now.
          item.body = 'Goodbye!'
          item.save
          expect(api_requests).to eq([{
            table_name: "TestTable",
            key: {
              "id" => { n: "1" },
              "date" => { s: "2015-12-14" }
            },
            attribute_updates: {
              "body" => {
                value: { s: "Goodbye!" },
                action: "PUT"
              }
            }
          }])
        end

        it 'populates the error array with an error message if check fails' do
          stub_client.stub_responses(:put_item,
            'ConditionalCheckFailedException'
          )
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.body = 'Hello!'
          expect(item.save).to be_falsy
          expect(item.errors.size).to eq(1)
          expect(api_requests).to eq([{
            table_name: "TestTable",
            item: {
              "id" => { n: "1" },
              "date" => { s: "2015-12-14" },
              "body" => { s: "Hello!" }
            },
            condition_expression: "attribute_not_exists(#H)"\
              " and attribute_not_exists(#R)",
            expression_attribute_names: {
              "#H" => "id",
              "#R" => "date"
            }
          }])
        end

        it 'does not raise an error when you try to save without setting keys' do
          klass.configure_client(client: stub_client)
          no_keys = klass.new
          expect { no_keys.save }.not_to raise_error

          no_hash = klass.new
          no_hash.date = "2015-12-15"
          expect { no_hash.save }.not_to raise_error

          no_range = klass.new
          no_range.id = 5
          expect { no_range.save }.not_to raise_error

          # None of this should have reached the API
          expect(api_requests).to eq([])
        end
      end

      describe "#valid?" do
        it 'is valid with successful save to Amazon DynamoDB' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.body = 'Hello!'
          item.save
          expect(item.valid?).to be_truthy
        end

        it 'is invalid when you try to save without setting keys' do
          klass.configure_client(client: stub_client)
          no_keys = klass.new
          no_keys.save
          expect(no_keys.valid?).to be_falsy

          no_hash = klass.new
          no_hash.date = "2015-12-15"
          no_hash.save
          expect(no_hash.valid?).to be_falsy

          no_range = klass.new
          no_range.id = 5
          no_range.save
          expect(no_range.valid?).to be_falsy

          # None of this should have reached the API
          expect(api_requests).to eq([])
        end

        it 'is valid after fixing invalid save state' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.save
          expect(item.valid?).to be_falsy

          item.id = 1
          item.date = '2015-12-14'
          item.body = 'Hello!'
          item.save
          expect(item.valid?).to be_truthy

          # None of this should have reached the API
          expect(api_requests).not_to be_empty
        end
      end

      describe "#find" do
        it 'can read an item from Amazon DynamoDB' do
          stub_client.stub_responses(:get_item,
            {
              item: {
                "id" => 5,
                "date" => "2015-12-15",
                "my_boolean" => true
              }
            })
          klass.configure_client(client: stub_client)
          find_opts = { id: 5, date: '2015-12-15' }
          ret = klass.find(find_opts)
          expect(api_requests).to eq([{
            table_name: "TestTable",
            key: {
              "id" => { n: "5" },
              "date" => { s: "2015-12-15" }
            }
          }])
          expect(ret).to be_a(klass)
          expect(ret.id).to eq(5)
          expect(ret.date).to eq(Date.parse('2015-12-15'))
          expect(ret.bool).to be(true)
        end

        it 'enforces that the required keys are present' do
          klass.configure_client(client: stub_client)
          find_opts = { id: 5 }
          expect { klass.find(find_opts) }.to raise_error(
            Aws::Record::Errors::KeyMissing
          )
        end
      end

      describe "#delete!" do
        it 'can delete an item from Amazon DynamoDB' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 3
          item.date = "2015-12-17"
          expect(item.delete!).to be(true)
          expect(api_requests).to eq([{
            table_name: "TestTable",
            key: {
              "id" => { n: "3" },
              "date" => { s: "2015-12-17" }
            }
          }])
        end
      end

    end
  end
end
