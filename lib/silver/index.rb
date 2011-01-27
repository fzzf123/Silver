require File.expand_path(File.dirname(__FILE__) + '/common_words.rb')

class AttrError < RuntimeError
end

module Rind
    class Index

        def initialize(table,field,conditions={})
            @r = Redis.new
            @r.select 4
            @table = table
            @field = field.split("/").length == 2 ? field.split("/") : field
            @conditions = conditions
            if conditions[:id]
                @last_id = 0
            else
                @last_id = @r.get("#{@table}:#{@field}:last_id") || 0
            end
        end

        def read
            options = {:id.gt => @last_id}.merge @conditions
            items = Object.const_get(@table).all(options)
            items
        end

        def parse(item)
            time = item.created_time
            time = Time.parse(time.to_s).to_i
            
            if @field.class == String
                attribute = item.instance_eval(@field)
            else
                attribute = item.instance_eval(@field[0]) || item.instance_eval(@field[1]) 
            end
           
            raise AttrError, "Specified attribute not found in item #{item.id}" if !attribute 
            morphed_words = Rind::Index.morph(attribute)
            [time,morphed_words]
        end

        def write(word,id,time)
            text = word[0]
            phonemes = word[1].compact
            phonemes.each do |phoneme|
                @r.zadd "#{@field}:#{phoneme}", time, id
            end
        end

        def process
            items = self.read
            items.each do |item|
                begin
                    puts item.id
                parsed_item = self.parse(item)
                item_time = parsed_item[0]
                morphed_words = parsed_item[1]
                morphed_words.each{|word| self.write(word,item.id,item_time)}
                @last_id = item.id if item.id > @last_id.to_i
                rescue AttrError => e
                    puts e
                end
            end
            @r.set("#{@table}:#{@field}:last_id",@last_id)
        end

        def self.morph(string)
            if string =~ /\.(jpg|jpeg|tif|tiff|bmp|gif)/i
                words = string.split(/[^a-zA-Z]/).reject{|q| q == "" || q =~ /^(jpg|jpeg|tif|tiff|bmp|gif)$/} - COMMON_WORDS 
            else
                words = string.split(/[^a-zA-Z]/).reject{|q| q == "" || (q.length < 5 && q.capitalize != q)} - COMMON_WORDS 
            end
            morphed_words = words.map{|q| [q,Text::Metaphone.double_metaphone(q)]}
            morphed_words
        end

    end

end

