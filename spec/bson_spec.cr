require "../src/bson"
require "spec"
require "json"

macro expect_value(v)
  %v = {{v}}
  if %v.is_a?(BSON::Value)
    %v.value
  else
    fail "expected a value but got #{{{v}}}"
  end
end

describe BSON::ObjectId do
  it "should be able to create a new ObjectId" do
    oid = BSON::ObjectId.new
    oid.should_not be_nil
  end

  it "should be able to create ObjectId from a string" do
    oid = BSON::ObjectId.new
    str = oid.to_s
    other = BSON::ObjectId.new(str)
    oid.should eq(other)
  end

  it "should be able to calculate an ObjectId hash" do
    oid = BSON::ObjectId.new
    oid.hash.should be > 0
  end

  it "should be able to create ObjectId from a json string" do
    id = "5e70ec155a1ead37204e05f1"
    json = %("#{id}")
    oid = BSON::ObjectId.from_json(json)
    oid.to_s.should eq id
    oid.to_json.should eq json
  end

  it "should be able to get a time" do
    oid = BSON::ObjectId.new
    (oid.time - Time.utc).should be < 1.seconds
  end

  it "should be able to compare ObjectIds" do
    oid1 = BSON::ObjectId.new
    oid2 = BSON::ObjectId.new
    oid1.should be < oid2
  end

  it "should be able to convert to a non null-terminated string" do
    oid = BSON::ObjectId.new
    str = oid.to_s
    str.check_no_null_byte
  end
end

describe BSON::Timestamp do
  it "should be comparable" do
    t = Time.utc
    t1 = BSON::Timestamp.new(t.to_unix.to_u32, 1)
    t2 = BSON::Timestamp.new(t.to_unix.to_u32, 2)
    t2.should be > t1
  end
end

