# frozen_string_literal: true

require 'spec_helper'

describe Aws::Record::Batch do
  let(:stub_logger) { double(info: nil) }

  let(:stub_client) { Aws::DynamoDB::Client.new(stub_responses: true, logger: stub_logger) }

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
        integer_attr(:id, hash_key: true, database_attribute_name: 'Food ID')
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
            'FoodTable' => [
              { 'Food ID' => 1, 'dish' => 'Pasta', 'spicy' => false },
              { 'Food ID' => 2, 'dish' => 'Waffles', 'spicy' => false, 'gluten_free' => true }
            ],
            'DrinkTable' => [
              { 'id' => 1, 'drink' => 'Hot Chocolate', 'gluten_free' => true }
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

      let(:actual_food) { result.items[0] }
      let(:actual_breakfast) { result.items[1] }
      let(:actual_drink) { result.items[2] }

      it 'reads a batch of operations and returns modeled items' do
        expect(result).to be_an(Aws::Record::BatchRead)
        expect(result.items.size).to eq(3)

        expect(actual_food).to be_a(food)
        expect(actual_food).to_not be_dirty
        expect(actual_food.spicy).to be_falsey

        expect(actual_breakfast).to be_a(breakfast)
        expect(actual_breakfast).to_not be_dirty
        expect(actual_breakfast.spicy).to be_falsey
        expect(actual_breakfast.gluten_free).to be_truthy

        expect(actual_drink).to be_a(drink)
        expect(actual_drink).to_not be_dirty
        expect(actual_drink.drink).to eq('Hot Chocolate')
        expect(actual_drink).to_not respond_to(:gluten_free)
      end

      it 'is complete' do
        expect(result).to be_complete
      end
    end

    context 'when there are more than 100 records' do
      let(:response_array) do
        (1..99).each.map do |i|
          { 'Food ID' => i, 'dish' => "Food#{i}", 'spicy' => false }
        end
      end

      before(:each) do
        stub_client.stub_responses(
          :batch_get_item,
          responses: {
            'FoodTable' => response_array
          },
          unprocessed_keys: {
            'FoodTable' => {
              keys: [
                { 'Food ID' => 100, 'dish' => 'Food100' }
              ]
            }
          }
        )
      end

      let(:result) do
        Aws::Record::Batch.read(client: stub_client) do |db|
          (1..101).each do |i|
            db.find(food, id: i, dish: "Food#{i}")
          end
        end
      end

      it 'reads batch of operations and returns most processed items' do
        expect(result).to be_an(Aws::Record::BatchRead)
        expect(result.items.size).to eq(99)
      end

      it 'is not complete' do
        expect(result).to_not be_complete
      end

      it 'can process the remaining records by running execute' do
        expect(result).to_not be_complete
        stub_client.stub_responses(
          :batch_get_item,
          responses: {
            'FoodTable' => [
              { 'Food ID' => 100, 'dish' => 'Food100', 'spicy' => false },
              { 'Food ID' => 101, 'dish' => 'Food101', 'spicy' => false }
            ]
          }
        )
        result.execute!
        expect(result).to be_complete
        expect(result).to be_an(Aws::Record::BatchRead)
        expect(result.items.size).to eq(101)
      end

      it 'is a enumerable' do
        expect(result).to_not be_complete
        stub_client.stub_responses(
          :batch_get_item,
          responses: {
            'FoodTable' => [
              { 'Food ID' => 100, 'dish' => 'Food100', 'spicy' => false },
              { 'Food ID' => 101, 'dish' => 'Food101', 'spicy' => false }
            ]
          }
        )
        result.each.with_index(1) do |item, expected_id|
          expect(item.id).to eq(expected_id)
        end
        expect(result.to_a.size).to eq(101)
      end
    end

    it 'raises when a record is missing a key' do
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
      }.to raise_error(ArgumentError)
    end

    it 'raises exception when BatchGetItem raises an exception' do
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

    it 'warns when unable to model item from response' do
      stub_client.stub_responses(
        :batch_get_item,
        responses: {
          'FoodTable' => [
            { 'Food ID' => 1, 'dish' => 'Pasta', 'spicy' => false }
          ],
          'DinnerTable' => [
            { 'id' => 1, 'dish' => 'Spaghetti' }
          ]
        }
      )
      expect(stub_logger).to receive(:warn).with(/Unexpected response from service/)
      Aws::Record::Batch.read(client: stub_client) do |db|
        db.find(food, id: 1, dish: 'Pasta')
      end
    end
  end
end
