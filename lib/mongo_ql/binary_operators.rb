# frozen_string_literal: true

module MongoQL
  module BinaryOperators
    BINARY_OPS = {
      "+":  "$add",
      "-":  "$subtract",
      "*":  "$multiply",
      "/":  "$divide",
      ">":  "$gt",
      "gt?":  "$gt",
      "<":  "$lt",
      "lt?":  "$lt",
      ">=": "$gte",
      "gte?":  "$gte",
      "<=": "$lte",
      "lte?":  "$lte",
      "!=": "$ne",
      "neq?":  "$ne",
      "==": "$eq",
      "eq?":  "$eq",
      "&":  "$and",
      "and": "$and",
      "|":  "$or",
      "or": "$or",
      "%":  "$mod",
      "**": "$pow"
    }.freeze

    BINARY_OPS.keys.each do |op|
      class_eval <<~RUBY
        def #{op}(right_node)
          Expression::Binary.new(BINARY_OPS[__method__], self, right_node)
        end
      RUBY
    end
  end
end