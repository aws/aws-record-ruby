2.13.2 (2024-08-21)
------------------

* Issue - Allow `global_secondary_index` to be defined in `TableConfig` without 
  supplying capacity settings. (#140)

2.13.1 (2024-07-18)
------------------

* Issue - Do not try to hydrate undeclared attributes from storage on `batch_read`. (#139)

2.13.0 (2023-10-17)
------------------

* Feature - Allow custom `update_expression` to be passed through to the
  underlying client calls. (#137)

2.12.0 (2023-09-28)
------------------

* Feature - Allow put, update, and delete item options to be passed through to
  the underlying client calls.

* Feature - Add an `original_error` accessor to `Errors::ConditionalWriteFailed`
  which contains the `Aws::DynamoDB::Errors::ConditionalCheckFailedException`
  error. If `:return_values_on_condition_check_failure` was provided to a put,
  update, or delete item call, this error will contain the item data that failed
  the condition check.

* Issue - Fix default value for String/Numeric Sets to be unset. (#133)

* Feature - Set required Ruby version to >= 2.3 (#134)

* Issue - Run Rubocop on all files. (#135)

2.11.0 (2023-06-02)
------------------

* Feature - Improve User-Agent tracking and bump minimum DynamoDB version.

2.10.1 (2023-01-17)
------------------

* Issue - Set `Aws::Record::VERSION` constant from the `VERSION` file

2.10.0 (2023-01-13)
------------------

* Feature - Implement the `BatchGetItem` operation (#122)

2.9.0 (2022-11-16)
------------------

* Feature - Add support for inheritance. Aws Record models can now be extended
  using standard ruby inheritance (#80).

2.8.0 (2022-10-12)
------------------

* Feature - Add support for atomic counter (#144)

2.7.0 (2021-10-28)
------------------

* Feature - Implement the `BatchWriteItem` operation (#119)

2.6.1 (2021-08-10)
------------------

* Issue - Fix FrozenError on BuildableSearch (#115)

2.6.0 (2021-05-13)
------------------

* Feature - Add support for on-demand-billing for table migrations (#94)

2.5.0 (2020-10-13)
------------------

* Feature - `Aws::Record::BuildableSearch` - Support queries yielding
  heterogeneous results using `multi_model_filter` (#107)

2.4.1 (2020-05-29)
------------------

* Issue - Allow symbols for database_attribute_name
* Issue - Correctly allow lambda/proc for default_value

2.4.0 (2019-07-16)
------------------

* Feature - Aws::Record::BuildableSearch - Adds support for query and scan
  builders using substitution expressions. This allows for streamlined and
  expressive queries and scans using aws-record.

2.3.0 (2019-02-08)
------------------

* Feature - Aws::Record::Transactions - Adds support for transactional find and
  transactional get requests. You can learn more about these new APIs in
  the [documentation](https://docs.aws.amazon.com/awssdkrubyrecord/api/Aws/Record/Transactions.html).

2.2.0 (2018-12-05)
------------------

* Feature - Aws::Record::TableConfig - Adds support for the "PAY_PER_REQUEST"
  billing mode in table configurations.

2.1.2 (2018-11-15)
------------------

* Issue - Aws::Record::Marshalers::EpochTimeMarshaler - Fixed a bug where epoch
  time objects didn't properly marshal from database entries.

2.1.1 (2018-07-10)
------------------

* Feature - Aws::Record::TableConfig - Adds `:ttl_attribute` to the TableConfig
  DSL. When used with `epoch_time_attr` attributes or other attributes stored as
  epoch time, your TableConfig migrations will enable TTL on your DynamoDB
  table, and will use your specified attribute as the TTL attribute.

* Feature - Aws::Record::Marshalers::EpochTimeMarshaler - Adds
  the `epoch_time_attr`, which behaves much like `time_attr` except the Amazon
  DynamoDB storage type is numeric, and the serialized value is epoch seconds.

2.1.0 (2018-06-25)
------------------

* Feature - Aws::Record - Add the `persisted?`, `new_record?`, and `destroyed?`
  methods to `Aws::Record`, which supports use cases where you'd like to see if
  a record has just been newly initialized, or has been deleted or was a
  preexisting record retrieved from DynamoDB. Note that these methods are
  present in `ActiveModel::Model` so you should require that module
  before `Aws::Record`

* Feature - Aws::Record - Add the `assign_attributes`, `update`, and `update!`
  methods to `Aws::Record` which supports the use case where the user might want
  to mass assign or update a records attributes by hash. `update!` also ensures
  that a `ValidationError` is thrown on an invalid update

* Upgrading - If you already include `ActiveModel::Model` on your models the
  new `persisted?`, `new_record?` and `destroyed?` methods will not function
  properly unless you include `ActiveModel::Model` before `Aws::Record`.
  Additionally, new methods could lead to collisions if you happened to have
  attributes such as `:update` or `:assign_attributes`. In such a case, you
  would want to version lock below `2.1.0`, or use
  the `:database_attribute_name` property and change your attribute name in
  code.

2.0.2 (2018-06-08)
------------------

* Feature - Aws::Record::Marshalers::TimeMarshaler - Adds the `time_attr` method
  to AWS Record models, which uses `Time` as the underlying type.

2.0.1 (2017-10-27)
------------------

* Feature - Aws::Record::ItemCollection - Add the `#page`
  and `#last_evaluated_key` methods to `Aws::Record::ItemCollection`. This helps
  to support use cases where you'd like to control the result set size with
  the `:limit` parameter, or if you want to expose pagination capabilities to an
  outside caller, for example a list-type operation exposed in a web API.

2.0.0 (2017-08-29)
------------------

* Upgrading - Aws::Record - Support version 3 of the AWS SDK for Ruby. This is
  being released as major version 2 of `aws-record`, though the APIs remain the
  same. Do note, however, that we've changed our SDK dependency to only depend
  on `aws-sdk-dynamodb`. This means that if you were depending on other service
  clients transitively via `aws-record`, you will need to add dependencies on
  the appropriate service gems when upgrading.

1.1.1 (2017-06-16)
------------------

* Feature - Support lambdas for default attribute values.

  ```ruby
  date_attr :date, default_value -> { Date.today }
  ```

* Issue - An attribute's default_value could be modified and carried over to
  new instances of the model. With this change, default values are deep copied,
  and are hydrated at item creation to ensure correct persistence of mutable
  objects.

  See [related GitHub issue #69](https://github.com/aws/aws-sdk-ruby-record/issues/69)

1.1.0 (2017-04-21)
------------------

* Feature - Aws::Record::TableConfig - A declarative way to describe
  configuration for your Amazon DynamoDB tables, with smart migrations based on
  the current remote state. More details in the documentation.

* Issue - Aws::Record::TableMigration - Legacy table migrations could have
  issues with global secondary indexes if a table was deleted and recreated
  multiple times.

  See [related GitHub issue #64](https://github.com/aws/aws-sdk-ruby-record/issues/64).

1.0.3 (2016-12-19)
------------------

* Feature - Aws::Record::ItemOperations - Adds the `find_with_opts` class method
  to model instances, which allows users to pass in both the key (as in `find`)
  and parameters which are to be passed through to the underlying
  `Aws::DynamoDB::Client#get_item` call.

1.0.2 (2016-12-02)
------------------

* Issue - Aws::Record::ItemOperations - Fixes an issue where update operations
  which consist of only `REMOVE` expressions failed due to an empty
  `:expression_attribute_values` map. The fix makes the presence of that map
  conditional on the existance of valid values.

1.0.1 (2016-08-24)
------------------

* Issue - Aws::Record::ItemCollection - Fixes a faulty `#empty?` implementation,
  which could return `false` for a response which is, in fact, empty.

1.0.0 (2016-08-15)
------------------

* Issue - Aws::Record - Fixes the `#table_exists?` and `#provisioned_throughput`
  methods, which could fail if called before `#table_name`.

1.0.0.pre.10 (2016-08-03)
------------------

* Feature - Aws::Record - Refactored tracking of model attributes, key
  attributes,
  and item data to use internal classes over module composition. Dirty tracking
  is
  also handled more consistently across attributes, and turning on/off of dirty
  tracking is only possible at the model level (not for individual attributes).

1.0.0.pre.9 (2016-07-22)
------------------

* Feature - Aws::Record::Attribute - Added support for default values at the
  attribute level.

* Feature - Aws::Record::Marshalers - Removed the marshalers in
  the `Aws::Attributes`
  namespace, replacing them with instantiated marshaler objects. This enables
  more functionality in marshalers such as the Date/DateTime marshalers.

* Feature - Aws::Record::DirtyTracking - Improves dirty tracking by adding
  support for tracking mutations of attribute value objects. This feature is on
  by default for the "collection" types: `:list_attr`, `:map_attr`,
  `:string_set_attr`, and `:numeric_set_attr`.

  Before this feature, the `#save` method's default behavior of running an
  update call for dirty attributes only could cause problems for users of
  collection attributes. As many of them are commonly manipulated using mutable
  state, the underlying "clean" version of the objects would be modified and the
  updated object would not be recognized as dirty, and therefore would not be
  updated at all unless explicitly marked as dirty or through a force put.

  ```ruby
  class Model
    include Aws::Record
    string_attr :uuid, hash_key: true
    list_attr :collection
  end

  item = Model.new(uuid: SecureRandom.uuid, collection: [1,2,3])
  item.clean! # As if loaded from the database, to demonstrate the new tracking.
  item.dirty? # => false
  item.collection << 4 # In place mutation of the "collection" array.
  item.dirty? # => true (Previous versions would not recognize this as dirty.
  item.save # Would call Aws::DynamoDB::Client#update_item for :collection only.
  ```

  Note that this feature is implemented using deep copies of collection objects
  in memory, so there is a potential memory/performance hit in exchange for the
  added accuracy. As such, mutation tracking can be explicitly turned off at the
  attribute level or at the full model level, if desired.

  ```ruby
  # Note that the disabling of mutation tracking is redundant in this example,
  # for illustration purposes.
  class Model
    include Aws::Record
    disable_mutation_tracking # For turning off mutation at the model level.
    string_attr :uuid, hash_key: true
    list_attr :collection, mutation_tracking: false # Turn off at attr level.
  end
  ```

1.0.0.pre.8 (2016-05-19)
------------------

* Feature - Aws::Record - Adds the ability to set initial attribute values when
  calling `#initialize`. Additionally, can call `update` on a model to directly
  call `Aws::DynamoDB::Client#update_item`.

1.0.0.pre.7 (2016-04-21)
------------------

* Upgrading - Aws::Record - This release includes changes to validation and
  to the `#save` and `#save!` methods. With this release, the validation hooks
  in `Aws::Record::Attribute` have been removed. Additionally, `#save` will
  resume raising exceptions on client errors. However, `#save` and `#save!`
  will attempt to call `#valid?` if defined on the model, and will return false
  or raise as appropriate if that method is defined and returns false.

  As a part of this change, we've removed the built in `#valid?` and `#errors`
  methods. If you were a user of those, consider bringing your own validation
  library such as `ActiveModel::Validations`.

* Issue - Aws::Record - Removes `#valid?` and `#errors` methods, which caused a
  conflict with the ability to bring your own validation library such as
  `ActiveModel::Validations`. Added tests as an example and to test
  compatibility.

1.0.0.pre.6 (2016-04-19)
------------------

* Feature - Aws::Record::Attributes - Improves default marshaling behavior for
  set types. Now, if your object responds to `:to_set`, such as an Array, it
  will automatically be marshaled to a set type when persisted.

1.0.0.pre.5 (2016-04-19)
------------------

* Upgrading - Aws::Record - The conditional put/update logic added to `#save`
  and `#save!` is not backwards compatible in some cases. For example, the
  following code would work in previous versions, but not in this version:

  ```ruby
  item = Model.new # Assume :id is the hash key, there is no range key.
  item.id = 1
  item.content = "First write."
  item.save

  smash = Model.new
  smash.id = 1
  smash.content = "Second write."
  smash.save # false, and populates the errors array.
  smash.save(force: true) # This will skip the conditional check and work.

  updatable = Model.find(id: 1)
  updatable.content = "Update write."
  updatable.save # This works and uses an update client call.
  ```

  If you want to maintain previous behavior of unconditional puts, add the
  `force: true` option to your `#save` calls. However, this risks overwriting
  unmodeled attributes, or attributes excluded from your projection. But, the
  option is available for you to use.

* Upgrading - Aws::Record - The split of the `#save` method into `#save` and
  `#save!` breaks when your code is expecting `#save` to raise exceptions.
  `#save` will return false on a failed write and populate an `errors` array.
  If you wish to raise exceptions on failed save attempts, use the `#save!`
  method.

* Feature - Aws::Record - Adds logic to determine if `#save` and `#save!` calls
  should use `Aws::DynamoDB::Client#put_item` or
  `Aws::DynamoDB::Client#update_item`, depending on which item attributes are
  marked as dirty. `#put_item` calls are also made conditional on the key not
  existing, so accidental overwrites can be prevented. Old behavior of
  unconditional `#put_item` calls can be done using the `force: true` parameter.

* Feature - Aws::Record - Separates the `#save` method into `#save` and
  `#save!`. `#save!` will raise any errors that occur during persistence, while
  `#save` will populate an errors array and cause `#valid?` calls on the item to
  return `false`.

* Issue - Aws::Record - Changed how default table names are generated. In the
  past, the default table name could not handle class names that included
  modules. Now, module namespaces are appended to the default table name. This
  should not affect any existing model classes, as previously any affected
  models would have failed to create a table in DynamoDB.

1.0.0.pre.4 (2016-02-11)
------------------

* Feature - Aws::Record::DirtyTracking - `Aws::Record` items will now keep track
  of "dirty" changes from database state. The DirtyTracking module provides a
  set of helper methods to handle dirty attributes.

1.0.0.pre.3 (2016-02-10)
------------------

* Feature - Aws::Record - Support for additional marshaled types, such as lists,
  maps, and string/numeric sets.

1.0.0.pre.2 (2016-02-04)
------------------

* Feature - Aws::Record - Provides a low-level interface for the client `#query`
  and `#scan` methods. Query and Scan results are surfaces as an enumerable
  collection of `Aws::Record` items.

* Feature - Aws::Record - Support for adding global secondary indexes and local
  secondary indexes to your model classes. Built-in support for creating these
  indexes at table creation time.

1.0.0.pre.1 (2015-12-23)
------------------

* Feature - Aws::Record - Initial development release of the `aws-record` gem.
  Includes basic table and item functionality for CRUD operations.
