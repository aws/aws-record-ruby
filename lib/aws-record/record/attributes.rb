# frozen_string_literal: true

module Aws
  module Record
    module Attributes
      def self.included(sub_class)
        sub_class.extend(ClassMethods)
        model_attributes = ModelAttributes.new(self)
        sub_class.instance_variable_set('@attributes', model_attributes)
        sub_class.instance_variable_set('@keys', KeyAttributes.new(model_attributes))
        inherit_attributes(sub_class) if Aws::Record.extends_record?(sub_class)
      end

      # Base initialization method for a new item. Optionally, allows you to
      # provide initial attribute values for the model. You do not need to
      # provide all, or even any, attributes at item creation time.
      #
      # === Inheritance Support
      # Child models will inherit the attributes and keys defined in the parent
      # model. Child models can override attribute keys if defined in their own model.
      #
      # See examples below to see the feature in action.
      # @example Usage Example
      #   class MyModel
      #     include Aws::Record
      #     integer_attr :id,   hash_key: true
      #     string_attr  :name, range_key: true
      #     string_attr  :body
      #   end
      #
      #   item = MyModel.new(id: 1, name: "Quick Create")
      # @example Child model inheriting from Parent model
      #   class Animal
      #     include Aws::Record
      #     string_attr :name,   hash_key: true
      #     integer_attr :age,   default_value: 1
      #   end
      #
      #   class Cat < Animal
      #     include Aws::Record
      #     integer_attr :num_of_wiskers
      #   end
      #
      #   cat = Cat.find(name: 'Foo')
      #   cat.age    # => 1
      #   cat.num_of_wiskers = 200
      # @example Child model overrides the hash key
      #   class Animal
      #     include Aws::Record
      #     string_attr :name,   hash_key: true
      #     integer_attr :age,   range_key: true
      #   end
      #
      #   class Dog < Animal
      #     include Aws::Record
      #     integer_attr :id, hash_key: true
      #   end
      #
      #   Dog.keys # => {:hash=>:id, :range=>:age}
      # @param [Hash] attr_values Attribute symbol/value pairs for any initial
      #  attribute values you wish to set.
      # @return [Aws::Record] An item instance for your model.
      def initialize(attr_values = {})
        opts = {
          track_mutations: self.class.mutation_tracking_enabled?
        }
        @data = ItemData.new(self.class.attributes, opts)
        attr_values.each do |attr_name, attr_value|
          send("#{attr_name}=", attr_value)
        end
      end

      # Returns a hash representation of the attribute data.
      #
      # @return [Hash] Map of attribute names to raw values.
      def to_h
        @data.hash_copy
      end

      # @return [Array] List of attribute names.
      def attribute_names
        self.class.attribute_names
      end

      def self.inherit_attributes(klass)
        superclass_attributes = klass.superclass.instance_variable_get('@attributes')

        superclass_attributes.attributes.each do |name, attribute|
          subclass_attributes = klass.instance_variable_get('@attributes')
          subclass_attributes.register_superclass_attribute(name, attribute)
        end

        superclass_keys = klass.superclass.instance_variable_get('@keys')
        subclass_keys = klass.instance_variable_get('@keys')

        subclass_keys.hash_key = superclass_keys.hash_key if superclass_keys.hash_key
        subclass_keys.range_key = superclass_keys.range_key if superclass_keys.range_key
      end

      private_class_method :inherit_attributes

      module ClassMethods
        # Define an attribute for your model, providing your own attribute type.
        #
        # @param [Symbol] name Name of this attribute.  It should be a name that
        #   is safe to use as a method.
        # @param [Marshaler] marshaler The marshaler for this attribute. So long
        #   as you provide a marshaler which implements +#type_cast+ and
        #   +#serialize+ that consume raw values as expected, you can bring your
        #   own marshaler type. Convenience methods will provide this for you.
        # @param [Hash] opts
        # @option opts [String] :database_attribute_name Optional attribute
        #   used to specify a different name for database persistence than the
        #   `name` parameter. Must be unique (you can't have overlap between
        #   database attribute names and the names of other attributes).
        # @option opts [String] :dynamodb_type Generally used for keys and
        #   index attributes, one of "S", "N", "B", "BOOL", "SS", "NS", "BS",
        #   "M", "L". Optional if this attribute will never be used for a key or
        #   secondary index, but most convenience methods for setting attributes
        #   will provide this.
        # @option opts [Boolean] :persist_nil Optional attribute used to
        #   indicate whether nil values should be persisted. If true, explicitly
        #   set nil values will be saved to DynamoDB as a "null" type. If false,
        #   nil values will be ignored and not persisted. By default, is false.
        # @option opts [Object] :default_value Optional attribute used to
        #   define a "default value" to be used if the attribute's value on an
        #   item is nil or not set at persistence time. Additionally, lambda
        #   can be used as a default value.
        # @option opts [Boolean] :hash_key Set to true if this attribute is
        #   the hash key for the table.
        # @option opts [Boolean] :range_key Set to true if this attribute is
        #   the range key for the table.
        def attr(name, marshaler, opts = {})
          @attributes.register_attribute(name, marshaler, opts)
          _define_attr_methods(name)
          _key_attributes(name, opts)
        end

        # Define a string-type attribute for your model.
        #
        # @param [Symbol] name Name of this attribute.  It should be a name that
        #   is safe to use as a method.
        # @param [Hash] opts
        # @option opts [Boolean] :hash_key Set to true if this attribute is
        #   the hash key for the table.
        # @option opts [Boolean] :range_key Set to true if this attribute is
        #   the range key for the table.
        # @option opts [Boolean] :persist_nil Optional attribute used to
        #   indicate whether nil values should be persisted. If true, explicitly
        #   set nil values will be saved to DynamoDB as a "null" type. If false,
        #   nil values will be ignored and not persisted. By default, is false.
        # @option opts [Object] :default_value Optional attribute used to
        #   define a "default value" to be used if the attribute's value on an
        #   item is nil or not set at persistence time. Additionally, lambda
        #   can be used as a default value.
        def string_attr(name, opts = {})
          opts[:dynamodb_type] = 'S'
          attr(name, Marshalers::StringMarshaler.new(opts), opts)
        end

        # Define a boolean-type attribute for your model.
        #
        # @param [Symbol] name Name of this attribute.  It should be a name that
        #   is safe to use as a method.
        # @param [Hash] opts
        # @option opts [Boolean] :hash_key Set to true if this attribute is
        #   the hash key for the table.
        # @option opts [Boolean] :range_key Set to true if this attribute is
        #   the range key for the table.
        # @option opts [Boolean] :persist_nil Optional attribute used to
        #   indicate whether nil values should be persisted. If true, explicitly
        #   set nil values will be saved to DynamoDB as a "null" type. If false,
        #   nil values will be ignored and not persisted. By default, is false.
        # @option opts [Object] :default_value Optional attribute used to
        #   define a "default value" to be used if the attribute's value on an
        #   item is nil or not set at persistence time. Additionally, lambda
        #   can be used as a default value.
        def boolean_attr(name, opts = {})
          opts[:dynamodb_type] = 'BOOL'
          attr(name, Marshalers::BooleanMarshaler.new(opts), opts)
        end

        # Define a integer-type attribute for your model.
        #
        # @param [Symbol] name Name of this attribute.  It should be a name that
        #   is safe to use as a method.
        # @param [Hash] opts
        # @option opts [Boolean] :hash_key Set to true if this attribute is
        #   the hash key for the table.
        # @option opts [Boolean] :range_key Set to true if this attribute is
        #   the range key for the table.
        # @option opts [Boolean] :persist_nil Optional attribute used to
        #   indicate whether nil values should be persisted. If true, explicitly
        #   set nil values will be saved to DynamoDB as a "null" type. If false,
        #   nil values will be ignored and not persisted. By default, is false.
        # @option opts [Object] :default_value Optional attribute used to
        #   define a "default value" to be used if the attribute's value on an
        #   item is nil or not set at persistence time. Additionally, lambda
        #   can be used as a default value.
        def integer_attr(name, opts = {})
          opts[:dynamodb_type] = 'N'
          attr(name, Marshalers::IntegerMarshaler.new(opts), opts)
        end

        # Define a float-type attribute for your model.
        #
        # @param [Symbol] name Name of this attribute.  It should be a name that
        #   is safe to use as a method.
        # @param [Hash] opts
        # @option opts [Boolean] :hash_key Set to true if this attribute is
        #   the hash key for the table.
        # @option opts [Boolean] :range_key Set to true if this attribute is
        #   the range key for the table.
        # @option opts [Boolean] :persist_nil Optional attribute used to
        #   indicate whether nil values should be persisted. If true, explicitly
        #   set nil values will be saved to DynamoDB as a "null" type. If false,
        #   nil values will be ignored and not persisted. By default, is false.
        # @option opts [Object] :default_value Optional attribute used to
        #   define a "default value" to be used if the attribute's value on an
        #   item is nil or not set at persistence time. Additionally, lambda
        #   can be used as a default value.
        def float_attr(name, opts = {})
          opts[:dynamodb_type] = 'N'
          attr(name, Marshalers::FloatMarshaler.new(opts), opts)
        end

        # Define a date-type attribute for your model.
        #
        # @param [Symbol] name Name of this attribute.  It should be a name that
        #   is safe to use as a method.
        # @param [Hash] opts
        # @option opts [Boolean] :hash_key Set to true if this attribute is
        #   the hash key for the table.
        # @option opts [Boolean] :range_key Set to true if this attribute is
        #   the range key for the table.
        # @option opts [Boolean] :persist_nil Optional attribute used to
        #   indicate whether nil values should be persisted. If true, explicitly
        #   set nil values will be saved to DynamoDB as a "null" type. If false,
        #   nil values will be ignored and not persisted. By default, is false.
        # @option options [Object] :default_value Optional attribute used to
        #   define a "default value" to be used if the attribute's value on an
        #   item is nil or not set at persistence time. Additionally, lambda
        #   can be used as a default value.
        def date_attr(name, opts = {})
          opts[:dynamodb_type] = 'S'
          attr(name, Marshalers::DateMarshaler.new(opts), opts)
        end

        # Define a datetime-type attribute for your model.
        #
        # @param [Symbol] name Name of this attribute.  It should be a name that
        #   is safe to use as a method.
        # @param [Hash] opts
        # @option opts [Boolean] :hash_key Set to true if this attribute is
        #   the hash key for the table.
        # @option opts [Boolean] :range_key Set to true if this attribute is
        #   the range key for the table.
        # @option opts [Boolean] :persist_nil Optional attribute used to
        #   indicate whether nil values should be persisted. If true, explicitly
        #   set nil values will be saved to DynamoDB as a "null" type. If false,
        #   nil values will be ignored and not persisted. By default, is false.
        # @option opts [Object] :default_value Optional attribute used to
        #   define a "default value" to be used if the attribute's value on an
        #   item is nil or not set at persistence time. Additionally, lambda
        #   can be used as a default value.
        def datetime_attr(name, opts = {})
          opts[:dynamodb_type] = 'S'
          attr(name, Marshalers::DateTimeMarshaler.new(opts), opts)
        end

        # Define a time-type attribute for your model.
        #
        # @param [Symbol] name Name of this attribute.  It should be a name that
        #   is safe to use as a method.
        # @param [Hash] opts
        # @option opts [Boolean] :hash_key Set to true if this attribute is
        #   the hash key for the table.
        # @option opts [Boolean] :range_key Set to true if this attribute is
        #   the range key for the table.
        # @option opts [Boolean] :persist_nil Optional attribute used to
        #   indicate whether nil values should be persisted. If true, explicitly
        #   set nil values will be saved to DynamoDB as a "null" type. If false,
        #   nil values will be ignored and not persisted. By default, is false.
        # @option opts [Object] :default_value Optional attribute used to
        #   define a "default value" to be used if the attribute's value on an
        #   item is nil or not set at persistence time. Additionally, lambda
        #   can be used as a default value.
        def time_attr(name, opts = {})
          opts[:dynamodb_type] = 'S'
          attr(name, Marshalers::TimeMarshaler.new(opts), opts)
        end

        # Define a time-type attribute for your model which persists as
        # epoch-seconds.
        #
        # @param [Symbol] name Name of this attribute.  It should be a name
        #   that is safe to use as a method.
        # @param [Hash] opts
        # @option opts [Boolean] :hash_key Set to true if this attribute is
        #   the hash key for the table.
        # @option opts [Boolean] :range_key Set to true if this attribute is
        #   the range key for the table.
        # @option opts [Boolean] :persist_nil Optional attribute used to
        #   indicate whether nil values should be persisted. If true, explicitly
        #   set nil values will be saved to DynamoDB as a "null" type. If false,
        #   nil values will be ignored and not persisted. By default, is false.
        # @option opts [Object] :default_value Optional attribute used to
        #   define a "default value" to be used if the attribute's value on an
        #   item is nil or not set at persistence time. Additionally, lambda
        #   can be used as a default value.
        def epoch_time_attr(name, opts = {})
          opts[:dynamodb_type] = 'N'
          attr(name, Marshalers::EpochTimeMarshaler.new(opts), opts)
        end

        # Define a list-type attribute for your model.
        #
        # Lists do not have to be homogeneous, but they do have to be types that
        # the AWS SDK for Ruby V3's DynamoDB client knows how to marshal and
        # unmarshal. Those types are:
        #
        # * Hash
        # * Array
        # * String
        # * Numeric
        # * Boolean
        # * IO
        # * Set
        # * nil
        #
        # Also note that, since lists are heterogeneous, you may lose some
        # precision when marshaling and unmarshaling. For example, symbols will
        # be stringified, but there is no way to return those strings to symbols
        # when the object is read back from DynamoDB.
        #
        # @param [Symbol] name Name of this attribute.  It should be a name that
        #   is safe to use as a method.
        # @param [Hash] opts
        # @option opts [Boolean] :hash_key Set to true if this attribute is
        #   the hash key for the table.
        # @option opts [Boolean] :range_key Set to true if this attribute is
        #   the range key for the table.
        # @option opts [Object] :default_value Optional attribute used to
        #   define a "default value" to be used if the attribute's value on an
        #   item is nil or not set at persistence time. Additionally, lambda
        #   can be used as a default value.
        def list_attr(name, opts = {})
          opts[:dynamodb_type] = 'L'
          attr(name, Marshalers::ListMarshaler.new(opts), opts)
        end

        # Define a map-type attribute for your model.
        #
        # Maps do not have to be homogeneous, but they do have to use types that
        # the AWS SDK for Ruby V3's DynamoDB client knows how to marshal and
        # unmarshal. Those types are:
        #
        # * Hash
        # * Array
        # * String
        # * Numeric
        # * Boolean
        # * IO
        # * Set
        # * nil
        #
        # Also note that, since maps are heterogeneous, you may lose some
        # precision when marshaling and unmarshaling. For example, symbols will
        # be stringified, but there is no way to return those strings to symbols
        # when the object is read back from DynamoDB.
        #
        # @param [Symbol] name Name of this attribute.  It should be a name that
        #   is safe to use as a method.
        # @param [Hash] opts
        # @option opts [Boolean] :hash_key Set to true if this attribute is
        #   the hash key for the table.
        # @option opts [Boolean] :range_key Set to true if this attribute is
        #   the range key for the table.
        # @option opts [Object] :default_value Optional attribute used to
        #   define a "default value" to be used if the attribute's value on an
        #   item is nil or not set at persistence time. Additionally, lambda
        #   can be used as a default value.
        def map_attr(name, opts = {})
          opts[:dynamodb_type] = 'M'
          attr(name, Marshalers::MapMarshaler.new(opts), opts)
        end

        # Define a string set attribute for your model.
        #
        # String sets are homogeneous sets, containing only strings. Note that
        # empty sets cannot be persisted to DynamoDB. Empty sets are valid for
        # aws-record items, but they will not be persisted as sets. nil values
        # from your table, or a lack of value from your table, will be treated
        # as an empty set for item instances. At persistence time, the marshaler
        # will attempt to marshal any non-strings within the set to be String
        # objects.
        #
        # @param [Symbol] name Name of this attribute.  It should be a name that
        #   is safe to use as a method.
        # @param [Hash] opts
        # @option opts [Boolean] :hash_key Set to true if this attribute is
        #   the hash key for the table.
        # @option opts [Boolean] :range_key Set to true if this attribute is
        #   the range key for the table.
        # @option opts [Object] :default_value Optional attribute used to
        #   define a "default value" to be used if the attribute's value on an
        #   item is nil or not set at persistence time. Additionally, lambda
        #   can be used as a default value.
        def string_set_attr(name, opts = {})
          opts[:dynamodb_type] = 'SS'
          attr(name, Marshalers::StringSetMarshaler.new(opts), opts)
        end

        # Define a numeric set attribute for your model.
        #
        # Numeric sets are homogeneous sets, containing only numbers. Note that
        # empty sets cannot be persisted to DynamoDB. Empty sets are valid for
        # aws-record items, but they will not be persisted as sets. nil values
        # from your table, or a lack of value from your table, will be treated
        # as an empty set for item instances. At persistence time, the marshaler
        # will attempt to marshal any non-numerics within the set to be Numeric
        # objects.
        #
        # @param [Symbol] name Name of this attribute.  It should be a name that
        #   is safe to use as a method.
        # @param [Hash] opts
        # @option opts [Boolean] :hash_key Set to true if this attribute is
        #   the hash key for the table.
        # @option opts [Boolean] :range_key Set to true if this attribute is
        #   the range key for the table.
        # @option opts [Object] :default_value Optional attribute used to
        #   define a "default value" to be used if the attribute's value on an
        #   item is nil or not set at persistence time.  Additionally, lambda
        #   can be used as a default value.
        def numeric_set_attr(name, opts = {})
          opts[:dynamodb_type] = 'NS'
          attr(name, Marshalers::NumericSetMarshaler.new(opts), opts)
        end

        # Define an atomic counter attribute for your model.
        #
        # Atomic counter are an integer-type attribute that is incremented,
        # unconditionally, without interfering with other write requests.
        # The numeric value increments each time you call +increment_<attr>!+.
        # If a specific numeric value are passed in the call, the attribute will
        # increment by that value.
        #
        # To use +increment_<attr>!+ method, the following condition must be true:
        # * None of the attributes have dirty changes.
        # * If there is a value passed in, it must be an integer.
        # For more information, see
        # {https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/WorkingWithItems.html#WorkingWithItems.AtomicCounters
        # Atomic counter} in the Amazon DynamoDB Developer Guide.
        #
        # @param [Symbol] name Name of this attribute.  It should be a name that
        #   is safe to use as a method.
        # @param [Hash] opts
        # @option opts [Object] :default_value Optional attribute used to
        #   define a "default value" to be used if the attribute's value on an
        #   item is nil or not set at persistence time. The "default value" of
        #   the attribute starts at 0.
        #
        # @example Usage Example
        #   class MyRecord
        #     include Aws::Record
        #     integer_attr :id, hash_key: true
        #     atomic_counter :counter
        #   end
        #
        #   record = MyRecord.find(id: 1)
        #   record.counter #=> 0
        #   record.increment_counter! #=> 1
        #   record.increment_counter!(2) #=> 3
        # @see #attr #attr method for additional hash options.
        def atomic_counter(name, opts = {})
          opts[:dynamodb_type] = 'N'
          opts[:default_value] ||= 0
          attr(name, Marshalers::IntegerMarshaler.new(opts), opts)

          define_method("increment_#{name}!") do |increment = 1|
            if dirty?
              msg = 'Attributes need to be saved before atomic counter can be incremented'
              raise Errors::RecordError, msg
            end

            unless increment.is_a?(Integer)
              msg = "expected an Integer value, got #{increment.class}"
              raise ArgumentError, msg
            end

            resp = dynamodb_client.update_item(
              table_name: self.class.table_name,
              key: key_values,
              expression_attribute_values: {
                ':i' => increment
              },
              expression_attribute_names: {
                '#n' => name
              },
              update_expression: 'SET #n = #n + :i',
              return_values: 'UPDATED_NEW'
            )
            assign_attributes(resp[:attributes])
            @data.clean!
            @data.get_attribute(name)
          end
        end

        # @return [Symbol,nil] The symbolic name of the table's hash key.
        def hash_key
          @keys.hash_key
        end

        # @return [Symbol,nil] The symbolic name of the table's range key, or nil if there is no range key.
        def range_key
          @keys.range_key
        end

        # @api private
        def attributes
          @attributes
        end

        # @return [Array] List of attribute names.
        def attribute_names
          @attributes.attributes.keys
        end

        # @api private
        def keys
          @keys.keys
        end

        private

        def _define_attr_methods(name)
          define_method(name) do
            @data.get_attribute(name)
          end

          define_method("#{name}=") do |value|
            @data.set_attribute(name, value)
          end
        end

        def _key_attributes(id, opts)
          if opts[:hash_key] == true && opts[:range_key] == true
            raise ArgumentError, 'Cannot have the same attribute be a hash and range key.'
          elsif opts[:hash_key] == true
            @keys.hash_key = id
          elsif opts[:range_key] == true
            @keys.range_key = id
          end
        end
      end
    end
  end
end
