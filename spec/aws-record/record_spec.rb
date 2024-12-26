# frozen_string_literal: true

require 'spec_helper'

module Aws
  describe 'Record' do
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

    describe '#table_name' do
      it 'should have an implied table name from the class name' do
        ::UnitTestModel = Class.new do
          include(Aws::Record)
        end
        expect(UnitTestModel.table_name).to eq('UnitTestModel')
      end

      it 'should allow a custom table name to be specified' do
        expected = 'ExpectedTableName'
        ::UnitTestModelTwo = Class.new do
          include(Aws::Record)
          set_table_name(expected)
        end
        expect(::UnitTestModelTwo.table_name).to eq(expected)
      end

      it 'should transform outer modules for default table name' do
        expected = 'OuterOne_OuterTwo_ClassTableName'
        ::OuterOne = Module.new
        ::OuterOne::OuterTwo = Module.new
        ::OuterOne::OuterTwo::ClassTableName = Class.new do
          include(Aws::Record)
        end
        expect(::OuterOne::OuterTwo::ClassTableName.table_name).to eq(expected)
      end
    end

    describe '#provisioned_throughput' do
      let(:model) do
        Class.new do
          include(Aws::Record)
          set_table_name('TestTable')
        end
      end

      it 'should fetch the provisioned throughput for the table on request' do
        stub_client.stub_responses(
          :describe_table,
          table: {
            provisioned_throughput: {
              read_capacity_units: 25,
              write_capacity_units: 10
            }
          }
        )
        model.configure_client(client: stub_client)
        resp = model.provisioned_throughput
        expect(api_requests).to eq([{ table_name: 'TestTable' }])
        expect(resp).to eq(
          read_capacity_units: 25,
          write_capacity_units: 10
        )
      end

      it 'should raise a TableDoesNotExist error if the table does not exist' do
        stub_client.stub_responses(:describe_table, 'ResourceNotFoundException')
        model.configure_client(client: stub_client)
        expect { model.provisioned_throughput }.to raise_error(
          Record::Errors::TableDoesNotExist
        )
      end
    end

    describe '#table_exists' do
      let(:model) do
        Class.new do
          include(Aws::Record)
          set_table_name('TestTable')
        end
      end

      it 'can check if the table exists' do
        stub_client.stub_responses(:describe_table, table: { table_status: 'ACTIVE' })
        model.configure_client(client: stub_client)
        expect(model.table_exists?).to eq(true)
      end

      it 'will not recognize a table as existing if it is not active' do
        stub_client.stub_responses(:describe_table, table: { table_status: 'CREATING' })
        model.configure_client(client: stub_client)
        expect(model.table_exists?).to eq(false)
      end

      it 'will answer false to #table_exists? if the table does not exist in DynamoDB' do
        stub_client.stub_responses(:describe_table, 'ResourceNotFoundException')
        model.configure_client(client: stub_client)
        expect(model.table_exists?).to eq(false)
      end
    end

    describe '#track_mutations' do
      let(:model) do
        Class.new do
          include(Aws::Record)
          set_table_name('TestTable')
          string_attr(:uuid, hash_key: true)
          attr(:mt, Aws::Record::Marshalers::StringMarshaler.new)
        end
      end

      it 'is on by default' do
        expect(model.mutation_tracking_enabled?).to be_truthy
      end

      it 'can turn off mutation tracking globally for a model' do
        model.disable_mutation_tracking
        expect(model.mutation_tracking_enabled?).to be_falsy
      end
    end

    describe 'default_value' do
      let(:model) do
        Class.new do
          include(Aws::Record)
          set_table_name('TestTable')
          string_attr(:uuid, hash_key: true)
          map_attr(:things, default_value: {})
        end
      end

      it 'uses a deep copy of the default_value' do
        model.new.things['foo'] = 'bar'
        expect(model.new.things).to eq({})
      end
    end

    describe 'attribute_names' do
      let(:model) do
        Class.new do
          include(Aws::Record)
          set_table_name('TestTable')
          string_attr(:uuid, hash_key: true)
          string_attr(:other_attr)
        end
      end

      describe '.attribute_names' do
        it 'returns the attribute names' do
          expect(model.attribute_names).to eq(%i[uuid other_attr])
        end
      end

      describe '#attribute_names' do
        it 'returns the attribute names' do
          expect(model.new.attribute_names).to eq(%i[uuid other_attr])
        end
      end
    end

    describe 'inheritance support for table name' do
      let(:parent_model) do
        Class.new do
          include(Aws::Record)
          set_table_name('ParentTable')
        end
      end

      let(:child_model) do
        Class.new(parent_model) do
          include(Aws::Record)
        end
      end

      it 'should have child model inherit table name from parent model if it is defined in parent model' do
        expect(parent_model.table_name).to eq('ParentTable')
        expect(child_model.table_name).to eq('ParentTable')
      end

      it 'should have child model override parent table name if defined in model' do
        child_model.set_table_name('ChildTable')
        expect(parent_model.table_name).to eq('ParentTable')
        expect(child_model.table_name).to eq('ChildTable')
      end

      it 'should have parent and child models maintain their default table names' do
        ::ParentModel = Class.new do
          include(Aws::Record)
        end
        ::ChildModel = Class.new(ParentModel) do
          include(Aws::Record)
        end

        expect(ParentModel.table_name).to eq('ParentModel')
        expect(ChildModel.table_name).to eq('ChildModel')
      end
    end

    describe 'inheritance support for track mutations' do
      let(:parent_model) do
        Class.new do
          include(Aws::Record)
          integer_attr(:id, hash_key: true)
        end
      end

      let(:child_model) do
        Class.new(parent_model) do
          include(Aws::Record)
          string_attr(:foo)
        end
      end

      it 'should have child model inherit track mutations from parent model' do
        parent_model.disable_mutation_tracking
        expect(parent_model.mutation_tracking_enabled?).to be_falsy
        expect(child_model.mutation_tracking_enabled?).to be_falsy
      end

      it 'should have child model maintain its own track mutations if defined in model' do
        child_model.disable_mutation_tracking
        expect(parent_model.mutation_tracking_enabled?).to be_truthy
        expect(child_model.mutation_tracking_enabled?).to be_falsy
      end
    end
  end
end
