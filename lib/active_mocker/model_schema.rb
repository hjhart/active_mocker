module ActiveMocker

  module LoggerToJson

    def initialize(*args)
      super(args)
      UnitLogger.unit.info "#{caller_locations[1]}\n"
      obj = JSON.parse(self.to_hash.to_json)
      UnitLogger.unit.info "#{self.class.name}: #{JSON.pretty_unparse(obj)}\n"
      puts "#{self.class.name}: #{JSON.pretty_unparse(obj)}\n"
    end

  end

  class ModelSchemaCollection

    include Enumerable

    attr_accessor :collection

    def initialize(collection)
      @collection = collection
    end

    def each(&block)
      collection.each do |item|
        block.call(item)
      end
    end

    def find_by(options={})
      collection.select{|c| c.send(options.keys.first) == options.values.first}.first
    end

    def find_by_in_relationships(options={})
      result = nil
      collection.each do |item|
        result = item.relationships.select do |attr|
          attr.send(options.keys.first) == options.values.first
        end
      end
      result
    end


    def [](val)
      collection[val]
    end

  end

  class ModelSchema

    include LoggerToJson

    attr_reader :class_name, :table_name, :attributes, :relationships, :methods

    def initialize( class_name:    nil,
                    table_name:    nil,
                    attributes:    nil,
                    relationships: nil,
                    methods:       nil,
                    constants:     nil,
                    is_join_table: nil,
                    join_table_members: nil
                    )
      @class_name    = class_name
      @table_name    = table_name
      @attributes    = attributes    unless attributes.nil?
      @relationships = relationships unless relationships.nil?
      @methods       = methods       unless (methods || []).empty?
      @constants     = constants     unless (constants || []).empty?
      @is_join_table = is_join_table unless is_join_table.nil?
      @join_table_members = join_table_members unless join_table_members.nil?

      # UnitLogger.unit.info "#{caller_locations[1]}\n"
      # obj = ::JSON.parse(self.to_json)
      # UnitLogger.unit.info "#{self.class.name}: #{JSON.pretty_unparse(obj)}\n"
      # puts "#{self.class.name}: #{JSON.pretty_unparse(obj)}\n"
    end

    def constants
      @constants || []
    end

    def has_many
      relation_find(:type, :has_many)
    end

    def has_one
      relation_find(:type, :has_one)
    end

    def belongs_to
      relation_find(:type, :belongs_to)
    end

    def has_and_belongs_to_many
      relation_find(:type, :has_and_belongs_to_many)
    end

    def belongs_to_foreign_key(foreign_key)
      belongs_to.select { |r| r.foreign_key.to_sym == foreign_key.to_sym }.first
    end

    def relation_find(key, value)
      relationships.select { |r| r.send(key).to_sym == value }
    end

    def instance_methods
      method_find(:instance)
    end

    def class_methods
      method_find(:class)
    end

    def method_find(type)
      return [] if methods.nil?
      methods.select { |r| r.type.to_sym == type }
    end

    def attribute_names
      attributes.map(&:name)
    end

    def types_hash
      types = {}
      attributes.each do |attr|
        types[attr.name] = "build_type(#{attr.ruby_type})"
      end

      type_array = types.map do |name, type|
        "#{name}: #{type}"
      end
      '{ ' + type_array.join(', ') + ' }'
    end

    def attributes_with_defaults
      hash = {}
      attributes.each do |attr|
        hash[attr.name] = attr.default_value
      end
      hash
    end

    def associations
      hash = {}
      relationships.each do |r|
        hash[r.name] = nil
      end
      hash
    end

    def mock_name(klass_name)
      klass_name + "Mock"
    end

    def class_method_not_implemented
      not_implemented(class_methods)
    end

    def instance_method_not_implemented
      not_implemented(instance_methods)
    end

    def not_implemented(collection)
      hash = {}
      collection.each do |meth|
        hash[meth.name.to_s] = :not_implemented
      end
      hash
    end

    def render(template, mock_append_name)
      @mock_append_name = mock_append_name
      ERB.new(template, nil, '-').result(binding)
    end

    private :relation_find

    def primary_key
      key = attributes.select { |attr| attr.primary_key }.first
      return key if key
      Attributes.new(name: 'id', primary_key: true, type: :integer)
    end

    class Attributes

      attr_reader :name, :type, :precision, :scale, :default_value, :primary_key
      attr_writer :primary_key
      def initialize(name:,
                     type:,
                     precision:     nil,
                     scale:         nil,
                     default_value: nil,
                     primary_key:   nil
      )
        @name          = name
        @type          = type
        @precision     = precision     unless precision.nil?
        @scale         = scale         unless scale.nil?
        @default_value = default_value unless default_value.nil?
        @primary_key   = primary_key   unless primary_key.nil?
      end

      def ruby_type
        ActiveMocker::DBToRubyType.call(type)
      end

    end

    class Relationships

      attr_reader :name, :class_name, :type, :through, :foreign_key, :join_table

      def initialize(name:,
          class_name:,
          type:,
          through:,
          foreign_key:,
          join_table:
      )
        @name        = name
        @class_name  = class_name
        @type        = type
        @through     = through     unless through.nil?
        @foreign_key = foreign_key unless foreign_key.nil?
        @join_table  = join_table  unless join_table.nil?
      end

    end

    class Methods

      attr_reader :name, :arguments, :type

      def initialize( name:,
                      arguments:,
                      type:
                    )
        @name      = name
        @arguments = Arguments.new(arguments)
        @type      = type
      end

      class Arguments

        attr_reader :arguments

        def initialize(arguments)
          @arguments = arguments
        end

        def to_hash
          @arguments
        end

        def to_s
          Reparameterize.call(arguments)
        end

        def passable
          Reparameterize.call(arguments, param_list: true)
        end

      end

    end

  end

end