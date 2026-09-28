# Aws::Record

[![Build Status](https://travis-ci.org/aws/aws-sdk-ruby-record.svg?branch=main)](https://travis-ci.org/aws/aws-sdk-ruby-record) [![Code Climate](https://codeclimate.com/github/aws/aws-sdk-ruby-record.svg)](https://codeclimate.com/github/aws/aws-sdk-ruby-record) [![Coverage Status](https://coveralls.io/repos/github/aws/aws-sdk-ruby-record/badge.svg?branch=main)](https://coveralls.io/github/aws/aws-sdk-ruby-record?branch=main)

A data mapping abstraction over the AWS SDK for Ruby's client for Amazon
DynamoDB.

## Table of Contents

* [Installation](https://github.com/aws/aws-sdk-ruby-record#installation)
* [Usage](https://github.com/aws/aws-sdk-ruby-record#usage)
  * [Item Operations](https://github.com/aws/aws-sdk-ruby-record#item-operations) 
  * [BatchGetItem / BatchWriteItem](https://github.com/aws/aws-sdk-ruby-record#batchgetitem-and-batchwriteitem)
  * [Transactions](https://github.com/aws/aws-sdk-ruby-record#transactions)
  * [Inheritance Support](https://github.com/aws/aws-sdk-ruby-record#inheritance-support)

## Links of Interest

* [Documentation](http://docs.aws.amazon.com/awssdkrubyrecord/api/)
* [Change Log](https://github.com/aws/aws-sdk-ruby-record/blob/main/CHANGELOG.md)
* [Issues](https://github.com/aws/aws-sdk-ruby-record/issues)
* [License](http://aws.amazon.com/apache2.0/)

---
## Installation

`Aws::Record` is available as the `aws-record` gem from RubyGems.

```shell
gem install 'aws-record'
```

```ruby
gem 'aws-record', '~> 2.0'
```

This automatically includes a dependency on the `aws-sdk-dynamodb` gem (part of the modular version-3 of 
the [AWS SDK for Ruby](https://aws.amazon.com/sdk-for-ruby/). If you need to pin to a specific version, 
you can add [aws-sdk-dynamodb](https://rubygems.org/gems/aws-sdk-dynamodb) 
or [aws-sdk-core](https://rubygems.org/gems/aws-sdk-core) gem in your
Gemfile.

---
## Usage

To create a model that uses `aws-record` features, simply include the provided
module:

```ruby
class MyModel
  include Aws::Record
end
```

You can then specify attributes using the `aws-record` DSL:

```ruby
class MyModel
  include Aws::Record
  integer_attr :id, hash_key: true
  string_attr  :name, range_key: true
  boolean_attr :active, database_attribute_name: 'is_active_flag'
end
```

If a matching table does not exist in DynamoDB, you can use the TableConfig DSL to create your table:

```ruby
cfg = Aws::Record::TableConfig.define do |t|
  t.model_class(MyModel)
  t.read_capacity_units(5)
  t.write_capacity_units(2)
end
cfg.migrate!
```

With a table in place, you can then use your model class to manipulate items in
your table:

```ruby
item = MyModel.find(id: 1, name: 'Hello Record')
item.active = true
item.save
item.delete!

MyModel.find(id: 1, name: 'Hello Record') # => nil

item = MyModel.new
item.id = 2
item.name = 'Item'
item.active = false
item.save
```
---
### Item Operations
You can use item operations on your model class to read and manipulate item(s).

More info under following documentation:
* [Item Operations](https://docs.aws.amazon.com/sdk-for-ruby/aws-record/api/Aws/Record/ItemOperations.html)
* [Item Operations Class Methods](https://docs.aws.amazon.com/sdk-for-ruby/aws-record/api/Aws/Record/ItemOperations/ItemOperationsClassMethods.html)

**Example usage**
```ruby
class MyModel
  include Aws::Record
  integer_attr :uuid,   hash_key: true
  string_attr  :name, range_key: true
  integer_attr :age
end

item = MyModel.find(id: 1, name: 'Foo')
item.update(id: 1, name: 'Foo', age: 1)
```

---

### `BatchGetItem` and `BatchWriteItem`
Aws Record provides [BatchGetItem](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDB/Client.html#batch_get_item-instance_method)
and [BatchWriteItem](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDB/Client.html#batch_write_item-instance_method)
support for aws-record models.

More info under the following documentation:

* [Batch](https://docs.aws.amazon.com/sdk-for-ruby/aws-record/api/Aws/Record/Batch.html)
* [BatchWrite](https://docs.aws.amazon.com/sdk-for-ruby/aws-record/api/Aws/Record/BatchWrite.html)
* [BatchRead](https://docs.aws.amazon.com/sdk-for-ruby/aws-record/api/Aws/Record/BatchRead.html)

See examples below to see the feature in action.

**`BatchGetItem` Example**
```ruby
class Lunch
  include Aws::Record
  integer_attr :id,   hash_key: true
  string_attr  :name, range_key: true
end

class Dessert
  include Aws::Record
  integer_attr :id,   hash_key: true
  string_attr  :name, range_key: true
end

# batch operations
operation = Aws::Record::Batch.read do |db|
  db.find(Lunch, id: 1, name: 'Papaya Salad')
  db.find(Lunch, id: 2, name: 'BLT Sandwich')
  db.find(Dessert, id: 1, name: 'Apple Pie')
end

# BatchRead is enumerable and handles pagination
operation.each { |item| item.id }

# Alternatively, BatchRead provides a lower level interface 
# through: execute!, complete? and items.
# Unprocessed items can be processed by calling:
operation.execute! until operation.complete?
```

**`BatchWriteItem` Example**
```ruby
class Breakfast
  include Aws::Record
  integer_attr :id,   hash_key: true
  string_attr  :name, range_key: true
  string_attr  :body
end

# setup
eggs = Breakfast.new(id: 1, name: 'eggs').save!
waffles = Breakfast.new(id: 2, name: 'waffles')
pancakes = Breakfast.new(id: 3, name: 'pancakes')

# batch operations
operation = Aws::Record::Batch.write(client: Breakfast.dynamodb_client) do |db|
  db.put(waffles)
  db.delete(eggs)
  db.put(pancakes)
end

# unprocessed items can be retried by calling Aws::Record::BatchWrite#execute!
operation.execute! until operation.complete?
```
---
### Transactions
Aws Record provides [TransactGetItems](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDB/Client.html#transact_get_items-instance_method)
and [TransactWriteItems](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDB/Client.html#transact_write_items-instance_method)
support for aws-record models.

More info under the [Transactions](https://docs.aws.amazon.com/sdk-for-ruby/aws-record/api/Aws/Record/Transactions.html) 
documentation.

See examples below to see the feature in action.

**`TransactGetItems` Example**
```ruby
class TableOne
  include Aws::Record
  string_attr :uuid, hash_key: true
end

class TableTwo
  include Aws::Record
  string_attr :hk, hash_key: true
  string_attr :rk, range_key: true
end

results = Aws::Record::Transactions.transact_find(
  transact_items: [
    TableOne.tfind_opts(key: { uuid: 'uuid1234' }),
    TableTwo.tfind_opts(key: { hk: 'hk1', rk: 'rk1'}),
    TableTwo.tfind_opts(key: { hk: 'hk2', rk: 'rk2'})
  ]
) # => results.responses contains nil or marshalled items
results.responses.map { |r| r.class } # [TableOne, TableTwo, TableTwo]
```

**`TransactWriteItems` Example**
```ruby
# same models as `TransactGetItems` Example
check_exp = TableOne.transact_check_expression(
  key: { uuid: 'foo' },
  condition_expression: 'size(#T) <= :v',
  expression_attribute_names: {
    '#T' => 'body'
  },
  expression_attribute_values: {
    ':v' => 1024
  }
)
new_item = TableTwo.new(hk: 'hk1', rk: 'rk1', body: 'Hello!')
update_item_1 = TableOne.find(uuid: 'bar')
update_item_1.body = 'Updated the body!'
put_item = TableOne.new(uuid: 'foobar', body: 'Content!')
update_item_2 = TableTwo.find(hk: 'hk2', rk: 'rk2')
update_item_2.body = 'Update!'
delete_item = TableOne.find(uuid: 'to_be_deleted')

Aws::Record::Transactions.transact_write(
  transact_items: [
    { check: check_exp },
    { save: new_item },
    { save: update_item_1 },
    {
      put: put_item,
      condition_expression: 'attribute_not_exists(#H)',
      expression_attribute_names: { '#H' => 'uuid' },
      return_values_on_condition_check_failure: 'ALL_OLD'
    },
      { update: update_item_2 },
      { delete: delete_item }
  ]
)
```
---
### Inheritance Support
Aws Record models can be extended using standard ruby inheritance. The child model must 
include `Aws::Record` in their model and the following will be inherited:

* [set_table_name](https://docs.aws.amazon.com/sdk-for-ruby/aws-record/api/Aws/Record/RecordClassMethods.html#set_table_name-instance_method)
* [Attributes and Keys](https://docs.aws.amazon.com/sdk-for-ruby/aws-record/api/Aws/Record/Attributes.html#initialize-instance_method)
* Mutation Tracking:
  * [enable_mutation_tracking](https://docs.aws.amazon.com/sdk-for-ruby/aws-record/api/Aws/Record/RecordClassMethods.html#enable_mutation_tracking-instance_method)
  * [disable_mutation_tracking](https://docs.aws.amazon.com/sdk-for-ruby/aws-record/api/Aws/Record/RecordClassMethods.html#disable_mutation_tracking-instance_method)
* [local_secondary_indexes](https://docs.aws.amazon.com/sdk-for-ruby/aws-record/api/Aws/Record/SecondaryIndexes/SecondaryIndexesClassMethods.html#local_secondary_indexes-instance_method)
* [global_secondary_indexes](https://docs.aws.amazon.com/sdk-for-ruby/aws-record/api/Aws/Record/SecondaryIndexes/SecondaryIndexesClassMethods.html#global_secondary_indexes-instance_method)
* [configure_client](https://docs.aws.amazon.com/sdk-for-ruby/aws-record/api/Aws/Record/ClientConfiguration.html#configure_client-instance_method)

See example below to see the feature in action.

```ruby
class Animal
  include Aws::Record
  string_attr :name, hash_key: true
  integer_attr :age
end

class Dog < Animal
  include Aws::Record
  boolean_attr :family_friendly
end

dog = Dog.find(name: 'Sunflower')
dog.age = 3
dog.family_friendly = true
```