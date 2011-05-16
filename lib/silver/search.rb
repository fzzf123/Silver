module Silver

    #### Search

    # Searches an indexed database. What else would it do?

    class Search

        # Takes a query and a redis key from a previous indexing. There is an optional offset
        # that can be used to paginate. It defaults to returning 30 results.
        # 
        # Example, query picture captions for "Barack Obama":
        #     search = Silver::Search.new("barack obama","picturecaption")
       
        def initialize(query,key,redis_options={},number=30,offset=0)
            @query = query
            @key = key
            @number = number
            @offset = offset
            @r = Redis.new(redis_options)
            @r.select 12
        end

        # Send a query to be metaphoned, finds the matching ids for the query and then
        # returns the results. Finally it only returns entries that are shared by both words.
        #
        # Takes a block that takes an id and then queries the database for that row. Again, Silver
        # can be used for services that "row" is a bad metaphor like REST apis. However, it is easy 
        # to write.
        #
        # Ex:
        #     search.perform{|id| Picture.get(id) }

        def perform(&accessor)
            morphed_words = morph_words
            morphed_words.map! do |word|
                phones = word[1]
                phones = self.find_matching_phones(phones)
                phones
            end
            results = morphed_words.reduce{|memo,obj| memo & obj}.slice(@offset,@number)
            results.map{|result| accessor.call(result)}
        end

        # Takes the instance's query, splits it into words, metaphones each word and returns the array of metaphoned words.

        def morph_words
            words = @query.split(/[^a-zA-Z0-9]/)
            morphed_words = words.map{|word| [word,Text::Metaphone.double_metaphone(word)]}
            morphed_words
        end

        # Takes an array of metaphones and returns the matching keys in the index. Since we are using double metaphone,
        # it unions the results for the two possible metaphones.i

        def find_matching_phones(phones)
            phones.map! do |phone|
                if phone
                    "#{@key}:#{phone}"
                else
                    nil
                end
            end
            phones = @r.zunionstore "temp", phones.compact
            phones = @r.zrevrange "temp", 0, -1
            phones
        end

    end

end
