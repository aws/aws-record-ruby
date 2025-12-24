# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'

describe Aws::Record::DirtyTracking do
  let(:klass) do
    Class.new do
      include(Aws::Record)

      set_table_name(:test_table)

      string_attr(:mykey, hash_key: true)
      string_attr(:body)
    end
  end

  let(:instance) { klass.new }

  let(:stub_client) { Aws::DynamoDB::Client.new(stub_responses: true) }

  describe '#[attribute]_dirty?' do
    it 'should return whether the attribute is dirty or clean' do
      expect(instance.mykey_dirty?).to be false

      instance.mykey = SecureRandom.uuid
      expect(instance.mykey_dirty?).to be true
    end

    it 'should not reflect changes to the original value as dirty' do
      instance.mykey = nil
      expect(instance.mykey_dirty?).to be false

      instance.mykey = SecureRandom.uuid
      expect(instance.mykey_dirty?).to be true

      instance.mykey = nil
      expect(instance.mykey_dirty?).to be false
    end

    it 'should recognize initialization values as dirty' do
      item = klass.new(mykey: 'Key', body: 'Hello!')
      expect(item.mykey_dirty?).to be_truthy
    end
  end

  describe '#[attribute]_dirty!' do
    before(:each) do
      instance.mykey = 'Alex'
      instance.clean!
    end

    it 'should mark the attribute as dirty' do
      expect(instance.mykey_dirty?).to be false

      instance.mykey_dirty!
      expect(instance.mykey_dirty?).to be true

      instance.mykey = 's'
      expect(instance.mykey_dirty?).to be true
    end

    it 'should take a snapshot of the attribute' do
      expect(instance.mykey_was).to eq 'Alex'
      expect(instance.mykey).to eq 'Alex'

      instance.mykey = 'Alexi'
      expect(instance.mykey_was).to eq 'Alex'
      expect(instance.mykey).to eq 'Alexi'

      instance.mykey_dirty!
      expect(instance.mykey_was).to eq 'Alex'
      expect(instance.mykey).to eq 'Alexi'

      instance.mykey = 'Alexis'
      expect(instance.mykey_was).to eq 'Alex'
      expect(instance.mykey).to eq 'Alexis'
    end
  end

  describe '#[attribute]_was' do
    it 'should return the last known clean value' do
      expect(instance.mykey_was).to be nil

      instance.mykey = SecureRandom.uuid
      expect(instance.mykey_was).to be nil
    end
  end

  describe '#clean!' do
    it 'should mark the record as clean' do
      instance.mykey = SecureRandom.uuid
      expect(instance.dirty?).to be true
      expect(instance.mykey_was).to be nil

      instance.clean!
      expect(instance.dirty?).to be false
      expect(instance.mykey_was).to eq instance.mykey
    end
  end

  describe '#dirty' do
    it 'should return an array of dirty attributes' do
      expect(instance.dirty).to match_array []

      instance.mykey = SecureRandom.uuid
      expect(instance.dirty).to match_array [:mykey]

      instance.body = SecureRandom.uuid
      expect(instance.dirty).to match_array %i[mykey body]
    end
  end

  describe '#dirty?' do
    it 'should return whether the record is dirty or clean' do
      expect(instance.dirty?).to be false

      instance.mykey = SecureRandom.uuid
      expect(instance.dirty?).to be true
    end
  end

  describe '#reload!' do
    before(:each) do
      klass.configure_client(client: stub_client)
    end

    let(:reloaded_instance) do
      item = klass.new
      item.mykey = SecureRandom.uuid
      item.body = SecureRandom.uuid
      item.clean!
      item
    end

    it 'can reload an item using find' do
      expect(klass)
        .to receive(:find)
        .with({ mykey: reloaded_instance.mykey })
        .and_return(reloaded_instance)

      instance.mykey = reloaded_instance.mykey
      instance.body = SecureRandom.uuid

      instance.reload!

      expect(instance.body).to eq reloaded_instance.body
    end

    it 'raises an error when find returns nil' do
      instance.mykey = SecureRandom.uuid

      expect(klass)
        .to receive(:find)
        .with({ mykey: instance.mykey })
        .and_return(nil)
      expect { instance.reload! }.to raise_error Aws::Record::Errors::NotFound
    end

    it 'should mark the item as clean' do
      instance.mykey = SecureRandom.uuid
      expect(instance.dirty?).to be true

      instance.reload!
      expect(instance.dirty?).to be false
    end
  end

  describe 'persisted?' do
    before(:each) do
      klass.configure_client(client: stub_client)
    end

    it 'appropriately determines whether an item is persisted' do
      item = klass.new
      item.mykey = 'mykey'
      item.body = 'body'
      # Test all combinations of new_recorded and destroyed
      expect(item.persisted?).to be false
      item.save
      expect(item.persisted?).to be true
      item.delete!
      expect(item.persisted?).to be false
      item = klass.new
      item.mykey = 'mykey'
      item.body = 'body'
      item.delete!
      expect(item.persisted?).to be false
    end
  end

  describe 'persisted? with ActiveModel::Model' do
    let(:klass) do
      Class.new do
        include(ActiveModel::Model)
        include(Aws::Record)

        set_table_name(:test_table)
        string_attr(:mykey, hash_key: true)
        string_attr(:body)
      end
    end

    before(:each) do
      klass.configure_client(client: stub_client)
    end

    it 'appropriately determines whether an item is persisted' do
      item = klass.new
      item.mykey = 'mykey'
      item.body = 'body'
      # Test all combinations of new_recorded and destroyed
      expect(item.persisted?).to be false
      item.save
      expect(item.persisted?).to be true
      item.delete!
      expect(item.persisted?).to be false
      item = klass.new
      item.mykey = 'mykey'
      item.body = 'body'
      item.delete!
      expect(item.persisted?).to be false
    end
  end

  describe '#rollback_[attribute]!' do
    it 'should restore the attribute to its last known clean value' do
      original_mykey = instance.mykey

      instance.mykey = SecureRandom.uuid

      instance.rollback_mykey!
      expect(instance.mykey).to be original_mykey
    end
  end

  describe '#rollback!' do
    it 'should restore the provided attributes' do
      original_mykey = instance.mykey

      instance.mykey = SecureRandom.uuid
      instance.body = updated_body = SecureRandom.uuid

      instance.rollback!(:mykey)

      expect(instance.mykey).to eq original_mykey
      expect(instance.body).to eq updated_body
    end

    context 'when no attributes are provided' do
      it 'should restore all attributes' do
        original_mykey = instance.mykey
        original_body = instance.body

        instance.mykey = SecureRandom.uuid
        instance.body = SecureRandom.uuid

        instance.rollback!

        expect(instance.dirty?).to be false

        expect(instance.mykey).to eq original_mykey
        expect(instance.body).to eq original_body
      end
    end
  end

  describe '#update' do
    before(:each) do
      klass.configure_client(client: stub_client)
    end

    it 'assign_attributes should perform a hash based attribute assignment without persisting changes' do
      item = klass.new
      item.mykey = 'mykey'
      item.body = 'body'
      item.save

      new_key = 'newkey'
      new_body = 'newbody'
      item.assign_attributes(mykey: new_key, body: new_body)
      expect(item.mykey).to eq new_key
      expect(item.body).to eq new_body
      expect(item.dirty?).to be true
    end

    it 'update should perform a hash based attribute assignment and persist changes' do
      item = klass.new
      item.mykey = 'mykey'
      item.body = 'body'
      item.save

      new_key = 'newkey'
      new_body = 'newbody'
      item.update(mykey: new_key, body: new_body)
      expect(item.mykey).to eq new_key
      expect(item.body).to eq new_body
      expect(item.dirty?).to be false
    end

    it 'automatically tokenizes update hash keys' do
      item = klass.new
      item.mykey = 'mykey'
      item.body = 'body'
      item.save

      new_key = 'newkey'
      new_body = 'newbody'
      item.update(mykey: new_key, body: new_body)
      expect(item.mykey).to eq new_key
      expect(item.body).to eq new_body
      expect(item.dirty?).to be false
    end

    it 'update not update when an invalid update is performed' do
      model = Object.const_set(
        'TestUpdateValidationModel',
        Class.new do
          include(Aws::Record)
          include(ActiveModel::Validations)

          set_table_name('TestTable')
          integer_attr(:id, hash_key: true)
          string_attr(:body)
          validates_length_of(:body, maximum: 5)
        end
      )
      model.configure_client(client: stub_client)

      record = model.new(id: 1, body: '12345')
      record.save
      res = record.update(body: '123456')
      expect(res).to be(false)
    end

    it 'update! should throw an error when a validation error occurs' do
      model = Class.new do
        include(Aws::Record)
        include(ActiveModel::Validations)

        set_table_name('TestTable')
        integer_attr(:id, hash_key: true)
        string_attr(:body)
        validates_length_of(:body, maximum: 5)
      end
      model.configure_client(client: stub_client)

      record = model.new(id: 1, body: '12345')
      record.save
      expect {
        record.update!(body: '123456').to raise_error(Errors::ValidationError)
      }
    end

    it 'should throw an argument error when you try to update an invalid attribute' do
      item = klass.new
      item.mykey = 'mykey'
      item.body = 'body'
      item.save

      expect {
        item.assign_attributes(mykey_key: 'ThrowsError')
      }.to raise_error(ArgumentError)
    end
  end

  describe '#update with ActiveModel::Model' do
    let(:klass) do
      Class.new do
        include(ActiveModel::Model)
        include(Aws::Record)

        set_table_name(:test_table)

        string_attr(:mykey, hash_key: true)
        string_attr(:body)
      end
    end

    before(:each) do
      klass.configure_client(client: stub_client)
    end

    it 'assign_attributes should perform a hash based attribute assignment without persisting changes' do
      item = klass.new
      item.mykey = 'mykey'
      item.body = 'body'
      item.save

      new_key = 'newkey'
      new_body = 'newbody'
      item.assign_attributes(mykey: new_key, body: new_body)
      expect(item.mykey).to eq new_key
      expect(item.body).to eq new_body
      expect(item.dirty?).to be true
    end

    it 'update should perform a hash based attribute assignment and persist changes' do
      item = klass.new
      item.mykey = 'mykey'
      item.body = 'body'
      item.save

      new_key = 'newkey'
      new_body = 'newbody'
      item.update(mykey: new_key, body: new_body)
      expect(item.mykey).to eq new_key
      expect(item.body).to eq new_body
      expect(item.dirty?).to be false
    end

    it 'automatically tokenizes update hash keys' do
      item = klass.new
      item.mykey = 'mykey'
      item.body = 'body'
      item.save

      new_key = 'newkey'
      new_body = 'newbody'
      item.update(:mykey => new_key, 'body' => new_body)
      expect(item.mykey).to eq new_key
      expect(item.body).to eq new_body
      expect(item.dirty?).to be false
    end

    it 'update! should throw an error when a validation error occurs' do
      model = Class.new do
        include(Aws::Record)
        include(ActiveModel::Validations)

        set_table_name('TestTable')
        integer_attr(:id, hash_key: true)
        string_attr(:body)
        validates_length_of(:body, maximum: 5)
      end
      model.configure_client(client: stub_client)

      record = model.new(id: 1, body: '12345')
      record.save
      expect {
        record.update!(body: '123456').to raise_error(Errors::ValidationError)
      }
    end

    it 'should throw an argument error when you try to update an invalid attribute' do
      item = klass.new
      item.mykey = 'mykey'
      item.body = 'body'
      item.save

      expect {
        item.assign_attributes(mykey_key: 'ThrowsError')
      }.to raise_error(ArgumentError)
    end
  end

  describe '#save' do
    before(:each) do
      klass.configure_client(client: stub_client)
    end

    it 'should mark the item as clean' do
      instance.mykey = SecureRandom.uuid
      expect(instance.dirty?).to be true

      instance.save
      expect(instance.dirty?).to be false
    end
  end

  describe '#find' do
    before(:each) do
      klass.configure_client(client: stub_client)
    end

    it 'should mark the item as clean' do
      found_item = klass.find(mykey: 1)

      expect(found_item.dirty?).to be false
    end
  end

  describe 'Mutation Dirty Tracking' do
    let(:klass) do
      Class.new do
        include(Aws::Record)

        set_table_name(:test_table)
        string_attr(:mykey, hash_key: true)
        string_attr(:body)
        list_attr(:dirty_list)
        map_attr(:dirty_map)
        string_set_attr(:dirty_set)
      end
    end

    describe 'Default Values' do
      let(:klass_with_defaults) do
        Class.new do
          include(Aws::Record)

          set_table_name(:test_table)
          string_attr(:mykey, hash_key: true)
          map_attr(:dirty_map, default_value: {})
        end
      end

      it 'tracks mutations to the default value' do
        item = klass_with_defaults.new(mykey: 'key')
        item.clean!
        expect(item.dirty?).to be_falsy
        item.dirty_map[:key] = 'value'
        expect(item.dirty_map).to eq(key: 'value')
        expect(item.dirty?).to be_truthy
      end
    end

    describe 'Tracking Turned Off' do
      it 'does not track detailed mutations when tracking is globally off' do
        klass.disable_mutation_tracking
        item = klass.new(mykey: '1', dirty_list: [1, 2, 3])
        item.clean!
        item.dirty_list << 4
        expect(item.dirty_list).to eq([1, 2, 3, 4])
        expect(item.dirty?).to be_falsy
      end
    end

    describe 'Lists' do
      it 'marks mutated lists as dirty' do
        item = klass.new(mykey: '1', dirty_list: [1, 2, 3])
        item.clean!
        item.dirty_list << 4
        expect(item.dirty_list).to eq([1, 2, 3, 4])
        expect(item.dirty?).to be_truthy
        expect(item.attribute_dirty?(:dirty_list)).to be_truthy
      end

      it 'has a copy of the mutated list to reference and can roll back' do
        item = klass.new(mykey: '1', dirty_list: [1, 2, 3])
        item.clean!
        item.dirty_list << 4
        expect(item.dirty_list_was).to eq([1, 2, 3])
        item.rollback!(:dirty_list)
        expect(item.dirty_list).to eq([1, 2, 3])
      end

      it 'includes the mutated list in the list of dirty attributes' do
        item = klass.new(mykey: '1', body: 'b', dirty_list: [1, 2, 3])
        item.clean!
        item.body = 'body'
        item.dirty_list << 4
        expect(item.dirty).to eq(%i[body dirty_list])
      end

      it 'correctly unmarks attributes as dirty when rolling back from copy' do
        item = klass.new(mykey: '1', dirty_list: [1, 2, 3])
        item.clean!
        item.attribute_dirty!(:dirty_list)
        expect(item.dirty).to eq([:dirty_list])
        item.dirty_list << 4
        expect(item.dirty).to eq([:dirty_list])
        item.rollback_attribute!(:dirty_list)
        expect(item.dirty?).to be_falsy
      end

      it 'correctly handles #clean! with a mutated list' do
        item = klass.new(mykey: '1', body: 'b', dirty_list: [1, 2, 3])
        item.clean!
        item.dirty_list << 4
        expect(item.dirty?).to be_truthy
        item.clean!
        expect(item.dirty?).to be_falsy
        expect(item.attribute_was(:dirty_list)).to eq([1, 2, 3, 4])
      end

      it 'correctly handles nested mutated lists' do
        my_list = [[1], [1, 2], [1, 2, 3]]
        item = klass.new(mykey: '1', dirty_list: my_list)
        item.clean!
        expect(item.dirty?).to be_falsy
        my_list[0] << 2
        my_list[1] << 3
        my_list[2] << 4
        expect(item.dirty_list).to eq([[1, 2], [1, 2, 3], [1, 2, 3, 4]])
        expect(item.dirty_list_was).to eq([[1], [1, 2], [1, 2, 3]])
        expect(item.dirty?).to be_truthy
        item.rollback_attribute!(:dirty_list)
        expect(item.dirty_list).to eq([[1], [1, 2], [1, 2, 3]])
      end

      it 'correctly handles list equality through assignment' do
        item = klass.new(mykey: '1', dirty_list: [1, 2, 3])
        item.clean!
        item.dirty_list << 4
        expect(item.dirty?).to be_truthy
        item.dirty_list = [1, 2, 3]
        expect(item.dirty?).to be_falsy
      end
    end

    describe 'Maps' do
      it 'marks mutated maps as dirty' do
        item = klass.new(mykey: '1', dirty_map: { a: 1, b: '2' })
        item.clean!
        item.dirty_map[:c] = 3.0
        expect(item.dirty_map).to eq(a: 1, b: '2', c: 3.0)
        expect(item.dirty?).to be_truthy
        expect(item.attribute_dirty?(:dirty_map)).to be_truthy
      end

      it 'has a copy of the mutated map to reference and can roll back' do
        item = klass.new(mykey: '1', dirty_map: { a: 1, b: '2' })
        item.clean!
        item.dirty_map[:c] = 3.0
        expect(item.dirty_map_was).to eq(a: 1, b: '2')
        item.rollback!(:dirty_map)
        expect(item.dirty_map).to eq(a: 1, b: '2')
      end

      it 'includes the mutated map in the list of dirty attributes' do
        item = klass.new(mykey: '1', body: 'b', dirty_map: { a: 1, b: '2' })
        item.clean!
        item.body = 'body'
        item.dirty_map[:c] = 3.0
        expect(item.dirty).to eq(%i[body dirty_map])
      end

      it 'correctly unmarks attributes as dirty when rolling back from copy' do
        item = klass.new(mykey: '1', dirty_map: { a: 1, b: '2' })
        item.clean!
        item.attribute_dirty!(:dirty_map)
        expect(item.dirty).to eq([:dirty_map])
        item.dirty_map[:c] = 3.0
        expect(item.dirty).to eq([:dirty_map])
        item.rollback_attribute!(:dirty_map)
        expect(item.dirty?).to be_falsy
      end

      it 'correctly handles #clean! with a mutated map' do
        item = klass.new(mykey: '1', dirty_map: { a: 1, b: '2' })
        item.clean!
        item.dirty_map[:c] = 3.0
        expect(item.dirty?).to be_truthy
        item.clean!
        expect(item.dirty?).to be_falsy
        expect(item.attribute_was(:dirty_map)).to eq(a: 1, b: '2', c: 3.0)
      end

      it 'correctly handles nested mutated maps' do
        my_map = {
          a: { one: 1, two: 2.0 },
          b: 2
        }
        item = klass.new(mykey: '1', dirty_map: my_map)
        item.clean!
        expect(item.dirty?).to be_falsy
        my_map[:a][:three] = '3'
        my_map[:c] = { nesting: true }
        expect(item.dirty_map).to eq(
          a: { one: 1, two: 2.0, three: '3' },
          b: 2,
          c: { nesting: true }
        )
        expect(item.dirty_map_was).to eq(
          a: { one: 1, two: 2.0 },
          b: 2
        )
        expect(item.dirty?).to be_truthy
        item.rollback_attribute!(:dirty_map)
        expect(item.dirty_map).to eq(
          a: { one: 1, two: 2.0 },
          b: 2
        )
      end

      it 'correctly handles map equality through assignment' do
        item = klass.new(mykey: '1', dirty_map: { a: 1, b: '2' })
        item.clean!
        item.dirty_map[:c] = 3.0
        expect(item.dirty?).to be_truthy
        item.dirty_map = { a: 1, b: '2' }
        expect(item.dirty?).to be_falsy
      end
    end

    describe 'Sets' do
      it 'marks mutated sets as dirty' do
        item = klass.new(mykey: '1', dirty_set: Set.new(%w[a b c]))
        item.clean!
        item.dirty_set.add('d')
        expect(item.dirty_set).to eq(Set.new(%w[a b c d]))
        expect(item.dirty?).to be_truthy
        expect(item.attribute_dirty?(:dirty_set)).to be_truthy
      end

      it 'has a copy of the mutated set to reference and can roll back' do
        item = klass.new(mykey: '1', dirty_set: Set.new(%w[a b c]))
        item.clean!
        item.dirty_set.add('d')
        expect(item.dirty_set_was).to eq(Set.new(%w[a b c]))
        item.rollback!(:dirty_set)
        expect(item.dirty_set).to eq(Set.new(%w[a b c]))
      end

      it 'includes the mutated set in the list of dirty attributes' do
        item = klass.new(mykey: '1', body: 'b', dirty_set: Set.new(%w[a b c]))
        item.clean!
        item.body = 'body'
        item.dirty_set.add('d')
        expect(item.dirty).to eq(%i[body dirty_set])
      end

      it 'correctly unmarks attributes as dirty when rolling back from copy' do
        item = klass.new(mykey: '1', dirty_set: Set.new(%w[a b c]))
        item.clean!
        item.attribute_dirty!(:dirty_set)
        expect(item.dirty).to eq([:dirty_set])
        item.dirty_set.add('d')
        expect(item.dirty).to eq([:dirty_set])
        item.rollback_attribute!(:dirty_set)
        expect(item.dirty?).to be_falsy
      end

      it 'correctly handles #clean! with a mutated set' do
        item = klass.new(mykey: '1', dirty_set: Set.new(%w[a b c]))
        item.clean!
        item.dirty_set.add('d')
        expect(item.dirty?).to be_truthy
        item.clean!
        expect(item.dirty?).to be_falsy
        expect(item.attribute_was(:dirty_set)).to eq(Set.new(%w[a b c d]))
      end

      it 'correctly handles set equality through assignment' do
        item = klass.new(mykey: '1', dirty_set: Set.new(%w[a b c]))
        item.clean!
        item.dirty_set.add('d')
        expect(item.dirty?).to be_truthy
        item.dirty_set = Set.new(%w[a b c])
        expect(item.dirty?).to be_falsy
      end
    end
  end
end
