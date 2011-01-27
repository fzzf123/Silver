require File.expand_path(File.dirname(__FILE__) + '/common_words.rb')

#### Boring new error

# Just makes a new sublcass of RuntimeError so we can raise database
# errors later

class AttrError < RuntimeError
end

#### Indexing

module Silver

    class Index

        # Create a new index for some given database or web service. Silver
        # doesn't do any connecting to a database, it requires you to pass
        # a query to it as a block. Use whatever ORM you like best. 
        #
        # key is the name this index will be stored with in Redis. 
        # time_field is the name of the field used for determining whether or not
        # there are new entries.
        # query is a block that takes the date of the most recently indexed item
        # as a parameter. Query should always sort entries in descending order.
        #
        # Example to index all large pictures based on their captions:
        #
        # index = Silver::Index.new("picturecaptions","created_time") do |time|
        #   Pictures.all(:order => :created_time.desc, :created_time.gt => time, :size => "large")
        # end

        def initialize(key,time_field,&query)
            @r = Redis.new
            @r.select 12
            @key = key
            @time_field = time_field
            @query = query
            @new_results = []
            @indexed_items = []
        end

        # Looks for the most recent date indexed and only fetch
        # entries newer than that date from the database.

        def find_and_update

            last_time = @r.get("#{key}:last") || "Jan. 1, 1970"
            new_results = @query.call(DateTime.parse(last_date))
            new_date = new_results[0][@time_field].to_s
            @r.set("#{@key}:last",new_date)
            @new_results = new_results
        end

        # Takes the new results and a block to access the field by which indexing will take place.
        # Sends these off to a double metaphone method to allow for fuzzy searching. 
        #
        # accessor should be a block that takes a result and returns an array containing, first, the item's id
        # and, second, the value by which to index.
        #
        # Ex:
        #
        # index.parse do |result|
        #   output = result.caption || result.label || "" 
        #   id = result.id
        #   [id,output]
        # end

        def parse(&accessor)

            @new_results.each do |result|
                begin 
                    value = accessor.call(result)
                    time = Time.parse(result[@time_field].to_s).to_i
                    raise AttrError, "Specified attribute not found in item #{value[0]}" if !attribute 
                    morphed_words = morph(value[1])
                    morphed_words.each{|word| write(word,value[0],time)}
                rescue AttrError => e
                    puts e
                end
           
            end
           
        end

        private
        
        # Takes a metaphoned string, the id of the row that contains it, and the time created/modified of that row
        # and writes to the database to phonemes by which that row is now indexed.

        def write(word,id,time)
            
            text = word[0]
            phonemes = word[1].compact
            phonemes.each do |phoneme|
                @r.zadd "#{@key}:#{phoneme}", time, id
            end
        end

        # Note: this method needs some work/ is not perfect.
        # Takes a string, removes any file extension, splits it on non-alpha characters, throws out empty words
        # words smaller than 5 characters that are not capitalized and all common words. Finally it converts each
        # word to its metaphoned equivalents and returns an array of the original words in its metaphones.

        def morph(string)
            string.gsub!(/\..{1,4}$/,"")
            words = string.split(/[^a-zA-Z]/).reject{|q| q == "" || (q.length < 5 && q.capitalize != q)} - COMMON_WORDS 
            morphed_words = words.map{|q| [q,Text::Metaphone.double_metaphone(q)]}
            morphed_words
        end

    end

end

