require 'rails'

class Protod
  class TaskGenerator < Rails::Generators::Base
    def create_raketask
      create_file "lib/tasks/protod.rake", <<~RUBY
        # frozen_string_literal: true

        begin
          require 'protod/rake_task'

          Protod::RakeTask::Builder.new do |builder|
            # If you want to change the rake task namespace, comment in it.
            # default: :protod
            # builder.name = :pd
          end.build
        rescue LoadError => e
          $stderr.puts "#\{e\}\\nYou might should remove 'lib/tasks/protod.rake'."
        end
      RUBY
    end
  end
end
