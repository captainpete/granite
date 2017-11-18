require "../spec_helper"

{% for adapter in ["pg","mysql","sqlite"] %}

  {%
   suffix = adapter.camelcase.id
   adapter_literal = adapter.id

   model_constant = "Parent#{suffix}".id
   model_string = "Parent#{suffix}".underscore.id
   model_table = model_string + "s"

   if adapter == "pg"
     primary_key_sql = "id SERIAL PRIMARY KEY".id
   elsif adapter == "mysql"
     primary_key_sql = "id INT NOT NULL AUTO_INCREMENT PRIMARY KEY".id
   elsif adapter == "sqlite"
     primary_key_sql = "id INTEGER NOT NULL PRIMARY KEY".id
   end
  %}

  require "../src/adapter/{{ adapter_literal }}"

  class {{ model_constant }} < Granite::ORM::Base
    primary id : Int32
    adapter {{ adapter_literal }}
    table_name {{ model_table }}

    field name : String
  end

  {{ model_constant }}.exec("DROP TABLE IF EXISTS {{ model_table }};")
  {{ model_constant }}.exec("CREATE TABLE {{ model_table }} (
    {{ primary_key_sql }},
    name VARCHAR(10)
  );
  ")

  describe {{ adapter }} do
    Spec.before_each do
      {{ model_constant }}.clear
    end

    describe "#find_in_batches" do
      it "finds records in batches and yields all the records" do
        model_ids = (0...100).map do |i|
          {{ model_constant }}.new(name: "model_#{i}").tap(&.save)
        end.map(&.id)

        found_models = [] of Int32 | Nil
        {{ model_constant }}.find_in_batches(batch_size: 10) do |batch|
          batch.each { |model| found_models << model.id }
          batch.size.should eq 10
        end

        found_models.compact.sort.should eq model_ids.compact
      end

      it "doesnt yield when no records are found" do
        {{ model_constant }}.find_in_batches do |model|
          fail "find_in_batches did yield but shouldn't have"
        end
      end

      it "errors when batch_size is < 1" do
        expect_raises ArgumentError do
          {{ model_constant }}.find_in_batches batch_size: 0 do |model|
            fail "should have raised"
          end
        end
      end

      it "returns a small batch when there arent enough results" do
        (0...9).each do |i|
          {{ model_constant }}.new(name: "model_#{i}").save
        end

        {{ model_constant }}.find_in_batches(batch_size: 11) do |batch|
          batch.size.should eq 9
        end
      end

      it "can start from an offset other than 0" do
        created_models = (0...10).map do |i|
          {{ model_constant }}.new(name: "model_#{i}").tap(&.save)
        end.map(&.id)

        # discard the first two models
        created_models.shift
        created_models.shift

        found_models = [] of Int32 | Nil

        {{ model_constant }}.find_in_batches(offset: 2) do |batch|
          batch.each do |model|
            found_models << model.id
          end
        end

        found_models.compact.sort.should eq created_models.compact
      end

      it "doesnt obliterate a parameterized query" do
        created_models = (0...10).map do |i|
          {{ model_constant }}.new(name: "model_#{i}").tap(&.save)
        end.map(&.id)

        looking_for_ids = created_models[0...5]

        {{ model_constant }}.find_in_batches("WHERE id IN(#{looking_for_ids.join(",")})") do |batch|
          batch.map(&.id).compact.should eq looking_for_ids
        end
      end
    end

    describe "#find_each" do
      it "finds all the records" do
        model_ids = (0...100).map do |i|
          {{ model_constant }}.new(name: "role_#{i}").tap {|r| r.save }
        end.map(&.id)

        found_roles = [] of Int32 | Nil
        {{ model_constant }}.find_each do |model|
          found_roles << model.id
        end

        found_roles.compact.sort.should eq model_ids.compact
      end

      it "doesnt yield when no records are found" do
        {{ model_constant }}.find_each do |model|
          fail "did yield"
        end
      end

      it "can start from an offset" do
        created_models = (0...10).map do |i|
          {{ model_constant }}.new(name: "model_#{i}").tap(&.save)
        end.map(&.id)

        # discard the first two models
        created_models.shift
        created_models.shift

        found_models = [] of Int32 | Nil

        {{ model_constant }}.find_each(offset: 2) do |model|
          found_models << model.id
        end

        found_models.compact.sort.should eq created_models.compact
      end

      it "doesnt obliterate a parameterized query" do
        created_models = (0...10).map do |i|
          {{ model_constant }}.new(name: "model_#{i}").tap(&.save)
        end.map(&.id)

        looking_for_ids = created_models[0...5]

        found_models = [] of Int32 | Nil
        {{ model_constant }}.find_each("WHERE id IN(#{looking_for_ids.join(",")})") do |model|
          found_models << model.id
        end

        found_models.compact.should eq looking_for_ids
      end
    end

  end

{% end %}