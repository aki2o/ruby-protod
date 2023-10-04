require 'rake'
require 'rake/tasklib'

class Protod
  class RakeTask < Rake::TaskLib
    class Builder
      attr_accessor :name

      def initialize(&body)
        body&.call(self)
      end

      def build
        Protod::RakeTask.new(**{ name: name }.compact)
      end
    end

    def initialize(name: :protod)
      super()

      @name = name

      define_generate_proto_task
      define_generate_pb_task
      define_run_gruf
    end

    def define_generate_proto_task
      desc 'Generate proto files'
      task("#{@name}:generate:proto": :environment) do
        Protod.setup!

        root = Pathname.new(Protod.configuration.proto_root_dir)

        Protod::Proto::Package.roots.flat_map { _1.all_packages.reject(&:external?).reject(&:empty?) }.each do |package|
          path = root.join(*package.full_ident.split('.').tap { _1.last << '.proto' })

          FileUtils.mkdir_p(path.parent) unless File.exist?(path.parent)

          puts "Start to generate #{path} ..."
          File.write(path, package.to_proto)
        end
      end
    end

    def define_generate_pb_task
      desc 'Generate protocol buffers files'
      task("#{@name}:generate:pb": :environment) do
        Protod.setup!

        proto_dir = Pathname.new(Protod.configuration.proto_root_dir)
        pb_dir    = File.absolute_path(Pathname.new(Protod.configuration.pb_root_dir))

        FileUtils.mkdir_p(pb_dir) unless File.exist?(pb_dir)

        Dir.mktmpdir do |dir|
          dir = Pathname(dir)

          Protod::Proto::Package.roots.flat_map(&:all_packages).filter { _1.url.present? }.each.with_index(1) do |package, i|
            args    = [package.url, dir.join("_ext#{i}_#{package.url.split('/').last}")]
            options = { depth: 1, branch: package.branch }.compact

            option_part = options.map { |k, v| "--#{k} #{v}" }.join(' ')
            arg_part    = args.map { Shellwords.shellescape(_1) }.join(' ')
            cmd         = "git clone #{option_part} #{arg_part}"

            puts "#{cmd}"
            system(cmd) or raise "Failed to generate pb!"
          end

          include_option = Dir.glob("#{dir}/*").map { "-I#{_1}" }.join(' ')
          cmd            = "bundle exec grpc_tools_ruby_protoc #{include_option} -I#{proto_dir} --ruby_out=#{pb_dir} --grpc_out=#{pb_dir} `find #{proto_dir} -type f -name '*.proto'`"

          puts "#{cmd}"
          system(cmd) or raise "Failed to generate pb!"
        end

        puts "Finished to generate pb."
      end
    end

    def define_run_gruf
      desc 'Run gruf'
      task("#{@name}:gruf": :environment) do
        require 'protod/protocol_buffers'

        ::Gruf::Cli::Executor.new.run
      end
    end
  end
end
