require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/support/db.rb')

describe "indexer" do

   it "correctly metaphones searches" do
       
       search = Silver::Search.new("Barack Obama","specparents")
       morph = search.morph_words
       morph.should eq([["Barack",["PRK",nil]],["Obama",["APM",nil]]])

   end

   it "correctly metaphones items" do

       index = Silver::Index.new("specparents","date") do |date|
           Parent.all(:order => :date.desc, :date.gt => date)
       end
       morph = index.send("morph","barack-obama.JpEg")
       morph.should eq([["barack",["PRK",nil]],["obama",["APM",nil]]])

   end

   it "indexes the database" do
       r = Redis.new
       r.select 12
       keys = r.keys("specparents:*")
       keys.each{|key| r.del key}
       r.keys("specparents:*").should eq([])

       index = Silver::Index.new("specparents","date") do |date|
           Parent.all(:order => :date.desc, :date.gt => date)
       end
       
       output = index.find_and_update do |result|
           output = result.name 
           id = result.id
           [id,output]
       end
       
       r.keys("specparents:*").should include("specparents:PS")
       r.keys("specparents:*").should include("specparents:ARK")

   end


   it "returns false when there are no new updates" do

       index = Silver::Index.new("specparents","date") do |date|
           Parent.all(:order => :date.desc, :date.gt => date)
       end
       
       output = index.find_and_update do |result|
           output = result.name 
           id = result.id
           [id,output]
       end

       output.should eq(false)

   end

   it "searches the index" do
       
       search = Silver::Search.new("Erik","specparents")
       results = search.perform{|id| Parent.get(id)}
       results[0]["name"].should eq("Erik")
       results[0]["age"].should eq(24)
       search = Silver::Search.new("Erik Hinton","specparents")
       results = search.perform{|id| Parent.get(id)}
       results[0]["name"].should eq("Erik Hinton")
       results[0]["age"].should eq(2)

   end
   
   it "updates the index" do

       r = Redis.new
       r.select 12

       index = Silver::Index.new("specparents","date") do |date|
           Parent.all(:order => :date.desc, :date.gt => date)
       end

       p = Parent.create(:name => "Update",
                         :age => 1,
                         :date => DateTime.now)

       output = index.find_and_update do |result|
           output = result.name 
           id = result.id
           [id,output]
       end

       output.should eq(true)
       r.keys("specparents:*").should include("specparents:APTT")
       p.destroy

   end

end

describe "cacher" do



end

#describe "reader" do

    #it "reads the database" do
        #index = Silver::Index.new("Asset","label",{:id => 15})
        #items = index.read
        #items[0].label.should eq("petraeus-testify-med.jpg")
    #end

#end

#describe "parser" do
    #it "registers the correct time" do
        #index = Silver::Index.new("Asset","label",{:id => 15})
        #items = index.read
        #parsed_item = index.parse(items[0])
        #parsed_item[0].should eq(1207685164)
    #end

    #it "parses the string" do
        #index = Silver::Index.new("Asset","label",{:id => 15})
        #items = index.read
        #parsed_item = index.parse(items[0])
        #parsed_item[1].should eq([["petraeus", ["PTRS", nil]], ["testify", ["TSTF", nil]], ["med", ["MT", nil]]])
    #end
#end

#describe "morpher" do
    #it "breaks strings into words" do
        #string = "barack-obama-happy.jpg"
        #parsed_string = Silver::Index.morph(string)
        #parsed_string[0][0].should eq("barack")
        #parsed_string[2][0].should eq("happy")
    #end
    #it "correctly sounds out words" do
        #string = "cat-hard-tack.jpg"
        #parsed_string = Silver::Index.morph(string)
        #parsed_string[0][1].should eq(["KT",nil])
        #parsed_string[2][1].should eq(["TK",nil])
    #end
#end

#describe "writer" do

    #it "writes to redis" do
        #index = Silver::Index.new("Asset","caption/label",{:parent => nil, :limit => 2})
        #r = Redis.new
        #r.select 4
        #items = index.read
        #if items == []
            #puts "no new items to test"
        #else
            #parsed_item = index.parse(items[1])
            #index.process
            #r.keys.should include("captionlabel:#{parsed_item[1][0][1][0]}")
        #end
    #end

#end

#describe "searcher" do
   
    #it "finds matching phones" do
        #search = Silver::Search.new("obama","Asset","captionlabel",0)
        #results = search.find_matching_phones(["SMT","XMT"])
        #results.should include("36662")
    #end

    #it "perform searches" do
        #search = Silver::Search.new("barack obama","Asset","captionlabel",0)
        #results = search.perform
        #results.length.should eq(30)
        #words = (results[0].caption || "")+" "+(results[0].label || "")
        #results[0].class.should eq(Asset)
        #words.should =~ /obama/i
    #end

#end
