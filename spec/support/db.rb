require 'rubygems'
require 'dm-core'

DB = "sqlite://#{File.expand_path(File.dirname(__FILE__))}/spec.db"

DataMapper.setup(:default,DB)
DataMapper.finalize

class Parent
    include DataMapper::Resource

    property :id, Serial
    property :name, String
    property :date, DateTime
    property :age, Integer

    has n, :children
end

class Child
    include DataMapper::Resource

    property :id, Serial
    property :name, String
    property :wow_factor, Integer

    belongs_to :parent
end

