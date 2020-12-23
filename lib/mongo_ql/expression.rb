# frozen_string_literal: true

require_relative "binary_operators"
require_relative "unary_operators"
require_relative "collection_operators"
require_relative "string_operators"
require_relative "convert_operators"

module MongoQL
  class Expression
    include BinaryOperators
    include UnaryOperators
    include CollectionOperators
    include ConvertOperators
    include StringOperators

    def method_missing(method_name, *args, &block)
      if args.size > 0 || !block.nil? || [:to_hash].include?(method_name.to_sym)
        raise NoMethodError, "undefined method `#{method_name}' for #{self.class}"
      end
      Expression::FieldAccess.new(self, method_name)
    end

    def f(field)
      Expression::FieldAccess.new(self, field.to_s)
    end

    def type
      Expression::MethodCall.new "$type", self
    end

    def if_null(default_val)
      Expression::MethodCall.new "$ifNull", self, ast_template: -> (target, **_args) {
        [target, to_expression(default_val)]
      }
    end
    alias_method :default, :if_null

    def as_date
      Expression::DateNode.new(self)
    end

    def then(then_expr = nil, &block)
      Expression::Condition.new(self, then_expr, nil, &block)
    end

    def to_ast
      raise NotImplementedError, "#{self.class.name} must implement to_ast"
    end

    protected
      def to_expression(val)
        if val.is_a?(Expression)
          val
        else
          Expression::ValueNode.new(val)
        end
      end
  end
end