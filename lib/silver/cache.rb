#### Hash extensions

# Creates a new class, BareHash, that is alike a Hash in every way except that
# it may be accessed by a symbol or a string for every key. Really the same thing
# as HashWithIndifferentAccess but without ActiveSupport

class BareHash < Hash

    def [](key)

        if self.include? key
            self.fetch(key)
        else
            key.class == String ? self.fetch(key.to_sym,nil) : self.fetch(key.to_s, nil)
        end

    end

end

# Monkey patches Hash to allow for conversion to a BareHash where all values are strings. This
# is good for mixing results with Redis results which are always stored as strings.

class Hash

    def to_bare

        bhash = BareHash.new
        self.each{|k,v| bhash[k] = v.to_s}
        bhash

    end

end

#### Caching

module Silver

  class Cache
    
    attr_reader :key, :time_field, :query

    # Creates a new cached search object.
    #
    # Silver does not connect to a database, the query is passed as a block. This means you can use
    # Silver to cache databases, REST APIs, or anything else that can be queried.
    #
    # key is string to identify this and successive queries to Redis
    # time_field is the name of a field used to determine whether or not there are new entries that
    # are not yet cached.
    # query is a block that take a date and queries the database for all entries after that date. The results
    # must be returned in descending order.
    # 
    # Example to prepare a cache and query for the database of new stories in blog #2:
    #
    #     cache = Silver::Cache.new("news_stories",
    #                               "created_time") do |date|
    #       
    #       Stories.all(:order => :created_time.desc,
    #                   :created_time.gt => date
    #                   :blog_id => 2)
    #
    #     end 


    def initialize(key,time_field,redis_options={},&query)
    
        @key = key
        @time_field = time_field
        @query = query
        @r = Redis.new(redis_options)
        @r.select 11
    
    end

    # Queries Redis, returns new entries and inserts them into Redis.
    # 
    # callback is block that gets called for every new results, receives the result
    # and returns a hash of additional attributes. This is used to query associations.
    #
    # Example to cache and the query the database and include any categories the entry might have:
    #
    #     cache.find{|entry| {:categories => entry.categories}}
      
    def find(&callback)
      
      old_results = @r.lrange(@key,0,-1).map{|q| JSON.parse(q)}
      last_date = @r.get("#{@key}:last") || "1970-01-01"
      new_results = @query.call(DateTime.parse(last_date))
      
      results = new_results.map do |result| 
        if block_given?
            add_on = callback.call(result)
            result.attributes.merge add_on
        else
          result.attributes
        end
      end 
      
      if results.empty?
          final_results = old_results
      else 
          write_new(results)
          final_results = results + old_results
      end
      
      final_results = final_results.map do |result| 
          result.to_bare
      end
    end

    # A helper method to keep the redis list at a reasonable size.
    # 
    # length is the number of entries to reduce the redis to 

    def cull(length)

        @r.ltrim(@key,0,length-1)

    end
    
    private

    # Writes the results to redis by pushing them in reverse order on the head
    # of the redis list. This ensures that the first result will always be the newest.
    # Also turns every result hash into JSON before writing because Redis is string based.
    # Find will automatically parse these JSON strings upon retrieval.

    def write_new(results)
          
          new_date = results[0][@time_field].to_s
          @r.set("#{@key}:last",new_date)
          
          results.reverse.each do |result|
            @r.lpush(@key,result.to_json)
          end

    end

  end

end
