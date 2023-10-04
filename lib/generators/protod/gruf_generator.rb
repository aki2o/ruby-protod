require 'rails'

class Protod
  class GrufGenerator < Rails::Generators::Base
    def create_gruf_controller
      create_file "app/rpc/protod/handler_controller.rb", <<~RUBY
        # frozen_string_literal: true

        class Protod
          class HandlerController < ::Gruf::Controllers::Base
            include ::Gruf::Loggable

            def self.package
              @package ||= Protod::Rpc::Handler.find_package
            end

            bind Protod::Rpc::Handler.find_service_in(package).pb_const

            def handle
              return enum_for(:handle) unless block_given?

              logger.info("protod/handle start")
              handler = Protod::Rpc::Handler.new(self.class.package)

              request.messages.each do |m|
                logger.debug("protod/handle receive : #\{m\}")
                yield handler.handle(m).tap { logger.debug("protod/handle send : #\{_1\}") }
              end
              logger.info("protod/handle finished")
            rescue Protod::Rpc::Handler::InvalidArgument => e
              logger.debug("protod/handle failed : #\{e.message\}")
              fail!(:invalid_argument, :invalid_argument, "ERROR: #\{e.message\}")
            rescue Exception => e
              logger.error("protod/handle failed : #\{e.message\}\\n#\{e.backtrace.join("\\n")\}")
              set_debug_info(e.message, e.backtrace[0..4])
              fail!(:internal, :internal, "ERROR: #\{e.message\}")
            end
          end
        end
      RUBY
    end
  end
end
