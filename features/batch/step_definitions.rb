# frozen_string_literal: true

And(/^a (Parent|Child) model with TableConfig of:$/) do |model, code_block|
  case model
  when 'Parent'
    ParentTableModel = @parent # rubocop:disable Naming/ConstantName
  when 'Child'
    ChildTableModel = @model # rubocop:disable Naming/ConstantName
  else
    raise 'Model must be either a Parent or Child'
  end

  @table_config = eval(code_block)
end

When(/^we make a batch write call with following Parent and Child model items:$/) do |string|
  item_data = JSON.parse(string, symbolize_names: true)

  Aws::Record::Batch.write do |db|
    item_data.each do |item|
      case item[:model]
      when 'Parent'
        db.put(@parent.new(remove_model_key(item)))
      when 'Child'
        db.put(@model.new(remove_model_key(item)))
      else
        raise 'Model must be either a Parent or Child'
      end
    end
  end
end

And(/^we make a batch read call for the following Parent and Child model item keys:$/) do |string|
  key_batch = JSON.parse(string, symbolize_names: true)

  @batch_read_result = Aws::Record::Batch.read do |db|
    key_batch.each do |item_key|
      case item_key[:model]
      when 'Parent'
        db.find(@parent, remove_model_key(item_key))
      when 'Child'
        db.find(@model, remove_model_key(item_key))
      else
        raise 'Model must be either a Parent or Child'
      end
    end
  end
end

Then(/^we expect the batch read result to include the following items:$/) do |string|
  expected = JSON.parse(string, symbolize_names: true)
  actual = @batch_read_result.items.map(&:to_h)
  expect(expected.count).to eq(actual.count)
  expect(expected.all? { |e| actual.include?(e) }).to be_truthy
end

def remove_model_key(item)
  item.delete(:model)
  item
end
