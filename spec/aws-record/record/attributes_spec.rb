# frozen_string_literal: true

require 'spec_helper'

module Aws
  module Record
    describe 'Attributes' do
      let(:klass) do
        Class.new do
          include(Aws::Record)
        end
      end

      describe '#initialize' do
        let(:model) do
          Class.new do
            include(Aws::Record)

            string_attr(:id, hash_key: true)
            string_attr(:body)
          end
        end

        it 'should allow attribute assignment at item creation time' do
          item = model.new(id: 'MyId')
          expect(item.id).to eq('MyId')
          expect(item.body).to be_nil
        end

        it 'should allow assignment of multiple attributes at item creation' do
          item = model.new(id: 'MyId', body: 'Hello!')
          expect(item.id).to eq('MyId')
          expect(item.body).to eq('Hello!')
        end
      end

      describe 'Keys' do
        it 'should be able to assign a hash key' do
          klass.string_attr(:mykey, hash_key: true)
          klass.string_attr(:other)
          expect(klass.hash_key).to eq(:mykey)
        end

        it 'should be able to assign a hash and range key' do
          klass.string_attr(:mykey, hash_key: true)
          klass.string_attr(:ranged, range_key: true)
          klass.string_attr(:other)
          expect(klass.hash_key).to eq(:mykey)
          expect(klass.range_key).to eq(:ranged)
        end

        it 'should reject assigning the same attribute as hash and range key' do
          expect {
            klass.string_attr(:oops, hash_key: true, range_key: true)
          }.to raise_error(ArgumentError)
        end
      end

      describe 'Attributes' do
        it 'should create dynamic methods around attributes' do
          klass.string_attr(:text)
          x = klass.new
          x.text = 'Hello world!'
          expect(x.text).to eq('Hello world!')
        end

        it 'should reject non-symbolized attribute names' do
          expect { klass.float_attr('floating') }.to raise_error(ArgumentError)
        end

        it 'rejects collisions of db storage names with existing attr names' do
          klass.string_attr(:dup_name, database_attribute_name: 'dup_storage')
          expect {
            klass.string_attr(:fail, database_attribute_name: 'dup_name')
          }.to raise_error(Aws::Record::Errors::NameCollision)
        end

        it 'rejects collisions of attr names with existing db storage names' do
          klass.string_attr(:dup_name, database_attribute_name: 'dup_storage')
          expect {
            klass.string_attr(:dup_storage, database_attribute_name: 'fail')
          }.to raise_error(Aws::Record::Errors::NameCollision)
        end

        it 'should not allow duplicate assignment of the same attr name' do
          klass.string_attr(:duplication)
          expect { klass.datetime_attr(:duplication) }.to raise_error(
            Aws::Record::Errors::NameCollision
          )
        end

        it 'should typecast an integer attribute' do
          klass.integer_attr(:num)
          x = klass.new
          x.num = '5'
          expect(x.num).to eq(5)
        end

        it 'should display a hash representation of attribute raw values' do
          klass.string_attr(:a)
          klass.string_attr(:b)
          x = klass.new
          x.a = '5'
          x.b = 5
          expect(x.to_h).to eq(a: '5', b: 5)
        end

        it 'should allow specification of a separate storage attribute name' do
          klass.string_attr(:a, database_attribute_name: 'column_a')
          klass.string_attr(:b)
          expect(klass.attributes.storage_name_for(:a)).to eq('column_a')
          expect(klass.attributes.storage_name_for(:b)).to eq('b')
        end

        it 'should reject storage name collisions' do
          klass.string_attr(:a, database_attribute_name: 'column_a')
          expect {
            klass.string_attr(:column_a)
          }.to raise_error(Errors::NameCollision)
          expect(klass.attributes.present?(:column_a)).to be_falsy
        end

        it 'should enforce uniqueness of storage names' do
          klass.string_attr(:a, database_attribute_name: 'unique')
          expect {
            klass.string_attr(:b, database_attribute_name: 'unique')
          }.to raise_error(Errors::NameCollision)
        end

        it 'should not allow collisions with reserved names' do
          expect {
            klass.string_attr(:to_h)
          }.to raise_error(Errors::ReservedName)
        end

        it 'should allow reserved names to be used as custom storage names' do
          klass.string_attr(:clever, database_attribute_name: 'to_h')
          item = klass.new
          item.clever = 'No problem.'
          expect(item.to_h).to eq(clever: 'No problem.')
        end
      end

      describe '#atomic_counter' do
        it 'should override the existing default value' do
          klass.string_attr(:id, hash_key: true)
          klass.atomic_counter(:counter, default_value: 5)
          item = klass.new(id: 'MyId')
          expect(item.counter).to eq(5)
        end

        it 'should be the existing default value' do
          klass.string_attr(:id, hash_key: true)
          klass.atomic_counter(:counter)
          item = klass.new(id: 'MyId')
          expect(item.counter).to eq(0)
        end

        it 'should be able to reassign default value after creation' do
          klass.string_attr(:id, hash_key: true)
          klass.atomic_counter(:counter, default_value: 5)
          item = klass.new(id: 'MyId')
          item.counter = 10
          expect(item.counter).to eq(10)
        end

        describe '#incrementing_<attr>!' do
          before(:each) do
            klass.configure_client(client: stub_client)
          end

          let(:klass) do
            Class.new do
              include(Aws::Record)

              set_table_name('TestTable')
              integer_attr(:id, hash_key: true)
              atomic_counter(:counter)
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

          it 'should increment atomic counter by default value' do
            stub_client.stub_responses(:update_item, attributes: { 'counter' => 1 })
            item = klass.new(id: 1)
            item.save!
            item.increment_counter!

            expect(item.counter).to eq(1)
            expect(api_requests[1]).to eq(
              expression_attribute_names: { '#n' => 'counter' },
              expression_attribute_values: { ':i' => { n: '1' } },
              key: { 'id' => { n: '1' } },
              return_values: 'UPDATED_NEW',
              table_name: 'TestTable',
              update_expression: 'SET #n = #n + :i'
            )
          end

          it 'should increment the atomic counter by a custom value' do
            stub_client.stub_responses(:update_item, attributes: { 'counter' => 2 })
            item = klass.new(id: 1)
            item.save!
            item.increment_counter!(2)

            expect(item.counter).to eq(2)
            expect(api_requests[1]).to eq(
              expression_attribute_names: { '#n' => 'counter' },
              expression_attribute_values: { ':i' => { n: '2' } },
              key: { 'id' => { n: '1' } },
              return_values: 'UPDATED_NEW',
              table_name: 'TestTable',
              update_expression: 'SET #n = #n + :i'
            )
          end

          it 'will raise when incrementing on a dirty item' do
            item = klass.new(id: 1)
            expect {
              item.increment_counter!
            }.to raise_error(Errors::RecordError)
          end

          it 'will raise when arg is not an integer' do
            item = klass.new(id: 1)
            item.save!
            expect {
              item.increment_counter!('foo')
            }.to raise_error(ArgumentError)
          end
        end
      end

      describe 'inheritance support' do
        let(:parent_model) do
          Class.new do
            include(Aws::Record)

            integer_attr(:id, hash_key: true)
            date_attr(:date, range_key: true)
            list_attr(:list)
          end
        end

        let(:child_model) do
          Class.new(parent_model) do
            include(Aws::Record)

            string_attr(:body)
          end
        end

        let(:child_model2) do
          Class.new(parent_model) do
            include(Aws::Record)

            string_attr(:body2)
          end
        end

        it 'should have instances of child models with parent attributes ' \
           'and an instance of parent model with its own attributes' do
          parent_item = parent_model.new(id: 1, date: '2022-10-10', list: [])
          child_item = child_model.new(id: 2, date: '2022-10-21', list: [1, 2, 3], body: 'Hello')
          child_item2 = child_model2.new(id: 3, date: '2022-10-31', list: [4, 5, 6], body2: 'World')

          expect(parent_item.id).to eq(1)
          expect(parent_item.date).to eq(Date.parse('2022-10-10'))
          expect(parent_item.list).to eq([])
          expect { parent_item.body }.to raise_error(NoMethodError)
          expect { parent_item.body2 }.to raise_error(NoMethodError)

          expect(child_item.id).to eq(2)
          expect(child_item.date).to eq(Date.parse('2022-10-21'))
          expect(child_item.list).to eq([1, 2, 3])
          expect(child_item.body).to eq('Hello')
          expect { child_item.body2 }.to raise_error(NoMethodError)

          expect(child_item2.id).to eq(3)
          expect(child_item2.date).to eq(Date.parse('2022-10-31'))
          expect(child_item2.list).to eq([4, 5, 6])
          expect(child_item2.body2).to eq('World')
          expect { child_item2.body }.to raise_error(NoMethodError)
        end

        it 'should let child model override attribute keys' do
          child_model.integer_attr(:rk, range_key: true)
          child_item = child_model.new(id: 1, rk: 1, date: '2022-10-21', list: [1, 2, 3], body: 'foo')

          expect(child_item.id).to eq(1)
          expect(child_item.rk).to eq(1)
          expect(child_item.key_values).to eq('id' => 1, 'rk' => 1)
        end

        it 'correctly passes default values to child model' do
          parent_model.string_attr(:test, default_value: -> { 'test' })
          child_item = child_model.new(id: 1, date: '2022-10-21', list: [1, 2, 3], body: 'foo')

          expect(child_item.test).to eq('test')
        end
      end
    end
  end
end
