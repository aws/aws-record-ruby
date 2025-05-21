# frozen_string_literal: true

require 'spec_helper'

module Aws
  module Record
    describe 'ItemOperations' do
      let(:klass) do
        Class.new do
          include(Aws::Record)
          set_table_name('TestTable')
          integer_attr(:id, hash_key: true)
          date_attr(:date, range_key: true, database_attribute_name: 'MyDate')
          string_attr(:body)
          string_attr(:persist_on_nil, persist_nil: true)
          list_attr(:list_nil_to_empty, default_value: [])
          list_attr(:list_nil_as_nil, persist_nil: true)
          list_attr(:list_no_nil_persist)
          map_attr(:map_nil_to_empty, default_value: {})
          map_attr(:map_nil_as_nil, persist_nil: true)
          map_attr(:map_no_nil_persist)
          boolean_attr(:bool, database_attribute_name: 'my_boolean')
          epoch_time_attr(:ttl)
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

      describe '#save!' do
        it 'can save an item that does not yet exist to Amazon DynamoDB' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.body = 'Hello!'
          item.ttl = Time.parse('2018-07-09 22:02:12 UTC')
          item.save!
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                item: {
                  'id' => { n: '1' },
                  'MyDate' => { s: '2015-12-14' },
                  'body' => { s: 'Hello!' },
                  'list_nil_to_empty' => { l: [] },
                  'map_nil_to_empty' => { m: {} },
                  'ttl' => { n: '1531173732' }
                },
                condition_expression: 'attribute_not_exists(#H) ' \
                                      'and attribute_not_exists(#R)',
                expression_attribute_names: {
                  '#H' => 'id',
                  '#R' => 'MyDate'
                }
              }
            ]
          )
        end

        it 'passes through options to #update_item and #put_item' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.body = 'Hello!'
          # new record
          item.save!(table_name: 'notused', return_values: 'ALL_OLD')
          # forced
          item.save!(force: true, table_name: 'notused', return_values: 'UPDATED_OLD')
          # not updated tuple
          item.save!(table_name: 'notused', return_values: 'ALL_NEW')
          # updated tuple
          item.clean!
          item.body = 'Goodbye!'
          item.save!(table_name: 'notused', return_values: 'UPDATED_NEW')

          expect(api_requests).to match [
            hash_including(table_name: 'TestTable', return_values: 'ALL_OLD'),
            hash_including(table_name: 'TestTable', return_values: 'UPDATED_OLD'),
            hash_including(table_name: 'TestTable', return_values: 'ALL_NEW'),
            hash_including(table_name: 'TestTable', return_values: 'UPDATED_NEW')
          ]
        end

        it 'raises an error when you try to save! without setting keys' do
          klass.configure_client(client: stub_client)
          no_keys = klass.new
          expect { no_keys.save! }.to raise_error(
            Errors::KeyMissing,
            'Missing required keys: id, date'
          )
          no_hash = klass.new
          no_hash.date = '2015-12-15'
          expect { no_hash.save! }.to raise_error(
            Errors::KeyMissing,
            'Missing required keys: id'
          )
          no_range = klass.new
          no_range.id = 5
          expect { no_range.save! }.to raise_error(
            Errors::KeyMissing,
            'Missing required keys: date'
          )
          # None of this should have reached the API
          expect(api_requests).to eq([])
        end
      end

      describe '#save' do
        it 'can save an item that does not yet exist to Amazon DynamoDB' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.body = 'Hello!'
          expect(item.new_record?).to be(true)
          item.save
          expect(item.new_record?).to be(false)
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                item: {
                  'id' => { n: '1' },
                  'MyDate' => { s: '2015-12-14' },
                  'body' => { s: 'Hello!' },
                  'list_nil_to_empty' => { l: [] },
                  'map_nil_to_empty' => { m: {} }
                },
                condition_expression: 'attribute_not_exists(#H) ' \
                                      'and attribute_not_exists(#R)',
                expression_attribute_names: {
                  '#H' => 'id',
                  '#R' => 'MyDate'
                }
              }
            ]
          )
        end

        it 'will call #put_item without conditions if :force is included' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.body = 'Hello!'
          item.save(force: true)
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                item: {
                  'id' => { n: '1' },
                  'MyDate' => { s: '2015-12-14' },
                  'body' => { s: 'Hello!' },
                  'list_nil_to_empty' => { l: [] },
                  'map_nil_to_empty' => { m: {} }
                }
              }
            ]
          )
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
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                key: {
                  'id' => { n: '1' },
                  'MyDate' => { s: '2015-12-14' }
                },
                update_expression: 'SET #UE_A = :ue_a',
                expression_attribute_names: {
                  '#UE_A' => 'body'
                },
                expression_attribute_values: {
                  ':ue_a' => { s: 'Goodbye!' }
                }
              }
            ]
          )
        end

        it 'will call #update_item with pass through update expression for existing items' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.body = 'Hello!'
          item.clean! # I'm claiming that it is this way in the DB now.
          item.save(
            update_expression: 'SET #S = if_not_exists(#S, :s)',
            expression_attribute_names: { '#S' => 'body' },
            expression_attribute_values: { ':s' => 'Goodbye!' }
          )
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                key: {
                  'id' => { n: '1' },
                  'MyDate' => { s: '2015-12-14' }
                },
                update_expression: 'SET #S = if_not_exists(#S, :s)',
                expression_attribute_names: {
                  '#S' => 'body'
                },
                expression_attribute_values: {
                  ':s' => { s: 'Goodbye!' }
                }
              }
            ]
          )
        end

        it 'passes through options to #update_item and #put_item' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.body = 'Hello!'
          # new record
          item.save(table_name: 'notused', return_values: 'ALL_OLD')
          # forced
          item.save(force: true, table_name: 'notused', return_values: 'UPDATED_OLD')
          # not updated tuple
          item.save(table_name: 'notused', return_values: 'ALL_NEW')
          # updated tuple
          item.clean!
          item.body = 'Goodbye!'
          item.save(table_name: 'notused', return_values: 'UPDATED_NEW')

          expect(api_requests).to match [
            hash_including(table_name: 'TestTable', return_values: 'ALL_OLD'),
            hash_including(table_name: 'TestTable', return_values: 'UPDATED_OLD'),
            hash_including(table_name: 'TestTable', return_values: 'ALL_NEW'),
            hash_including(table_name: 'TestTable', return_values: 'UPDATED_NEW')
          ]
        end

        it 'raises an exception when the conditional check fails' do
          stub_client.stub_responses(
            :put_item,
            'ConditionalCheckFailedException'
          )
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.body = 'Hello!'
          expect { item.save }.to raise_error do |error|
            expect(error).to be_a(Errors::ConditionalWriteFailed)
            expect(error.original_error).to be_a(
              Aws::DynamoDB::Errors::ConditionalCheckFailedException
            )
          end
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                item: {
                  'id' => { n: '1' },
                  'MyDate' => { s: '2015-12-14' },
                  'body' => { s: 'Hello!' },
                  'list_nil_to_empty' => { l: [] },
                  'map_nil_to_empty' => { m: {} }
                },
                condition_expression: 'attribute_not_exists(#H) ' \
                                      'and attribute_not_exists(#R)',
                expression_attribute_names: {
                  '#H' => 'id',
                  '#R' => 'MyDate'
                }
              }
            ]
          )
        end

        it 'raises a key missing error when you try to save without setting keys' do
          klass.configure_client(client: stub_client)
          no_keys = klass.new
          expect { no_keys.save }.to raise_error(
            Errors::KeyMissing,
            'Missing required keys: id, date'
          )

          no_hash = klass.new
          no_hash.date = '2015-12-15'
          expect { no_hash.save }.to raise_error(
            Errors::KeyMissing,
            'Missing required keys: id'
          )

          no_range = klass.new
          no_range.id = 5
          expect { no_range.save }.to raise_error(
            Errors::KeyMissing,
            'Missing required keys: date'
          )

          # None of this should have reached the API
          expect(api_requests).to eq([])
        end

        it 'raises an exception when attribute updates collide with an update expression' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.body = 'Hello!'
          item.clean! # I'm claiming that it is this way in the DB now.
          item.body = 'Goodbye!'
          expect {
            item.save(
              update_expression: 'SET #S = if_not_exists(#S, :s)',
              expression_attribute_names: { '#S' => 'body' },
              expression_attribute_values: { ':s' => 'Goodbye!' }
            )
          }.to raise_error(Aws::Record::Errors::UpdateExpressionCollision)
        end

        context 'modifications to default values' do
          let(:klass_with_defaults) do
            Class.new do
              include(Aws::Record)
              set_table_name('TestTable')
              string_attr(:mykey, hash_key: true)
              map_attr(:dirty_map, default_value: {})
            end
          end

          it 'persists modifications to default values' do
            klass_with_defaults.configure_client(client: stub_client)
            item = klass_with_defaults.new(mykey: 'key')
            item.dirty_map['a'] = 1
            item.save
            expect(api_requests).to eq(
              [
                {
                  table_name: 'TestTable',
                  item: {
                    'mykey' => { s: 'key' },
                    'dirty_map' => {
                      m: { 'a' => { n: '1' } }
                    }
                  },
                  condition_expression: 'attribute_not_exists(#H)',
                  expression_attribute_names: {
                    '#H' => 'mykey'
                  }
                }
              ]
            )
          end
        end
      end

      describe '#find' do
        it 'can read an item from Amazon DynamoDB' do
          stub_client.stub_responses(
            :get_item,
            item: {
              'id' => 5,
              'MyDate' => '2015-12-15',
              'my_boolean' => true
            }
          )
          klass.configure_client(client: stub_client)
          find_opts = { id: 5, date: '2015-12-15' }
          ret = klass.find(find_opts)
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                key: {
                  'id' => { n: '5' },
                  'MyDate' => { s: '2015-12-15' }
                }
              }
            ]
          )
          expect(ret).to be_a(klass)
          expect(ret.id).to eq(5)
          expect(ret.date).to eq(Date.parse('2015-12-15'))
          expect(ret.bool).to be(true)
          expect(ret.new_record?).to be(false)
          expect(ret.persisted?).to be(true)
        end

        it 'enforces that the required keys are present' do
          klass.configure_client(client: stub_client)
          find_opts = { id: 5 }
          expect { klass.find(find_opts) }.to raise_error(
            Aws::Record::Errors::KeyMissing
          )
        end
      end

      describe '#find_with_opts' do
        it 'can read an item from Amazon DynamoDB' do
          stub_client.stub_responses(
            :get_item,
            item: {
              'id' => 5,
              'MyDate' => '2015-12-15',
              'my_boolean' => true
            }
          )
          klass.configure_client(client: stub_client)
          find_opts = { key: { id: 5, date: '2015-12-15' } }
          ret = klass.find_with_opts(find_opts)
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                key: {
                  'id' => { n: '5' },
                  'MyDate' => { s: '2015-12-15' }
                }
              }
            ]
          )
          expect(ret).to be_a(klass)
          expect(ret.id).to eq(5)
          expect(ret.date).to eq(Date.parse('2015-12-15'))
          expect(ret.bool).to be(true)
          expect(ret.new_record?).to be(false)
          expect(ret.persisted?).to be(true)
        end

        it 'enforces that the required keys are present' do
          klass.configure_client(client: stub_client)
          find_opts = { key: { id: 5 } }
          expect { klass.find_with_opts(find_opts) }.to raise_error(
            Aws::Record::Errors::KeyMissing
          )
        end

        it 'passes through options to #get_item' do
          klass.configure_client(client: stub_client)
          find_opts = {
            key: { id: 5, date: '2015-12-15' },
            consistent_read: true
          }
          klass.find_with_opts(find_opts)
          expect(api_requests).to match([hash_including(consistent_read: true)])
        end
      end

      describe '#find_all' do
        let(:keys) do
          [
            { id: 1, date: '2022-12-24' },
            { id: 2, date: '2022-12-25' },
            { id: 3, date: '2022-12-26' }
          ]
        end

        it 'passes the correct client, class and key arguments to BatchRead' do
          klass.configure_client(client: stub_client)
          mock_batch_read = double
          expect(Batch).to receive(:read)
            .with(client: klass.dynamodb_client)
            .and_yield(mock_batch_read).and_return(mock_batch_read)
          keys.each do |key|
            expect(mock_batch_read).to receive(:find).with(klass, key)
          end
          result = klass.find_all(keys)
          expect(result).to eql(mock_batch_read)
        end
      end

      describe '.update' do
        it 'can find and update an item from Amazon DynamoDB' do
          klass.configure_client(client: stub_client)
          klass.update(id: 1, date: '2016-05-18', body: 'New', bool: true)
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                key: {
                  'id' => { n: '1' },
                  'MyDate' => { s: '2016-05-18' }
                },
                update_expression: 'SET #UE_A = :ue_a, #UE_B = :ue_b',
                expression_attribute_names: {
                  '#UE_A' => 'body',
                  '#UE_B' => 'my_boolean'
                },
                expression_attribute_values: {
                  ':ue_a' => { s: 'New' },
                  ':ue_b' => { bool: true }
                }
              }
            ]
          )
        end

        it 'can find item and apply update if update expression provided' do
          klass.configure_client(client: stub_client)
          opts = {
            update_expression: 'SET #S = if_not_exists(#S, :s)',
            expression_attribute_names: {
              '#S' => 'body'
            },
            expression_attribute_values: {
              ':s' => 'Content'
            }
          }
          klass.update({ id: 1, date: '2016-05-18' }, opts)
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                key: {
                  'id' => { n: '1' },
                  'MyDate' => { s: '2016-05-18' }
                },
                update_expression: 'SET #S = if_not_exists(#S, :s)',
                expression_attribute_names: {
                  '#S' => 'body'
                },
                expression_attribute_values: {
                  ':s' => { s: 'Content' }
                }
              }
            ]
          )
        end

        it 'will recognize nil as a removal operation if nil not persisted' do
          klass.configure_client(client: stub_client)
          klass.update(id: 1, date: '2016-07-20', body: nil, persist_on_nil: nil)
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                key: {
                  'id' => { n: '1' },
                  'MyDate' => { s: '2016-07-20' }
                },
                update_expression: 'SET #UE_B = :ue_b REMOVE #UE_A',
                expression_attribute_names: {
                  '#UE_A' => 'body',
                  '#UE_B' => 'persist_on_nil'
                },
                expression_attribute_values: {
                  ':ue_b' => { null: true }
                }
              }
            ]
          )
        end

        it 'will recognize nil as a removal operation even if it is the only operation' do
          klass.configure_client(client: stub_client)
          klass.update(id: 1, date: '2016-07-20', body: nil)
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                key: {
                  'id' => { n: '1' },
                  'MyDate' => { s: '2016-07-20' }
                },
                update_expression: 'REMOVE #UE_A',
                expression_attribute_names: {
                  '#UE_A' => 'body'
                }
              }
            ]
          )
        end

        it 'will upsert even if only keys provided' do
          klass.configure_client(client: stub_client)
          klass.update(id: 1, date: '2016-05-18')
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                key: {
                  'id' => { n: '1' },
                  'MyDate' => { s: '2016-05-18' }
                }
              }
            ]
          )
        end

        it 'raises if any key attributes are missing' do
          klass.configure_client(client: stub_client)
          update_opts = { id: 5, body: 'Fail' }
          expect { klass.update(update_opts) }.to raise_error(
            Aws::Record::Errors::KeyMissing
          )
        end

        it 'raises if both attribute updates and update expression provided' do
          klass.configure_client(client: stub_client)
          opts = {
            update_expression: 'SET #S = if_not_exists(#S, :s)',
            expression_attribute_names: {
              '#S' => 'body'
            },
            expression_attribute_values: {
              ':s' => 'Content'
            }
          }
          expect { klass.update({ id: 1, date: '2016-05-18', bool: false }, opts) }.to raise_error(
            Aws::Record::Errors::UpdateExpressionCollision
          )
        end
      end

      describe '#delete!' do
        it 'can delete an item from Amazon DynamoDB' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 3
          item.date = '2015-12-17'
          expect(item.delete!).to be(true)
          expect(item.destroyed?).to be(true)
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                key: {
                  'id' => { n: '3' },
                  'MyDate' => { s: '2015-12-17' }
                }
              }
            ]
          )
        end

        it 'passes through options to #delete_item' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 3
          item.date = '2015-12-17'
          item.delete!(table_name: 'notused', return_values: 'ALL_OLD')
          expect(api_requests).to include(
            hash_including(table_name: 'TestTable', return_values: 'ALL_OLD')
          )
        end
      end

      describe 'save after delete scenarios' do
        it 'sets destroyed to false after saving a destroyed record' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 3
          item.date = '2015-12-17'
          expect(item.delete!).to be(true)
          expect(item.destroyed?).to be(true)
          item.save
          expect(item.destroyed?).to be(false)
        end
      end

      describe 'nil persistence scenarios' do
        it 'does not persist attributes that are not defined' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.save
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                item: {
                  'id' => { n: '1' },
                  'MyDate' => { s: '2015-12-14' },
                  'list_nil_to_empty' => { l: [] },
                  'map_nil_to_empty' => { m: {} }
                },
                condition_expression: 'attribute_not_exists(#H) ' \
                                      'and attribute_not_exists(#R)',
                expression_attribute_names: {
                  '#H' => 'id',
                  '#R' => 'MyDate'
                }
              }
            ]
          )
        end

        it 'does not persist nil attributes by default' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.body = nil
          item.persist_on_nil = nil
          item.save
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                item: {
                  'id' => { n: '1' },
                  'MyDate' => { s: '2015-12-14' },
                  'persist_on_nil' => { null: true },
                  'list_nil_to_empty' => { l: [] },
                  'map_nil_to_empty' => { m: {} }
                },
                condition_expression: 'attribute_not_exists(#H) ' \
                                      'and attribute_not_exists(#R)',
                expression_attribute_names: {
                  '#H' => 'id',
                  '#R' => 'MyDate'
                }
              }
            ]
          )
        end

        it 'can persist nil list and map attributes as default values' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.list_nil_to_empty = nil
          item.map_nil_to_empty = nil
          item.list_no_nil_persist = nil
          item.map_no_nil_persist = nil
          item.save
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                item: {
                  'id' => { n: '1' },
                  'MyDate' => { s: '2015-12-14' },
                  'list_nil_to_empty' => { l: [] },
                  'map_nil_to_empty' => { m: {} }
                },
                condition_expression: 'attribute_not_exists(#H) ' \
                                      'and attribute_not_exists(#R)',
                expression_attribute_names: {
                  '#H' => 'id',
                  '#R' => 'MyDate'
                }
              }
            ]
          )
        end

        it 'can persist nil list and map attributes as nil' do
          klass.configure_client(client: stub_client)
          item = klass.new
          item.id = 1
          item.date = '2015-12-14'
          item.list_nil_as_nil = nil
          item.map_nil_as_nil = nil
          item.list_no_nil_persist = nil
          item.map_no_nil_persist = nil
          item.save
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                item: {
                  'id' => { n: '1' },
                  'MyDate' => { s: '2015-12-14' },
                  'list_nil_as_nil' => { null: true },
                  'map_nil_as_nil' => { null: true },
                  'list_nil_to_empty' => { l: [] },
                  'map_nil_to_empty' => { m: {} }
                },
                condition_expression: 'attribute_not_exists(#H) ' \
                                      'and attribute_not_exists(#R)',
                expression_attribute_names: {
                  '#H' => 'id',
                  '#R' => 'MyDate'
                }
              }
            ]
          )
        end

        it 'correctly reads nil collections from DynamoDB' do
          stub_client.stub_responses(
            :get_item,
            item: {
              'id' => 5,
              'MyDate' => '2016-07-15',
              'list_nil_to_empty' => nil,
              'list_nil_as_nil' => nil,
              'map_nil_to_empty' => nil,
              'map_nil_as_nil' => nil
            }
          )
          klass.configure_client(client: stub_client)
          find_opts = { id: 5, date: '2016-07-15' }
          item = klass.find(find_opts)
          expect(item.list_nil_to_empty).to eq([])
          expect(item.list_nil_as_nil).to eq(nil)
          expect(item.map_nil_to_empty).to eq({})
          expect(item.map_nil_as_nil).to eq(nil)
        end
      end

      describe 'validations with ActiveModel::Validations' do
        let(:klass_amv) do
          ::TEST_TABLE = Class.new do
            include(Aws::Record)
            include(ActiveModel::Validations)
            set_table_name('TestTable')
            integer_attr(:id, hash_key: true)
            date_attr(:date, range_key: true)
            string_attr(:body)
            boolean_attr(:bool, database_attribute_name: 'my_boolean')
            validates_presence_of(:id, :date)
          end
        end

        after { Object.send(:remove_const, :TEST_TABLE) }

        it 'will use ActiveModel::Validations :valid? method' do
          klass_amv.configure_client(client: stub_client)
          item = klass_amv.new
          item.id = 3
          expect(item.save).to be_falsey

          item.date = '2016-04-21'
          item.body = 'Hello!'
          expect(item.save).to be_truthy
        end

        it 'will raise on an invalid model for #save!' do
          klass_amv.configure_client(client: stub_client)
          item = klass_amv.new
          item.id = 3
          expect { item.save! }.to raise_error(Errors::ValidationError)
        end
      end

      describe 'Transactional APIs' do
        let(:client_stub) do
          Aws::DynamoDB::Client.new(stub_responses: true)
        end

        describe '#transact_find' do
          it 'can directly call #transact_find' do
            client_stub.stub_responses(
              :transact_get_items,
              responses:
                [
                  { item: {
                    'id' => 1, 'MyDate' => '2015-12-14', 'body' => 'One'
                  } },
                  { item: nil },
                  { item: {
                    'id' => 2, 'MyDate' => '2018-11-29', 'body' => 'Three'
                  } }
                ]
            )
            klass.configure_client(client: client_stub)
            items = klass.transact_find(
              transact_items:
                [
                  { key: { id: 1, date: '2015-12-14' } },
                  { key: { id: 7, date: '2019-07-14' } },
                  { key: { id: 2, date: '2018-11-29' } }
                ]
            )
            # request
            expect(client_stub.api_requests.size).to eq(1)
            request_params = client_stub.api_requests.first[:params]
            expect(request_params[:transact_items]).to eq(
              [
                {
                  get: {
                    key: {
                      'id' => { n: '1' }, 'MyDate' => { s: '2015-12-14' }
                    },
                    table_name: 'TestTable'
                  }
                },
                {
                  get: {
                    key: {
                      'id' => { n: '7' }, 'MyDate' => { s: '2019-07-14' }
                    },
                    table_name: 'TestTable'
                  }
                },
                {
                  get: {
                    key: {
                      'id' => { n: '2' }, 'MyDate' => { s: '2018-11-29' }
                    },
                    table_name: 'TestTable'
                  }
                }
              ]
            )
            # response
            expect(items.responses.size).to eq(3)
            expect(items.responses[1]).to be_nil
            expect(items.responses[0].class).to eq(klass)
            expect(items.responses[2].class).to eq(klass)
            expect(items.responses[0].body).to eq('One')
            expect(items.responses[2].body).to eq('Three')
            expect(items.missing_items.size).to eq(1)
            expect(items.missing_items[0]).to eq(
              model_class: klass,
              key: { 'id' => 7, 'MyDate' => '2019-07-14' }
            )
          end
        end
      end

      describe '#transact_check_expression' do
        it 'can create a valid check expression' do
          expression = klass.transact_check_expression(
            key: { id: 10, date: '2018-11-29' },
            condition_expression: 'size(#T) <= :v',
            expression_attribute_names: {
              '#T' => 'body'
            },
            expression_attribute_values: {
              ':v' => 1024
            }
          )
          expect(expression).to eq(
            key: {
              'id' => 10,
              'MyDate' => '2018-11-29'
            },
            table_name: 'TestTable',
            condition_expression: 'size(#T) <= :v',
            expression_attribute_names: {
              '#T' => 'body'
            },
            expression_attribute_values: {
              ':v' => 1024
            }
          )
        end
      end
    end
  end
end
