RSpec.shared_context :load_configuration do
  before { Protod.configuration }
end

RSpec.shared_context :setup_rbs do
  around do |example|
    Dir.mktmpdir do |dir|
      dir = Pathname(dir)

      File.write(dir.join('1.rbs'), rbs) if rbs

      Protod.configure do |c|
        c.setup_rbs_environment_loader { _1.add(path: dir) }
      end

      Protod.configuration

      example.run
    end
  end
  let(:rbs) { nil }
end
