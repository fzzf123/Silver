require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "reader" do

    it "reads the database" do
        index = Silver::Index.new("Asset","label",{:id => 15})
        items = index.read
        items[0].label.should eq("petraeus-testify-med.jpg")
    end

end

describe "parser" do
    it "registers the correct time" do
        index = Silver::Index.new("Asset","label",{:id => 15})
        items = index.read
        parsed_item = index.parse(items[0])
        parsed_item[0].should eq(1207685164)
    end

    it "parses the string" do
        index = Silver::Index.new("Asset","label",{:id => 15})
        items = index.read
        parsed_item = index.parse(items[0])
        parsed_item[1].should eq([["petraeus", ["PTRS", nil]], ["testify", ["TSTF", nil]], ["med", ["MT", nil]]])
    end
end

describe "morpher" do
    it "breaks strings into words" do
        string = "barack-obama-happy.jpg"
        parsed_string = Silver::Index.morph(string)
        parsed_string[0][0].should eq("barack")
        parsed_string[2][0].should eq("happy")
    end
    it "correctly sounds out words" do
        string = "cat-hard-tack.jpg"
        parsed_string = Silver::Index.morph(string)
        parsed_string[0][1].should eq(["KT",nil])
        parsed_string[2][1].should eq(["TK",nil])
    end
end

describe "writer" do

    it "writes to redis" do
        index = Silver::Index.new("Asset","caption/label",{:parent => nil, :limit => 2})
        r = Redis.new
        r.select 4
        items = index.read
        if items == []
            puts "no new items to test"
        else
            parsed_item = index.parse(items[1])
            index.process
            r.keys.should include("captionlabel:#{parsed_item[1][0][1][0]}")
        end
    end

end

describe "searcher" do
   
    it "finds matching phones" do
        search = Silver::Search.new("obama","Asset","captionlabel",0)
        results = search.find_matching_phones(["SMT","XMT"])
        results.should include("36662")
    end

    it "perform searches" do
        search = Silver::Search.new("barack obama","Asset","captionlabel",0)
        results = search.perform
        results.length.should eq(30)
        words = (results[0].caption || "")+" "+(results[0].label || "")
        results[0].class.should eq(Asset)
        words.should =~ /obama/i
    end

end
