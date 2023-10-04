class Protod
  module Rpc
    class Request
      class << self
        def register_for(*ruby_idents, with:, force: true, ignore: false, &body)
          ruby_idents.map { Protod::RubyIdent.absolute_of(_1) }.each do |ruby_ident|
            next if map.key?(ruby_ident) && ignore

            raise ArgumentError, "Request already regsitered for #{ruby_ident}" if map.key?(ruby_ident) && !force

            map[ruby_ident] = Class.new(with, &body).tap do |const|
              const.ruby_ident = Protod::RubyIdent.build_from(ruby_ident)
            end
          end
        end

        def find_by(ruby_ident)
          map[Protod::RubyIdent.absolute_of(ruby_ident)]
        end

        def keys
          map.keys
        end

        def clear!
          @map = nil
        end

        private

        def map
          @map ||= {}
        end
      end

      class Base
        class_attribute :ruby_ident
      end

      class Receiver
        ONEOF_NAME = 'procedure'

        class << self
          def register_for(*ruby_idents, with: Base, **options, &body)
            Protod::Rpc::Request.register_for(*ruby_idents, **options.merge(with: with), &body)
          end
        end

        class Base < Protod::Rpc::Request::Base
          class_attribute :procedures

          def self.push_procedure(*names, singleton: false)
            ruby_idents = names.map { Protod::RubyIdent.new(const_name: ruby_ident, method_name: _1, singleton: singleton) }

            Protod::Rpc::Request.register_for(*ruby_idents, with: Protod::Rpc::Request::Base, force: false, ignore: true)

            self.procedures ||= []
            self.procedures.push(*ruby_idents)
          end

          def self.procedure_pushed?(name, singleton: false)
            procedures&.include?(Protod::RubyIdent.new(const_name: ruby_ident, method_name: name, singleton: singleton)) || false
          end
        end
      end
    end
  end
end
