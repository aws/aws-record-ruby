# frozen_string_literal: true

module Aws
  module Record
    module ClientConfiguration
      # Configures the Amazon DynamoDB client used by this class and all
      # instances of this class.
      #
      # Please note that this method is also called internally when you first
      # attempt to perform an operation against the remote end, if you have not
      # already configured a client. As such, please read and understand the
      # documentation in the AWS SDK for Ruby around
      # {http://docs.aws.amazon.com/sdk-for-ruby/v3/api/index.html#Configuration configuration}
      # to ensure you understand how default configuration behavior works. When
      # in doubt, call this method to ensure your client is configured the way
      # you want it to be configured.
      #
      # *Note*: {#dynamodb_client} is inherited from a parent model when
      # +configure_client+ is explicitly specified in the parent.
      # @param [Hash] opts the options you wish to use to create the client.
      #  Note that if you include the option +:client+, all other options
      #  will be ignored. See the documentation for other options in the
      #  {https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDB/Client.html#initialize-instance_method
      #  AWS SDK for Ruby}.
      # @option opts [Aws::DynamoDB::Client] :client allows you to pass in your
      #  own pre-configured client.
      def configure_client(opts = {})
        @dynamodb_client = if self.class != Module && Aws::Record.extends_record?(self) && opts.empty? &&
                              superclass.instance_variable_get('@dynamodb_client')
                             superclass.instance_variable_get('@dynamodb_client')
                           else
                             _build_client(opts)
                           end
      end

      # Gets the
      # {https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDB/Client.html Client}
      # instance that Transactions use. When called for the first time, if
      # {#configure_client} has not yet been called, will configure a new
      # client for you with default parameters.
      #
      # *Note*: +dynamodb_client+ is inherited from a parent model when
      # {configure_client} is explicitly specified in the parent.
      #
      # @return [Aws::DynamoDB::Client] the Amazon DynamoDB client instance.
      def dynamodb_client
        @dynamodb_client ||= configure_client
      end

      private

      def _build_client(opts = {})
        provided_client = opts.delete(:client)
        client = provided_client || Aws::DynamoDB::Client.new(opts)
        client.config.user_agent_frameworks << 'aws-record'
        client
      end
    end
  end
end
