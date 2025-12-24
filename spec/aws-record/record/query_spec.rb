# frozen_string_literal: true

require 'spec_helper'

module Aws
  module Record
    describe 'Query' do
      let(:klass) do
        Class.new do
          include(Aws::Record)

          set_table_name('TestTable')
          integer_attr(:id, hash_key: true)
          date_attr(:date, range_key: true)
          string_attr(:body)
          global_secondary_index(
            :reverse,
            hash_key: :date,
            range_key: :id,
            projection: {
              projection_type: 'ALL'
            }
          )
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

      describe '#query' do
        it 'can pass on a manually constructed query to the client' do
          stub_client.stub_responses(
            :query,
            items:
              [
                {
                  'id' => 1,
                  'date' => '2016-01-25',
                  'body' => 'Item 1'
                },
                {
                  'id' => 1,
                  'date' => '2016-01-26',
                  'body' => 'Item 2'
                }
              ],
            count: 2,
            scanned_count: 2,
            last_evaluated_key: nil
          )
          klass.configure_client(client: stub_client)
          query_opts = {
            key_conditions: {
              id: {
                attribute_value_list: [1],
                comparison_operator: 'EQ'
              },
              date: {
                attribute_value_list: ['2016-01-01'],
                comparison_operator: 'GT'
              }
            }
          }
          klass.query(query_opts).to_a
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                key_conditions: {
                  'id' => {
                    attribute_value_list: [{ n: '1' }],
                    comparison_operator: 'EQ'
                  },
                  'date' => {
                    attribute_value_list: [{ s: '2016-01-01' }],
                    comparison_operator: 'GT'
                  }
                }
              }
            ]
          )
        end
      end

      describe '#scan' do
        it 'can pass on a manually constructed scan to the client' do
          stub_client.stub_responses(
            :scan,
            items:
              [
                {
                  'id' => 1,
                  'date' => '2016-01-25',
                  'body' => 'Item 1'
                },
                {
                  'id' => 1,
                  'date' => '2016-01-26',
                  'body' => 'Item 2'
                }
              ],
            count: 2,
            scanned_count: 2,
            last_evaluated_key: nil
          )
          klass.configure_client(client: stub_client)
          klass.scan.to_a
          expect(api_requests).to eq([{ table_name: 'TestTable' }])
        end
      end

      describe '#build_query' do
        it 'accepts frozen strings as the key expression (#115)' do
          klass.configure_client(client: stub_client)
          q = klass
              .build_query
              .key_expr(
                ':id = ? AND begins_with(date, ?)',
                'my-id',
                '2019-07-15'
              )
              .scan_ascending(false)
              .projection_expr(':body')
              .limit(10)
              .complete!
          q.to_a
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                key_condition_expression: '#BUILDERA = :buildera AND begins_with(date, :builderb)',
                projection_expression: '#BUILDERB',
                limit: 10,
                scan_index_forward: false,
                expression_attribute_names: {
                  '#BUILDERA' => 'id',
                  '#BUILDERB' => 'body'
                },
                expression_attribute_values: {
                  ':buildera' => { s: 'my-id' },
                  ':builderb' => { s: '2019-07-15' }
                }
              }
            ]
          )
        end

        it 'can build and run a query' do
          klass.configure_client(client: stub_client)
          q = klass
              .build_query
              .on_index(:reverse)
              .key_expr(':date = ?', '2019-07-15')
              .scan_ascending(false)
              .projection_expr(':body')
              .limit(10)
              .complete!
          q.to_a
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                index_name: 'reverse',
                key_condition_expression: '#BUILDERA = :buildera',
                projection_expression: '#BUILDERB',
                limit: 10,
                scan_index_forward: false,
                expression_attribute_names: {
                  '#BUILDERA' => 'date',
                  '#BUILDERB' => 'body'
                },
                expression_attribute_values: {
                  ':buildera' => { s: '2019-07-15' }
                }
              }
            ]
          )
        end
      end

      describe '#build_scan' do
        it 'can build and run a scan' do
          klass.configure_client(client: stub_client)
          klass.build_scan
               .consistent_read(false)
               .filter_expr(':body = ?', 'foo')
               .parallel_scan(total_segments: 5, segment: 2)
               .exclusive_start_key(id: 5, date: '2019-01-01')
               .complete!.to_a
          expect(api_requests).to eq(
            [
              {
                table_name: 'TestTable',
                consistent_read: false,
                filter_expression: '#BUILDERA = :buildera',
                exclusive_start_key: {
                  'id' => { n: '5' },
                  'date' => { s: '2019-01-01' }
                },
                segment: 2,
                total_segments: 5,
                expression_attribute_names: {
                  '#BUILDERA' => 'body'
                },
                expression_attribute_values: {
                  ':buildera' => { s: 'foo' }
                }
              }
            ]
          )
        end

        it 'does not support key expressions' do
          expect {
            klass.build_scan.key_expr(':fail = ?', true)
          }.to raise_error(ArgumentError)
        end

        it 'does not support ascending scan settings' do
          expect {
            klass.build_scan.scan_ascending(false)
          }.to raise_error(ArgumentError)
        end
      end
    end
  end
end
