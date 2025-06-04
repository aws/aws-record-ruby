# frozen_string_literal: true

When('we make a global transact_find call with parameters:') do |param_block|
  params = eval(param_block)
  @transact_get_result = Aws::Record::Transactions.transact_find(params)
end

When('we run the following transactional find:') do |code|
  @transact_get_result = eval(code)
end

Then('we expect a transact_find result that includes the following items:') do |result_block|
  tfind_result = eval(result_block)
  expected = tfind_result.map do |item|
    if item.nil?
      nil
    else
      item.to_h
    end
  end
  actual = @transact_get_result.responses.map do |item|
    if item.nil?
      nil
    else
      item.to_h
    end
  end
  expect(expected).to eq(actual)
end

When('we run the following code:') do |code|
  @arbitrary_code_ret = eval(code)
rescue StandardError => e
  @arbitrary_code_exception = e
end

Then('we expect the code to raise an {string} exception') do |exception_class|
  expect(@arbitrary_code_exception.class).to eq(Kernel.const_get(exception_class))
end
