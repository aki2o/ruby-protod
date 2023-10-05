RSpec.describe Protod::Proto::Oneof, type: :model do
  it_behaves_like :proto_part_root, parentables: [:proto_message]
  it_behaves_like :proto_part_ancestor_as, parentables: [:proto_message]
  it_behaves_like :proto_part_push, childables: [:proto_field]
  it_behaves_like :proto_part_freeze
end
