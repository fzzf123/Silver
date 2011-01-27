class BareHash < Hash

    def [](key)

        if self.include? key
            self.fetch(key)
        else
            key.class == String ? self.fetch(key.to_sym,nil) : self.fetch(key.to_s, nil)
        end

    end

end

class Hash

    def to_bare

        bhash = BareHash.new
        self.each{|k,v| bhash[k] = v.to_s}
        bhash

    end

end

module Silver

  class Cache
    
    attr_reader :key, :time_field, :query

    def initialize(key,time_field,&query)
    
        @key = key
        @time_field = time_field
        @query = query
        @r = Redis.new
        @r.select 11
    
    end
      
    def find(&callback)
      
      old_results = @r.lrange(@key,0,-1).map{|q| JSON.parse(q)}
      last_date = @r.get("#{@key}:last") || "1970-01-01"
      new_results = @query.call(DateTime.parse(last_date))
      
      results = new_results.map do |result| 
        add_on = callback.call(result)
        result.attributes.merge add_on
      end 
      if results.empty?
          final_results = old_results
      else 
          new_date = results[0][@time_field].to_s
          @r.set("#{@key}:last",new_date)
          results.reverse!
          
          results.each do |result|
            @r.lpush(@key,result.to_json)
          end

          final_results = results.reverse + old_results
      end
      
      final_results = final_results.map do |result| 
          result.to_bare
      end
    end

    def cull(length)

        @r.ltrim(@key,0,length-1)

    end

  end

end
