# frozen_string_literal: true

module Aws
  module Record
    class BatchRead
      include Enumerable

      # @api private
      BATCH_GET_ITEM_LIMIT = 100

      # @param [Hash] opts
      # @option opts [Aws::DynamoDB::Client] client the DynamoDB SDK client.
      def initialize(opts = {})
        @client = opts[:client]
      end

      # Append the item keys to a batch read request.
      #
      # See {Batch.read} for example usage.
      # @param [Aws::Record] klass a model class that includes {Aws::Record}
      # @param [Hash] key attribute-value pairs for the key you wish to search for.
      # @raise [Aws::Record::Errors::KeyMissing] if your option parameters
      #  do not include all item keys defined in the model.
      # @raise [ArgumentError] if the provided item keys is a duplicate request
      #  in the same instance.
      def find(klass, key = {})
        unprocessed_key = format_unprocessed_key(klass, key)
        store_unprocessed_key(klass, unprocessed_key)
        store_item_class(klass, unprocessed_key)
      end

      # Perform a +batch_get_item+ request.
      #
      # This method processes the first 100 item keys and
      # returns an array of new modeled items.
      #
      # See {Batch.read} for example usage.
      # @return [Array] an array of unordered new items
      def execute!
        operation_keys = unprocessed_keys[0..BATCH_GET_ITEM_LIMIT - 1]
        @unprocessed_keys = unprocessed_keys[BATCH_GET_ITEM_LIMIT..] || []

        operations = build_operations(operation_keys)
        result = @client.batch_get_item(request_items: operations)
        new_items = build_items(result.responses)
        items.concat(new_items)

        update_unprocessed_keys(result.unprocessed_keys) unless result.unprocessed_keys.nil?

        new_items
      end

      # Provides an enumeration of the results from the +batch_get_item+ request
      # and handles pagination.
      #
      # Any pending item keys will be automatically processed and be
      # added to the {#items}.
      #
      # See {Batch.read} for example usage.
      # @yieldparam [Aws::Record] item a modeled item
      # @return [Enumerable<BatchRead>] an enumeration over the results of
      #  +batch_get_item+ request.
      def each(&block)
        return enum_for(:each) unless block_given?

        @items.each(&block)

        until complete?
          new_items = execute!
          new_items.each(&block)
        end
      end

      # Indicates if all item keys have been processed.
      #
      # See {Batch.read} for example usage.
      # @return [Boolean] +true+ if all item keys has been processed, +false+ otherwise.
      def complete?
        unprocessed_keys.none?
      end

      # Returns an array of modeled items. The items are marshaled into classes used in {#find} method.
      # These items will be unordered since DynamoDB does not return items in any particular order.
      #
      # See {Batch.read} for example usage.
      # @return [Array] an array of modeled items from the +batch_get_item+ call.
      def items
        @items ||= []
      end

      private

      def unprocessed_keys
        @unprocessed_keys ||= []
      end

      def item_classes
        @item_classes ||= Hash.new { |h, k| h[k] = [] }
      end

      def format_unprocessed_key(klass, key)
        item_key = {}
        attributes = klass.attributes
        klass.keys.each_value do |attr_sym|
          raise Errors::KeyMissing, "Missing required key #{attr_sym} in #{key}" unless key[attr_sym]

          attr_name = attributes.storage_name_for(attr_sym)
          item_key[attr_name] = attributes.attribute_for(attr_sym)
                                          .serialize(key[attr_sym])
        end
        item_key
      end

      def store_unprocessed_key(klass, unprocessed_key)
        unprocessed_keys << { keys: unprocessed_key, table_name: klass.table_name }
      end

      def store_item_class(klass, key)
        if item_classes.include?(klass.table_name)
          item_classes[klass.table_name].each do |item|
            if item[:keys] == key && item[:class] != klass
              raise ArgumentError, 'Provided item keys is a duplicate request'
            end
          end
        end
        item_classes[klass.table_name] << { keys: key, class: klass }
      end

      def build_operations(keys)
        operations = Hash.new { |h, k| h[k] = { keys: [] } }
        keys.each do |key|
          operations[key[:table_name]][:keys] << key[:keys]
        end
        operations
      end

      def build_items(item_responses)
        new_items = []
        item_responses.each do |table, unprocessed_items|
          unprocessed_items.each do |item|
            item_class = find_item_class(table, item)
            if item_class.nil? && @client.config.logger
              @client.config.logger.warn(
                'Unexpected response from service.' \
                "Received: #{item}. Skipping above item and continuing"
              )
            else
              new_items << build_item(item, item_class)
            end
          end
        end
        new_items
      end

      def update_unprocessed_keys(keys)
        keys.each do |table_name, table_values|
          table_values.keys.each do |key| # rubocop:disable Style/HashEachMethods
            unprocessed_keys << { keys: key, table_name: table_name }
          end
        end
      end

      def find_item_class(table, item)
        selected_item = item_classes[table].find { |item_info| contains_keys?(item, item_info[:keys]) }
        selected_item[:class] if selected_item
      end

      def contains_keys?(item, keys)
        item.merge(keys) == item
      end

      def build_item(item, item_class)
        new_item_opts = {}
        item.each do |db_name, value|
          name = item_class.attributes.db_to_attribute_name(db_name)

          next unless name

          new_item_opts[name] = value
        end
        item = item_class.new(new_item_opts)
        item.clean!
        item
      end
    end
  end
end
