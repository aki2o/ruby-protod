FactoryBot.define do
  factory :proto_part, class: Protod::Proto::Part do
    ident { Faker::Food.fruits.gsub(' ', '').gsub("'", '_') }
    comment { [nil, Faker::String.random].sample }

    after(:build) do |instance, evaluator|
      instance.attributes.values.filter { _1.is_a?(::Array) }.each do |children|
        children.each { _1.assign_attributes(parent: instance) }
      end
    end
  end

  factory :proto_package, parent: :proto_part, class: Protod::Proto::Package do
    url { nil }
    branch { nil }
    for_ruby { nil }
    for_java { nil }

    trait :external do
      url { Faker::Internet.url }
      branch { [nil, 'main', 'develop'].sample }
    end

    trait :has_child do
      transient do
        size { 1 }
      end

      packages { build_list(:proto_package, size) }
      services { build_list(:proto_service, size, :has_child, size: size) }
      messages { build_list(:proto_message, size, :has_child, size: size) }
    end

    trait :has_children do
      has_child
      size { (2..9).to_a.sample }
    end
  end

  factory :proto_service, parent: :proto_part, class: Protod::Proto::Service do
    trait :has_child do
      transient do
        size { 1 }
      end

      procedures { build_list(:proto_procedure, size) }
    end

    trait :has_children do
      has_child
      size { (2..9).to_a.sample }
    end
  end

  factory :proto_procedure, parent: :proto_part, class: Protod::Proto::Procedure do
    singleton { [true, false].sample }

    trait :singleton do
      singleton { true }
    end

    trait :instance do
      singleton { false }
    end

    trait :has_child do
      transient do
        size { 1 }
      end
    end

    trait :has_children do
    end
  end

  factory :proto_message, parent: :proto_part, class: Protod::Proto::Message do
    trait :has_child do
      transient do
        size { 1 }
      end

      messages { build_list(:proto_message, size) }
      fields { [*build_list(:proto_field, size), *build_list(:proto_oneof, size, :has_child, size: size)] }
    end

    trait :has_children do
      has_child
      size { (2..9).to_a.sample }
    end
  end

  factory :proto_field, parent: :proto_part, class: Protod::Proto::Field do
    trait :has_child do
      transient do
        size { 1 }
      end
    end

    trait :has_children do
    end
  end

  factory :proto_oneof, parent: :proto_part, class: Protod::Proto::Oneof do
    trait :has_child do
      transient do
        size { 1 }
      end

      fields { build_list(:proto_field, size) }
    end

    trait :has_children do
      has_child
      size { (2..9).to_a.sample }
    end
  end
end
