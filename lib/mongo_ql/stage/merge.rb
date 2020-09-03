# frozen_string_literal: true

module MongoQL
  class Stage::Merge < Stage
    class NestedPipelineVars
      attr_accessor :vars

      def initialize
        @vars = {}
      end

      def method_missing(m, *args, &block)
        if is_setter?(m)
          set(m, args.first)
        else
          get(m)
        end
      end

      def get(name)
        vars["var_#{name}"] ||= Expression::FieldNode.new(name)
        Expression::FieldNode.new("$var_#{name}")
      end

      def set(name, val)
        vars["var_#{name.to_s[0..-2]}"] = val
      end

      private
        def is_setter?(method_name)
          method_name.to_s.end_with?("=")
        end
    end

    attr_accessor :ctx, :into, :on, :when_matched, :when_not_matched,
      :nested_pipeline_block, :let_vars, :nested_pipeline

    def initialize(ctx, into, on: nil, when_matched: nil, when_not_matched:, &block)
      @ctx       = ctx
      @into      = collection_name(into)
      @on        = field_name(on)
      @when_not_matched = when_not_matched.to_s
      @nested_pipeline_block = block

      unless ["insert", "discard", "fail"].include?(when_not_matched.to_s)
        raise ArgumentError, "when_not_matched must be one of <insert|discard|fail>"
      end

      if has_nested_pipeline?
        @let_vars = NestedPipelineVars.new
        @nested_pipeline = eval_nested_pipeline
      elsif ["replace", "keepExisting", "merge", "fail"].include?(when_matched.to_s)
        @when_matched = when_matched.to_s
      else
        raise ArgumentError, "when_not_matched must be one of <replace|keepExisting|merge|fail|pipeline>"
      end
    end

    def to_ast
      merge_expr = { "into" => into, "on" => on, "whenMatched" => when_matched, "whenNotMatched" => when_not_matched }
      if has_nested_pipeline?
        merge_expr["whenMatched"] = nested_pipeline
        merge_expr["let"]      = let_vars.vars
      end
      ast = { "$merge" => merge_expr }
      MongoQL::Utils.deep_transform_values(ast, &MongoQL::EXPRESSION_TO_AST_MAPPER)
    end

    private
      def has_nested_pipeline?
        !nested_pipeline_block.nil?
      end

      def eval_nested_pipeline
        sub_ctx = StageContext.new
        sub_ctx.instance_exec(let_vars, &nested_pipeline_block)
        sub_ctx
      end

      def collection_name(into)
        case into
        when String, Symbol
          into
        when Expression::FieldNode
          collection_name = into.to_s
          if collection_name.include?(".")
            db, collection = collection_name.split(".")
            { db: db, coll: collection }
          else
            collection_name
          end
        else
          if into&.respond_to?(:collection)
            into&.collection&.name
          elsif into&.respond_to?(:field_name)
            into.field_name
          else
            raise ArgumentError, "#{into} is not a valid collection"
          end
        end
      end

      def field_name(on)
        case on
        when String, Symbol
          on
        when Expression::FieldNode
          on.to_s
        when Array
          on.map(&method(:field_name))
        else
          raise ArgumentError, "#{on} is not valid field name"
        end
      end
  end
end