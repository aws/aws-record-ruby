# Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

When(/^we call the 'query' class method with parameter data:$/) do |string|
  data = JSON.parse(string, symbolize_names: true)
  @collection = @model.query(data)
end

Then(/^we should receive an aws\-record collection with members:$/) do |string|
  expected = JSON.parse(string, symbolize_names: true)
  # Ensure that we have the same number of items, and no pagination.
  expect(expected.size).to eq(@collection.to_a.size)
  # Results do not have guaranteed order, check each expected value individually
  @collection.each do |item|
    h = item.to_h
    expect(expected.any? { |e| h == e }).to eq(true)
  end
end

When(/^we call the 'scan' class method$/) do
  @collection = @model.scan
end

When(/^we call the 'scan' class method with parameter data:$/) do |string|
  data = JSON.parse(string, symbolize_names: true)
  @collection = @model.scan(data)
end

When(/^we take the first member of the result collection$/) do
  @instance = @collection.first
end

Then(/^we should receive an aws\-record page with 2 values from members:$/) do |string|
  expected = JSON.parse(string, symbolize_names: true)
  page = @collection.page
  @last_evaluated_key = @collection.last_evaluated_key
  # This is definitely a hack which takes advantage of an accident in test
  # design. In the future, we'll need to have some sort of shared collection
  # state to cope with the fact that scan order is not guaranteed.
  page.size == 2
  # Results do not have guaranteed order, check each expected value individually
  page.each do |item|
    h = item.to_h
    expect(expected.any? { |e| h == e }).to eq(true)
  end
end

When(/^we call the 'scan' class method using the page's pagination token$/) do
  @collection = @model.scan(exclusive_start_key: @last_evaluated_key)
end

When("we run the following search:") do |code|
  SearchTestModel = @model
  @collection = eval(code)
end

When(/^we run a heterogeneous query$/) do
  @model_1 = @model.dup
  @model_2 = @model.dup
  scan = @model.build_scan.multi_model_filter do |raw_item_attributes|
    if raw_item_attributes['id'] == "1"
      @model_1
    elsif raw_item_attributes['id'] == "2"
      @model_2
    end
  end
  @collection = scan.complete!
end

Then(/^we should receive an aws-record collection with multiple model classes/) do
  result_classes = @collection.map(&:class)
  expect(result_classes).to include(@model_1, @model_2)
end
