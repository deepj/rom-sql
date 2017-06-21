module ROM
  module Plugins
    module Relation
      module SQL
        # Generates methods for restricting relations by their indexed attributes
        #
        # @example
        #   rom = ROM.container(:sql, 'sqlite::memory') do |config|
        #     config.create_table(:users) do
        #       primary_key :id
        #       column :email, String, null: false, unique: true
        #     end
        #
        #     config.plugin(:sql, relations: :auto_restrictions)
        #
        #     config.relation(:users) do
        #       schema(infer: true)
        #     end
        #   end
        #
        #   # now `by_email` is available automatically
        #   rom.relations[:users].by_email('jane@doe.org')
        #
        # @api public
        module AutoRestrictions
          def self.apply(klass)
            schema = klass.schema
            raise EmptySchemaError, klass if schema.empty?

            methods, mod = restriction_methods(schema)
            klass.include(mod)
            methods.each { |meth| klass.auto_curry(meth) }
          end

          module FinalizationHook
            def set_schema!(*)
              super.tap { AutoRestrictions.apply(self) }
            end
          end

          def self.included(klass)
            super

            if klass.schema
              AutoRestrictions.apply(klass)
            else
              klass.extend(FinalizationHook)
            end
          end

          def self.restriction_methods(schema)
            mod = Module.new

            indexed_attrs = schema.select { |attr| attr.meta[:index] }

            methods = indexed_attrs.map do |attr|
              meth_name = :"by_#{attr.name}"

              mod.module_eval do
                define_method(meth_name) do |value|
                  where(attr.is(value))
                end
              end

              meth_name
            end

            [methods, mod]
          end
        end
      end
    end
  end
end

ROM.plugins do
  adapter :sql do
    register :auto_restrictions, ROM::Plugins::Relation::SQL::AutoRestrictions, type: :relation
  end
end
