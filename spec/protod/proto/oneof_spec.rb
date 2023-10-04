RSpec.describe Protod::Proto::Oneof, type: :model do
  it_behaves_like :proto_part_root_feature, parentables: [:proto_message]
  it_behaves_like :proto_part_ancestor_as_feature, parentables: [:proto_message]
  it_behaves_like :proto_part_push_feature, childables: [:proto_field]
  it_behaves_like :proto_part_freeze_feature
end
