# frozen_string_literal: true

require_relative "test_helper"

class TestMontoQL < Minitest::Test
  def setup
    @time_now ||= DateTime.now
    @result_pipeline = [
      {"$match"   => {"$expr" => {"$ne" => ["$deleted_at", nil]}}},
      {"$match"   => {"$expr" => {"$gt" => ["$created_at", { "$toDate" => DateTime.now(1573191861).iso8601 }]}}},
      {"$addFields" => {"extra" => {"$switch" => {
        "branches" => [
          {"case" => { "$lt" => ["$age", 10] }, "then" => "<10"},
          {"case" => { "$lt" => ["$age", 20] }, "then" => "<20"}
        ],
        "default" => "Unknown"
      }}}},
      {"$lookup"  => {"from" => "customers", "as" => "customers", "localField" => "customer_id", "foreignField" => {"$toString" => {"$toObjectId" => "$_id"}}}},
      {"$lookup"  => {"from" => "shippings", "as" => "shippings", "pipeline" => [{"$match" => {"$expr" => {"$and" => [{"$eq" => ["$order_id", "$$var__id"]}, {"$eq" => ["$status", :shipped]}]}}}], "let" => {"var__id" => "$_id"}}},
      {"$match"   => {"$expr" => {"$eq" => ["$province", "ON"]}}},
      {"$project" => {"_id" => 1, "total" => 1, "customer" => "$customers.name", "tax" => {"$multiply" => ["$total", "$tax_rate"]}}},
      {"$group"   => {"_id" => "$customer", "name" => { "$first" => "$name" }, "year" => { "$first" => "$year" }, "total" => {"$sum" => "$total"}, "total_tax" => {"$round" => [{"$multiply" => [{"$sum" => "$tax"}, 5]}, 2]}}},
      {"$sort"    => {"age" => -1}},
      {"$limit"   => 1},
      {"$merge"   => {"into" => "orders", "on" => "_id", "whenMatched" => "merge", "whenNotMatched" => "insert" }},
      {"$merge"   => {"into" => "orders", "on" => "_id", "whenMatched" => [
        {"$addFields" => {"new_field_to_be_inserted_after_merge"=> "$$var_quantity"}},
        {"$project" => { "new_field_to_be_inserted_after_merge" => 1, "_id" => 1 }},
      ], "whenNotMatched" => "fail","let"=>{"var_quantity"=>1}}},
    ]
  end

  def test_compose
    time_now = DateTime.now(1573191861)
    pipeline = MongoQL.compose do
      where   deleted_at != nil

      where   created_at > time_now

      add_fields extra => switch {
                            cond    age < 10,  then: "<10"
                            cond    age < 20,  then: "<20"
                            default "Unknown"
                          }

      join    customers,
              on: customer_id == _id.to_id,
              as: customers

      join    shippings, as: shippings do |doc|
      match   order_id == doc._id,
              status   == :shipped
      end

      match   province == "ON"

      project :_id,
              total,
              customer  => customers.name,
              tax       => total * tax_rate

      group   customer, name, first_of(year),
              total     => total.sum,
              total_tax => (tax.sum * 5).round(2)

      sort_by age.dsc

      limit   1

      merge orders, on: _id, when_matched: :merge, when_not_matched: :insert
      merge orders, on: _id, when_not_matched: :fail do |var|
        var.quantity = 1
        add_fields new_field_to_be_inserted_after_merge => var.quantity
        project new_field_to_be_inserted_after_merge, _id
      end
    end
    assert_equal pipeline.to_ast, @result_pipeline
  end
end