module ActiveMocker
  # @api private
  class ModelReader

    attr_reader :model_name, :model_dir, :file_reader

    def initialize(options={})
      @file_reader = options[:file_reader] ||= FileReader
      @model_dir   = options[:model_dir]
    end

    def parse(model_name)
      @model_name = model_name
      klass
      return self unless @klass == false
      return false
    end

    def klass
      @klass ||= eval_file
    end

    def eval_file
      model_name.classify.constantize
    end

    def real
      model_name.classify.constantize
    end

    def read_file
      file_reader.read(file_path)
    end

    def file_path
      "#{model_dir}/#{model_name}.rb"
    end

    def instance_methods
      klass.public_instance_methods(false).reject do |meth|
        is_active_record_method(meth)
      end
    end

    def class_methods
      [[*klass.methods(false)] - [*scopes.keys]].flatten.reject do |meth|
        is_active_record_method(meth)
      end
    end

    def is_active_record_method(meth)
      starts_with = %w[
          autosave_associated_records_for_
          validate_associated_
          before_add_for_
          after_add_for_
          after_remove_for_
          before_remove_for_
          autosave_associated_records_for_
          validate_associated_records_for_
        ]
      is = %w[
          _validators
          defined_enums
          _destroy_callbacks
          _save_callbacks
          _create_callbacks
          _update_callbacks
          _validate_callbacks
          _reflections
          belongs_to_counter_cache_after_create
          belongs_to_counter_cache_before_destroy
          belongs_to_counter_cache_after_update
        ]
      return true if starts_with.any? { |name| /^#{name}/ =~ meth.to_s }
      return true if is.any? { |name| name.to_s == meth.to_s }
    end

    def scopes
      values = klass.instance_variable_get(:@scope_method_names)
      values =  values.nil? ? {} : values
      values
    end

    def scopes_with_arguments
      scopes.map do |name, parameters|
        {name => parameters}
      end
    end

    def class_methods_with_arguments
      class_methods.map do |m|
        {m => klass.method(m).parameters }
      end
    end

    def instance_methods_with_arguments
      instance_methods.map do |m|
        {m => klass.new.method(m).parameters }
      end
    end

    def relationships_types
      klass.relationships
    end

    def relationships
      relationships_types.to_h.values.flatten
    end

    def collections
      klass.collections.flatten.compact
    end

    def single_relationships
      klass.single_relationships.flatten.compact
    end

    def belongs_to
      klass.reflect_on_all_associations(:belongs_to)
    end

    def has_one
      klass.reflect_on_all_associations(:has_one)
    end

    def has_and_belongs_to_many
      klass.reflect_on_all_associations(:has_and_belongs_to_many)
    end

    def has_many
      klass.reflect_on_all_associations(:has_many)
    end

    def table_name
      klass.table_name
    end

    def primary_key
      klass.primary_key
    end

    def constants
      const = {}
      [klass.constants - klass.superclass.constants].flatten.each {|c| const[c] = klass.const_get(c)}
      const = const.reject do |c, v|
        v.class == Module || v.class == Class
      end
      const
    end

    def modules
      {included: process_module_names(klass.included_modules - klass.superclass.included_modules),
       extended: process_module_names(klass.singleton_class.included_modules - klass.superclass.singleton_class.included_modules)}
    end

    def process_module_names(names)
      names.reject { |m| /GeneratedAssociationMethods/ =~  m.name || m.name.nil? || /#{klass.name}/ =~ m.name }.map(&:inspect)
    end

  end

end

