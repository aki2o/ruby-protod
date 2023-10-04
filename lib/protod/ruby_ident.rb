class Protod
  class RubyIdent
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :const_name, :string
    attribute :method_name, :string
    attribute :singleton, :boolean, default: false

    class << self
      def build_from(string)
        return if string.blank?

        string = string.gsub('__', '::')

        const_name, method_name, singleton = case
                                             when string.include?('.') 
                                               [*string.split('.'), true]
                                             when string.include?('#')
                                               [*string.split('#'), false]
                                             else
                                               [string, nil, false]
                                             end

        return unless const_name.safe_constantize

        new(const_name: const_name, method_name: method_name, singleton: singleton)
      end

      def absolute_of(ruby_ident)
        return if ruby_ident.blank?

        "::#{ruby_ident.to_s.delete_prefix('::')}"
      end
    end

    def const_name
      self.class.absolute_of(super)
    end

    def ==(other)
      to_s == other.to_s
    end

    def to_s
      [const_name, method_name].compact.join(singleton ? '.' : '#')
    end
  end
end
