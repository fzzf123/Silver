module Silver

    class Search

        def initialize(query,table,field,offset=0)
            @query = query
            @table = table
            @field = field
            @offset = offset
            @r = Redis.new
            @r.select 4
        end

        def perform
            morphed_words = self.morph_words
            morphed_words.map! do |word|
                phones = word[1]
                phones = self.find_matching_phones(phones)
                phones
            end
            results = morphed_words.reduce{|memo,obj| memo & obj}.slice(0,30)
            results.map{|result| Object.const_get(@table).get(result)}
        end

        def morph_words
            words = @query.split(/[^a-zA-Z0-9]/)
            morphed_words = words.map{|word| [word,Text::Metaphone.double_metaphone(word)]}
            morphed_words
        end

        def find_matching_phones(phones)
            phones.map! do |phone|
                if phone
                    "#{@field}:#{phone}"
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
