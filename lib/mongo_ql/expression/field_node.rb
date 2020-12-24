# frozen_string_literal: true

module MongoQL
  class Expression::FieldNode < Expression
    attr_accessor :field_name

    def initialize(name)
      @field_name = name
    end

    def method_missing(method_name, *args, &block)
      if args.size > 0 || !block.nil? || [:to_hash].include?(method_name.to_sym)
        raise NoMethodError, "undefined method `#{method_name}' for #{self.class}"
      end
      Expression::FieldNode.new("#{field_name}.#{method_name}")
    end

    def f(field)
      Expression::FieldNode.new("#{field_name}.#{field}")
    end

    def exists?(val = true)
      if val
        self.if_null(nil).eq?(nil)
      else
        self.if_null(nil).neq?(nil)
      end
    end

    def to_ast
      "$#{field_name}"
    end

    def to_s
      field_name.to_s
    end

    def dsc
      Expression::Descend.new(self)
    end

    def asc
      Expression::Ascend.new(self)
    end
  end
end