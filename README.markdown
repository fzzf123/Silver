# Silver

Silver is a lightweight, redis-backed database cacher and indexer.

## Getting Started

As it says on the tin, Silver is going to make your database queries much faster. Now it is no secret that Redis is fantastic to use as a cache/index. However, you have to write the same boilerplate to use it as cache over and over: find most recent cached entry, look for newer entries in the database, cache it to redis, combine with old results. Rinse, repeat.
The goal of Silver is so that you never have to do that again. Rather than connecting to the database/service for you, you simply wrap your calls in Silver and it does the rest. This means you can use silver to speed up calls to databases, calls APIs, CURLS, really whatever you want.

### A Simple Caching Example

First make sure you have Silver installed.
    gem install silver
Now, let's pretend you have an app that queries your database for entries frequently. Entries are added frequently. Furthermore, you only want Entries that come from a specific blog, blog #12. Also you want to grab something from an association of the Entry row in the database. Let's say the author's name.
First, instantiate a new cache object.
    cache = Silver::Cache.new("12_entries","created_time") do |date|
      Entry.all(:order => :created_time.desc, :created_time.gt => date, :blog_id => 12)
    end
The first paramater passed to the constructor is the name you want to give to this cache in Redis as Silver allows to creates as many caches for  different queries as you would like. The second paramater is the name of the field that you will be using to determine if there are new entries. Finally, you pass the constructor a block that will receive the date of the newest cached entry from Redis. You must return the entries in reverse chronological order for Silver to be able to keep them in order. Silver will then query the database/service for newer entries when the instance's find method is called.
    results = cache.find do |entry|
      attrs = entry.attributes
      author = {:author_name => entry.author[:name]}
      attrs.merge author
    end
The find method of a cache instance takes a block that will be called for every new entry. The results of the block call should be a hash that will be stored in the cache. The whole thing will be converted into JSON and stashed in the Redis cache. From now on the database will never have to be hit again to return this value. The find method returns an array of all the results old and new from the Redis cache. 
If you just want to read from the cache without hitting the database, simply call find without a block and with a single param:    false
    results = cache.find(false)
Currently, the cache does not support the changing of cached entries and is, thus, intended for data that is unlikely to change once it has been written to the database. This feature will be included in future releases of Silver.
Finally, Silver provides a cull method.
    cache.cull(30)
This will cut the Redis cache down to the 30 most recent items.

### A Simple Indexing Example

However, Silver is not just a simple cache. It can also be used to index a database. It is optimized to index based on short text, such as names, captions, tag lists, excerpts, tweets etc. There is nothing stopping you from using on longer fields such as body text except the size of your memory alloted to Redis. Silver uses a stupidly simple fuzzy text search. The search will likely be augmented in the future.
Here's how you would index a mess of photos by their captions, falling back on their filename if no caption is given.
First, instantiate a new index object.
    index = Silver::Index.new("blog_pictures","created_time") do |date|
      Picture.all(:order => :created_time.desc, :created_time.gt => date)
    end
This is the same deal as before with Silver::Cache: redis key name, time field, ordering block.
Next, call the find_and_update method of the instance.
    index.find_and_update do |result|
      output = result.label || result.filename || ""
      id = result.id
      [id,output]
    end
Find_and_update takes a block that will be called for each db-fetched result. This block should return a two item array of the row's id, first, and the value we are using for indexing second. As you can see in the example, Silver allows you to mix fields to use to index. It let's you do anything you want actually as long as an id and a corresponding value are returned. After calling find_and_update, your database is indexed and ready to be searched. Say, we wanted to search for photos of "Barack Obama":
    search = Silver::Search.new("Barack Obama","blog_pictures")
The constructor takes a string to search for and the name of Redis key storing the index. To actually perform the search:
    search.perform{|id| Picture.get(id)}
The perform method takes a block that will be passed the ids of all the id's whose indexes match the query. Perform will return an array of database/service objects for you to then interact with as you please.

### A note about the shortcoming of the search.

As Silver is currently in beta, it's search could use some work (feel free to contribute code). Currently, it does a fuzzy search based on the double-metaphone of each word in the search and then interects the results. This means several things. First, a search for "barack Obama" will only return those entries indexed with "Barack Obama"(case-insensitive) in their indexed field. It will excludes those with just, say, "obama". Second, no levensteining is done yet. It should be.

### Non-standard configurations

Every initializer in Silver takes, in addition to the parameters shown above, an optional options hash for Redis as the third parameter.
    cache = Silver::Cache.new("12_entries","created_time",{:host => "127.0.0.1",:port => "6969"})
Also, the search initializer for Silver's indexing takes optional number and offset paramater for pagination. Default is no offest and 30 results returned.
    search = Silver::Search.new("Barack Obama","blog_pictures",{:host => "127.0.0.1",:port => "6969"},50,10)
This will return results 10-60.

### Rocco Annotated Source

* [Cacher](http://tpm.github.com/Silver/cache.html)
* [Indexer](http://tpm.github.com/Silver/indexer.html)
* [Searcher](http://tpm.github.com/Silver/search.html)

## Improvements to be made

* Better Search
* Allow for changes to be made in the database for already cached values. (Make an uncache function that fetches that ID again and replaces it in the cache)
* Etc.

## Contributing to silver
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2011 Erik Hin-tone. See LICENSE.txt for
further details.

