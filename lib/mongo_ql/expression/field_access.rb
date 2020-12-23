# frozen_string_literal: true

module MongoQL
  class Expression::FieldAccess < Expression
    attr_accessor :target, :field_name

    def initialize(target, field_name)
      @target = target
      @field_name = field_name
    end

    def to_ast
      {
        "$let" => {
          "vars" => { "let_var" => target },
          "in" => "$$let_var.#{field_name}"
        }
      }
    end
  end
end