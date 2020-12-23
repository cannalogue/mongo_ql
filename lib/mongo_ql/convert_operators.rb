module MongoQL
  module ConvertOperators
    FORMATING_OPS = {
      "to_object_id": "$toObjectId",
      "to_id":        "$toObjectId",
      "to_s":         "$toString",
      "to_string":    "$toString",
      "to_int":       "$toInt",
      "to_long":      "$toLong",
      "to_bool":      "$toBool",
      "to_date":      "$toDate",
      "to_decimal":   "$toDecimal",
      "to_double":    "$toDouble",
      "downcase":     "$toLower",
      "to_lower":     "$toLower",
      "upcase":       "$toUpper",
      "to_upper":     "$toUpper"
    }.freeze

    FORMATING_OPS.keys.each do |op|
      class_eval <<~RUBY
        def #{op}
          Expression::MethodCall.new(FORMATING_OPS[__method__], self)
        end
      RUBY
    end

    def round(precision)
      Expression::MethodCall.new "$round", self, ast_template: -> (target, **_args) {
        [target, precision]
      }
    end
  end
end