describe BSON do
  it "should be able to create an empty bson" do
    bson = BSON.new
    bson.count.should eq(0)
  end

  it "should be able to append Int32" do
    bson = BSON.new
    bson["int_val"] = 1
    bson.count.should eq(1)
    bson.has_key?("int_val").should be_true
    expect_value(bson.each.next).should eq(1)
  end

  it "should be able to append binary" do
    bson = BSON.new
    bson["bin"] = BSON::Binary.new(BSON::Binary::SubType::Binary, "binary".to_slice)
    bson.count.should eq(1)
    bson.has_key?("bin").should be_true
  end

  it "should be able to append uuid" do
    bson = BSON.new
    uuid = UUID.random
    bson["uuid"] = uuid
    bson.count.should eq(1)
    bson.has_key?("uuid").should be_true
    UUID.from_bson(bson["uuid"]).should eq uuid
  end

  it "should be able to append boolean" do
    bson = BSON.new
    bson["bool"] = true
    bson.count.should eq(1)
    bson.has_key?("bool")
  end

  it "should be able to append float" do
    bson = BSON.new
    bson["double"] = 1.0
    expect_value(bson.each.next).should eq(1.0)
  end

  it "should be able to append Int64" do
    bson = BSON.new
    bson["int64"] = 1_i64
    expect_value(bson.each.next).should eq(1_i64)
  end

  it "should be able to append min key" do
    bson = BSON.new
    bson["min"] = BSON::MinKey.new
    expect_value(bson.each.next).should eq(BSON::MinKey.new)
  end

  it "should be able to append max key" do
    bson = BSON.new
    bson["min"] = BSON::MaxKey.new
    expect_value(bson.each.next).should eq(BSON::MaxKey.new)
  end

  it "should be able to append nil" do
    bson = BSON.new
    bson["min"] = nil
    expect_value(bson.each.next).should be_nil
  end

  it "should be able to append ObjectId" do
    bson = BSON.new
    oid = BSON::ObjectId.new
    bson["oid"] = oid
    expect_value(bson.each.next).should eq(oid)
  end

  it "should be able to append string" do
    bson = BSON.new
    bson["en"] = "hello"
    bson["ru"] = "привет"
    bson["en"].should eq("hello")
    bson["ru"].should eq("привет")
  end

  it "should be able to append document" do
    bson = BSON.new
    bson["v"] = 1
    bson.append_document("doc") do |child|
      child["body"] = "document body"
    end

    doc = bson["doc"]
    if doc.is_a?(BSON)
      doc.has_key?("body").should be_true
      doc["body"].should eq("document body")
    else
      fail "doc must be BSON object"
    end
  end

  it "should invalidate child document after append" do
    bson = BSON.new
    bson["v"] = 1
    child = nil
    bson.append_document("doc") do |child|
      child.not_nil!["body"] = "document body"
    end
    expect_raises(Exception) do
      child.not_nil!["v"] = 2
    end
  end

  it "should be able to append an array" do
    bson = BSON.new
    bson["v"] = 1
    bson.append_array("ary") do |child|
      child << "a1"
      child << "a2"
      child << nil
      child << 1
    end

    ary = bson["ary"]
    if ary.is_a?(BSON)
      ary.count.should eq(4)
      ary["0"].should eq("a1")
      ary["2"].should be_nil
      ary["3"].should eq(1)
    else
      fail "ary must be BSON object"
    end
  end

  it "should be able to append symbol" do
    bson = BSON.new
    bson["s"] = BSON::Symbol.new("symbol")
    sym = bson["s"]
    if sym.is_a?(BSON::Symbol)
      sym.name.should eq("symbol")
    else
      fail "sym must be BSON::Symbol"
    end
  end

  it "should be able to append time" do
    t = Time.utc
    bson = BSON.new
    bson["time"] = t
    bson_t = bson["time"]
    if bson_t.is_a?(Time)
      bson_t.to_unix.should eq(t.to_utc.to_unix)
    else
      fail "expected Time"
    end
  end

  it "should be able to append timestamp" do
    t = Time.utc
    bson = BSON.new
    bson["ts"] = BSON::Timestamp.new(t.to_unix.to_u32, 1)
    bson["ts"].should eq(BSON::Timestamp.new(t.to_unix.to_u32, 1))
  end

  it "should be able to append regex" do
    bson = BSON.new
    re = /blah/im
    bson["re"] = re
    val = bson["re"]
    if val.is_a?(Regex)
      val.source.should eq(re.source)
      val.options.should eq(re.options)
    else
      fail "expected regex value"
    end
  end

  it "should be able to append code" do
    bson = BSON.new
    code = BSON::Code.new("function() { return 'OK'; }")
    bson["code"] = code
    bson["code"].should eq(code)
  end

  it "should be able to append code with scope" do
    bson = BSON.new

    scope = BSON.new
    scope["x"] = 42
    code = BSON::Code.new("function() { return x; }", scope)

    bson["code"] = code
    bson["code"].should eq(code)
  end

  it "should be able to append document" do
    bson = BSON.new
    child = BSON.new
    child["x"] = 42
    bson["doc"] = child
    bson["doc"].should eq(child)
  end

  it "should be able to concat document" do
    bson = BSON.new
    child = BSON.new
    child["x"] = 42
    bson["y"] = "y"
    bson.concat child
    bson["x"].should eq(child["x"])
  end

  it "should be comparable" do
    bson1 = BSON.new
    bson1["x"] = 1
    bson2 = BSON.new
    bson2["x"] = 2
    bson2.should be > bson1
  end

  it "should be able to iterate" do
    bson = BSON.new
    bson["bool"] = true
    bson["int"] = 1
    iter = bson.each
    expect_value(iter.next).should be_true
    expect_value(iter.next).should eq(1)
  end

  it "should be able to iterate pairs" do
    bson = BSON.new
    bson["bool"] = false
    bson["int"] = 1
    v = [{"bool", false}, {"int", 1}]
    count = 0
    bson.each_pair do |key, val|
      v[count][0].should eq(key)
      v[count][1].should eq(val.value)
      count += 1
    end
  end

  it "should be able to clear content" do
    bson = BSON.new
    bson["x"] = "string"
    bson.count.should eq(1)
    bson.clear
    bson.empty?.should be_true
  end

  it "should be able to clone BSON" do
    bson = BSON.new
    bson["x"] = 42
    bson["body"] = "content"

    copy = bson.clone
    copy.should eq(bson)
  end

  it "should be able to convert UUID to BSON" do
    uuid = UUID.random
    bson = BSON.new
    bson["uuid"] = uuid
    bson["uuid"].should be_a BSON::Binary
    UUID.from_bson(bson["uuid"]).should eq uuid
    bson["uuid"].as(BSON::Binary).data.should eq uuid.bytes.to_slice
  end

  it "should be able to convert Hash to BSON" do
    query = [{"$match" => {"status" => "A"}},
             {"$group" => {"_id" => "$cust_id", "total" => {"$sum" => "$amount"}}}]
    bson_query = query.to_bson
    elem1 = bson_query["0"]
    fail "expected BSON" unless elem1.is_a?(BSON)
    match = elem1["$match"]
    fail "expected BSON" unless match.is_a?(BSON)
    match["status"].should eq("A")
  end

  it "should be able to convert NamedTuple to BSON" do
    query = [{"$match": {"status": "A"}},
             {"$group": {"_id": "$cust_id", "total": {"$sum": "$amount"}}}]
    bson_query = query.to_bson
    elem1 = bson_query["0"]
    fail "expected BSON" unless elem1.is_a?(BSON)
    match = elem1["$match"]
    fail "expected BSON" unless match.is_a?(BSON)
    match["status"].should eq("A")
  end

  it "should be able to detect array type" do
    ary = ["a", "b", "c"]
    ary.to_bson.array?.should be_true
  end

  it "should be able to decode bson" do
    bson = BSON.new
    bson["x"] = 42
    bson.append_array("ary") do |child|
      child << 1
      child << 2
      child << 3
    end
    bson.append_document("doc") do |child|
      child["y"] = "text"
    end
    h = {"x" => 42, "ary" => [1, 2, 3], "doc" => {"y" => "text"}}
    bson.decode.should eq(h)
  end

  it "should be able to encode to bson" do
    h = {"x" => 42, "ary" => [1, 2, 3], "doc" => {"y" => "text"}}
    bson = h.to_bson
    bson["x"].should eq(42)
    ary = bson["ary"]
    fail "expected BSON" unless ary.is_a?(BSON)
    ary["0"].should eq(1)
  end

  it "should decode json" do
    s = "{ \"sval\" : \"1234\", \"ival\" : 1234 }"
    bson = BSON.from_json s
    bson.to_s.should eq s
  end

  it "should decode canonical extended json" do
    s = "{ \"sval\" : \"1234\", \"ival\" : 1234 }"
    q = "{ \"sval\" : \"1234\", \"ival\" : { \"$numberInt\" : \"1234\" } }"
    bson = BSON.from_json q
    bson.to_s.should eq s
  end

  it "should output canonical extended json" do
    q = "{ \"sval\" : \"1234\", \"ival\" : { \"$numberInt\" : \"1234\" } }"
    bson = BSON.from_json q
    bson.to_extended_json.should eq q
  end

  it "should be able to read binary data" do
    bson = BSON.new
    bson["bin"] = BSON::Binary.new(BSON::Binary::SubType::Binary, "binary".to_slice)
    value = bson["bin"].as(BSON::Binary)
    String.new(value.data).should eq("binary")
  end

  it "should error json" do
    s = "{ this = wrong }"
    expect_raises(Exception) do
      _ = BSON.from_json s
    end
  end
