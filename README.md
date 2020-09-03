# MongoQL
[![Gem](https://img.shields.io/gem/v/mongo_ql.svg?style=flat)](http://rubygems.org/gems/mongo_ql "View this project in Rubygems")
[![Actions Status](https://github.com/dingxizheng/mongo_ql/workflows/Ruby/badge.svg)](https://github.com/dingxizheng/mongo_ql/actions)
[![MIT license](http://img.shields.io/badge/license-MIT-brightgreen.svg)](http://opensource.org/licenses/MIT)

## Installation
Install from RubyGems by adding it to your `Gemfile`, then bundling.

```ruby
# Gemfile
gem 'mongo_ql'
```

```
$ bundle install
```

## Aggregation Pipeline DSL
```ruby
MongoQL.compose do
  where   deleted_at != nil

  where   created_at > "2018-10-10"

  add_fields extra => switch {
                        If      age < 10,  then: "<10"
                        If      age < 20,  then: "<20"
                        Default "Unknown"
                      }

  join    customers,
          on: customer_id == _id.to_id,
          as: customers

  join    shippings, as: shippings do |doc|
    match  order_id  == doc._id,
            status   == :shipped
  end

  match   province == "ON"

  project :_id,
          total,
          customer  => customers.name,
          tax       => total * tax_rate

  group   customer,
          total     => total.sum,
          total_tax => tax.sum * 5

  sort_by age.dsc
end
```

## The above aggregation DSL generates the following MongoDB pipeline
```json
[{
    "$match": {
      "$expr": {
        "$ne": ["$deleted_at", null]
      }
    }
  },
  {
    "$match": {
      "$expr": {
        "$gt": ["$created_at", {
          "$toDate": "2019-10-10"
        }]
      }
    }
  },
  {
    "$addFields": {
      "extra": {
        "$switch": {
          "branches": [{
              "case": {
                "$lt": ["$age", 10]
              },
              "then": "<10"
            },
            {
              "case": {
                "$lt": ["$age", 20]
              },
              "then": "<20"
            }
          ],
          "default": "Unknown"
        }
      }
    }
  },
  {
    "$lookup": {
      "from": "customers",
      "as": "customers",
      "localField": "customer_id",
      "foreignField": {
        "$toString": {
          "$toObjectId": "$_id"
        }
      }
    }
  },
  {
    "$lookup": {
      "from": "shippings",
      "as": "shippings",
      "pipeline": [{
        "$match": {
          "$expr": {
            "$and": [{
              "$eq": ["$order_id", "$$var__id"]
            }, {
              "$eq": ["$status", "shipped"]
            }]
          }
        }
      }],
      "let": {
        "var__id": "$_id"
      }
    }
  },
  {
    "$match": {
      "$expr": {
        "$eq": ["$province", "ON"]
      }
    }
  },
  {
    "$project": {
      "_id": 1,
      "total": 1,
      "customer": "$customers.name",
      "tax": {
        "$multiply": ["$total", "$tax_rate"]
      }
    }
  },
  {
    "$group": {
      "_id": "$customer",
      "total": {
        "$sum": "$total"
      },
      "total_tax": {
        "$multiply": [{
          "$sum": "$tax"
        }, 5]
      }
    }
  },
  {
    "$sort": {
      "age": -1
    }
  }
]
```

# How to run test
`ruby ./test/test_mongo_ql.rb`

# How to debug
`rdebug-ide --host 0.0.0.0 --port 1234 --dispatcher-port 1234 ./test/test_mongo_ql.rb`
then run debug from vscode

## debug in console
`./debug.sh`