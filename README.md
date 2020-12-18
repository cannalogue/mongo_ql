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

# API

## Convert operators
| method     | mongo operator | example                 |
|------------|----------------|-------------------------|
| to_id      | $toObjectId    | string_id_field.to_id   |
| to_string  | $toString      | id_field.to_string      |
| to_int     | $toInt         |                         |
| to_long    | $toLong        | v("10.9").to_long       |
| to_date    | $toDate        | v("2020-01-19").to_date |
| to_decimal | $toDecimal     |                         |
| to_double  | $toDouble      |                         |
| downcase   | $toLower       | v("Ding").downcase      |
| upcase     | $toUpper       | name.upcase             |

## Date operators
| method        | mongo operator | example                             |
|---------------|----------------|-------------------------------------|
| year          | $year          | `created_at.as_date.year` # => 2020 |
| week          | $week          | `created_at.as_date.week`           |
| month         | $month         | `created_at.as_date.month`          |
| day_of_month  | $dayOfMonth    | `created_at.as_date.day_of_month`   |
| day_of_year   | $dayOfYear     |                                     |
| iso_week      | $isoWeek       |                                     |
| iso_week_Year | $isoWeekYear   |                                     |

## Binary/Unary operators
| method | mongo operator | example           |
|--------|----------------|-------------------|
| +      | $add           | field1 + field2   |
| -      | $subtract      | field1 - field2   |
| *      | $multiply      | field1 * field2   |
| /      | $divide        | field1 / field2   |
| >      | $gt            | field1 > 1        |
| gt?    | $gt            | field1.gt?(5)     |
| <      | $lt            |                   |
| lt?    | $lt            |                   |
| >=     | $gte           |                   |
| gte?   | $gte           |                   |
| <=     | $lte           |                   |
| lte?   | $lte           |                   |
| !=     | $ne            | field1 != nil     |
| neq?   | $ne            | field1.neq?(nil)  |
| ==     | $eq            |                   |
| eq?    | $eq            |                   |
| &      | $and           | expr1 & expr2     |
| \|     | $or            | expr1 \| expr2    |
| %      | %mod           | `v(12) % 5` #=> 2 |
| **     | $pow           | field1 ** 2       |
| !      | $not           | !expr1            |

## Collection operators
| method                     | mongo operator | example                   | group stage | array      |
|----------------------------|----------------|---------------------------|-------------|------------|
| max                        | $max           |                           | yes         | yes        |
| min                        | $min           |                           | yes         | yes        |
| sum                        | $sum           |                           | yes         | yes        |
| size                       | $size          |                           | no          | yes        |
| push                       | $push          |                           | yes         | no         |
| reverse                    | $reverseArray  |                           | no          | yes        |
| first                      | $first         |                           | yes         | no (< 4.4) |
| last                       | $last          |                           | yes         | no (< 4.4) |
| filter                     | $filter        |                           | no          | yes        |
| map                        | $map           |                           | no          | yes        |
| reduce                     | $reduce        |                           | no          | yes        |
| any?                       | $filter        |                           | no          | yes        |
| concat_arrays              | $concatArrays  |                           | no          | yes        |
| combine_sets               | $setUnion      |                           | no          | yes        |
| []                         | $arrayElemAt   | docs[0]                   | no          | yes        |
| contains/includes/include? | $in            | v([1,2]).include?(field1) | no          | yes        |

## String operators
| method | mongo operator | example                      |
|--------|----------------|------------------------------|
| substr | $substr        | name.substr(0, 5)            |
| trim   | $trim          | name.trim(",")               |
| concat | $concat        | first_name.concat(last_name) |

## Condition expression
`If a > b, then: 1, else: 2`