end

class Inner
  include BSON::Serializable
  include JSON::Serializable

  property key : String?
end

class Outer
  include BSON::Serializable
  include JSON::Serializable

  def initialize(**args)
    {% for ivar in @type.instance_vars %}
      {% if ivar.type.nilable? %}
        instance.{{ivar.id}} = args["{{ivar.id}}"]?
      {% else %}
        instance.{{ivar.id}} = args["{{ivar.id}}"]
      {% end %}
    {% end %}
  end

  property str : String
  property optional_int : Int32?
  property array_of_union_types : Array(String | Int32)
  property nested_object : Inner
  property array_of_objects : Array(Inner)
  property free_form : JSON::Any
  property hash : Hash(String, String | Int32)

  @[BSON::Prop(key: other_str)]
  @[JSON::Field(key: other_str)]
  property renamed_string : String

  @[BSON::Prop(ignore: true)]
  @[JSON::Field(ignore: true)]
  property ignored_field : String?
end

reference_json = %({
      "str": "str",
      "optional_int": 10,
      "array_of_union_types": [
          10,
          "str"
      ],
      "nested_object": {
          "key": "value"
      },
      "array_of_objects": [
          {
              "key": "0"
          }
      ],
      "free_form": {
          "one": 1,
          "two": "two"
      },
      "hash": {
          "one": 1,
          "two": "two"
      },
      "other_str": "str"
  })

describe BSON::Serializable do
  it "should perform a round-trip" do
    bson = BSON.new
    bson["str"] = "str"
    bson["optional_int"] = 10
    bson.append_array("array_of_union_types") { |child|
      child << 10
      child << "str"
    }
    bson.append_document("nested_object") { |child|
      child["key"] = "value"
    }
    index = 0
    bson.append_array("array_of_objects") { |_, child|
      child.append_document(index.to_s) { |c|
        c["key"] = index.to_s
      }
    }
    free_form = BSON.new
    free_form["one"] = 1
    free_form["two"] = "two"
    bson["free_form"] = free_form
    hash = BSON.new
    hash["one"] = 1
    hash["two"] = "two"
    bson["hash"] = hash
    bson["other_str"] = "str"

    expected_json = JSON.parse(reference_json).to_json

    # bson -> json
    JSON.parse(bson.to_json).to_json.should eq expected_json

    # bson -> bson::serializable
    bson["ignored_field"] = "nope"
    instance = Outer.from_bson bson
    # test the annotations
    instance.renamed_string.should eq bson["other_str"]
    instance.ignored_field.should be_nil
    # bson::serializable -> json
    instance.to_json.should eq expected_json
    # bson::serializable -> bson -> json
    JSON.parse(instance.to_bson.to_json).to_json.should eq expected_json
  end
end
