# Copyright 2015-2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

describe Aws::Record::Batch do

  let(:stub_client) { Aws::DynamoDB::Client.new(stub_responses: true) }

  describe '.write' do
    Planet = Class.new do
      include(Aws::Record)
      integer_attr(:id, hash_key: true)
      string_attr(:name, range_key: true)
    end

    before(:each) do
      Planet.configure_client(client: stub_client)
    end

    let(:pluto) { Planet.find(id: 9, name: 'pluto') }
    let(:result) do
      described_class.write(client: stub_client) do |db|
        db.put(Planet.new(id: 1, name: 'mercury'))
        db.put(Planet.new(id: 2, name: 'venus'))
        db.put(Planet.new(id: 3, name: 'earth'))
        db.put(Planet.new(id: 4, name: 'mars'))
        db.put(Planet.new(id: 5, name: 'jupiter'))
        db.put(Planet.new(id: 6, name: 'saturn'))
        db.put(Planet.new(id: 7, name: 'uranus'))
        db.put(Planet.new(id: 8, name: 'neptune'))
        db.delete(pluto) # sorry :(
      end
    end

    before(:each) do
      stub_client.stub_responses(
        :get_item,
        item: {
          'id' => 9,
          'name' => 'pluto'
        }
      )
    end

    context 'when all operations succeed' do
      before(:each) do
        stub_client.stub_responses(
          :batch_write_item,
          unprocessed_items: {}
        )
      end

      it 'writes a batch of operations' do
        expect(result).to be_an(Aws::Record::BatchWrite)
      end

      it 'is complete' do
        expect(result).to be_complete
      end
    end

    context 'when some operations fail' do
      before(:each) do
        stub_client.stub_responses(
          :batch_write_item,
          unprocessed_items: {
            'planet' => [
              { put_request: { item: { 'id' => 3, 'name' => 'earth' } } },
              { delete_request: { key: { 'id' => 9, 'name' => 'pluto' } } }
            ]
          }
        )
      end

      it 'sets the unprocessed_items attribute' do
        expect(result.unprocessed_items['planet'].size).to eq(2)
      end

      it 'is not complete' do
        expect(result).to_not be_complete
      end
    end
  end

  describe '.read' do

    let(:food) do
      Class.new do
        include(Aws::Record)
        set_table_name('FoodTable')
        integer_attr(:id, hash_key: true)
        string_attr(:dish, range_key: true)
        boolean_attr(:spicy)
      end
    end

    let(:breakfast) do
      Class.new(food) do
        include(Aws::Record)
        boolean_attr(:gluten_free)
      end
    end

    let(:drink) do
      Class.new do
        include(Aws::Record)
        set_table_name('DrinkTable')
        integer_attr(:id, hash_key: true)
        string_attr(:drink)
      end
    end

    before(:each) do
      Aws::Record::Batch.configure_client(client: stub_client)
    end

    context 'when all operations succeed' do

      before(:each) do
        stub_client.stub_responses(
          :batch_get_item,
          responses: {
            'FoodTable'=> [
              {'id' => 1, 'dish' => 'Pasta', 'spicy' => false},
              {'id' => 2, 'dish' => 'Waffles', 'spicy' => false, 'gluten_free' => true},
            ],
            'DrinkTable'=> [
              {'id' => 1, 'drink' => 'Hot Chocolate'},
            ]
          }
        )
      end

      let(:result) do
        Aws::Record::Batch.read(client: stub_client) do |db|
          db.find(food, id: 1, dish: 'Pasta')
          db.find(breakfast, id: 2, dish: 'Waffles')
          db.find(drink, id: 1)
        end
      end

      it 'reads a batch of operations and returns modeled items' do
        expect(result).to be_an(Aws::Record::BatchRead)
        expect(result.items.size).to eq(3)
        expect(result.items[0].class).to eq(food)
        expect(result.items[1].class).to eq(breakfast)
        expect(result.items[2].class).to eq(drink)
        expect(result.items[0].dirty?).to be_falsey
        expect(result.items[1].dirty?).to be_falsey
        expect(result.items[2].dirty?).to be_falsey
        expect(result.items[0].spicy).to be_falsey
        expect(result.items[1].spicy).to be_falsey
        expect(result.items[1].gluten_free).to be_truthy
        expect(result.items[2].drink).to eq('Hot Chocolate')
      end

      it 'is complete' do
        expect(result).to be_complete
      end

    end

    context 'when some operations are uncompleted' do
      before(:each) do
        stub_client.stub_responses(
          :batch_get_item,
          {
            responses: {
              'FoodTable'=> [
                {'id' => 1, 'dish' => 'Pasta', 'spicy' => false},
              ],
            },
            unprocessed_keys: {
              'FoodTable' => {
                :keys => [
                  {'id' => 2, 'dish' => 'Waffles'}
                ]
              },
              'DrinkTable'=> {
                :keys => [
                  {'id' => 1},
                  {'id' => 2}
                ]
              }
            }
          }
        )
      end

      let(:result) do
        Aws::Record::Batch.read(client: stub_client) do |db|
          db.find(food, id: 1, dish: 'Pasta')
          db.find(breakfast, id: 2, dish: 'Waffles')
          db.find(drink, id: 1)
          db.find(drink, id: 2)
        end
      end

      it 'sets the unprocessed_keys attribute' do
        expect(result.unprocessed_keys['FoodTable'][:keys].size).to eq(1)
        expect(result.unprocessed_keys['DrinkTable'][:keys].size).to eq(2)
      end

      it 'is not complete' do
        expect(result).to_not be_complete
      end

      it 'can process the remaining operations by running execute' do
        expect(result).to_not be_complete
        stub_client.stub_responses(
          :batch_get_item,
          responses: {
            'FoodTable'=> [
              {'id' => 2, 'dish' => 'Waffles', 'spicy' => false, 'gluten_free' => true},
            ],
            'DrinkTable'=> [
              {'id' => 1, 'drink' => 'Hot Chocolate'},
              {'id' => 2, 'drink' => 'Coffee'},
            ]
          }
        )
        result.execute!
        expect(result).to be_complete
        expect(result).to be_an(Aws::Record::BatchRead)
        expect(result.items.size).to eq(4)
      end

    end

    it 'raises when an operation is missing a key' do
      expect {
        Aws::Record::Batch.read(client: stub_client) do |db|
          db.find(food, id: 1)
        end
      }.to raise_error(Aws::Record::Errors::KeyMissing)
    end

    it 'raises when there is a duplicate item key' do
      expect {
        Aws::Record::Batch.read(client: stub_client) do |db|
          db.find(food, id: 1, dish: 'Pancakes')
          db.find(breakfast, id: 1, dish: 'Pancakes')
        end
      }.to raise_error(RuntimeError)
    end

    it 'raises exception from API when none of the items can be processed due to '\
        'an insufficient provisioned throughput on all tables in the request' do
      stub_client.stub_responses(
        :batch_get_item,
        'ProvisionedThroughputExceededException'
      )
      expect {
        Aws::Record::Batch.read(client: stub_client) do |db|
          db.find(food, id: 1, dish: 'Omurice')
          db.find(breakfast, id: 2, dish: 'Omelette')
        end
      }.to raise_error(Aws::DynamoDB::Errors::ProvisionedThroughputExceededException)
    end

  end



end

