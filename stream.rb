#!/usr/bin/env ruby
# The line above this isn't really needed. It'd let you run the script by doing: ./stream.rb
# Running the script using the following makes this line kinda useless: ruby ./stream.rb

require 'twitter' # This allows us to communicate with the Twitter API more easily.
require 'htmlentities' # This lets us encode stuff to send sane data to the API's endpoints
require 'mysql2' # You'll need to install this gem. Do that with: gem install mysql2


# This just lists out your command line arguments:
ARGV.each do|a|
  puts "Argument: #{a}"
end

# Handle command line arguments. ARGV is just an array of the arguments.
if ARGV.length == 0
  puts "No brand provided on the command line. Using 'multiple' instead..."
  brand = 'multiple'
else
  brand = ARGV[0]
end

# Set up the list of filters for the stream based on the command line argument:
case brand
  when 'james'
    topics = %w(synth edm)
  when 'tacobell'
    topics = %w(tacobell)
  when 'burgerking'
    topics = %w(burgerking)
  when 'cke'
    topics = ['carlsjr', 'carl%27s%20jr%2E', 'hardees','hardee%27s', 'eatlikeyoumeanit', 'mondaybunday']
  else
    # THIS is default! If no command line arguments are given, these words will be used.
    #
    # %w() is just another way to build an array of strings. It's easier to type than 
    # something like ["carlsjr", "hardees", "eatlikeyoumeanit"]
    topics = %w(carlsjr hardees eatlikeyoumeanit mondaybunday tacobell)
end


# Setup a URL encoder so we can send clean data to the Twitter endpoint:
# This handles strange characters (or rather, non-web-safe characters like spaces) in the 
# filter list. For example, a space will be translated to %20 because %20 is safe for URLs
coder = HTMLEntities.new

# Set up the Twitter gem to use the correct OAuth keys:
# Originally this was set based on the brand...
client = Twitter::Streaming::Client.new do |config|
  case brand
    when 'james'
      config.consumer_key        = ""
      config.consumer_secret     = ""
      config.access_token        = ""
      config.access_token_secret = ""
    when 'tacobell' || 'burgerking'
      # Carlsjr app keys:
      # ToDo: Build a second api key set for pulling competitor information:
      config.consumer_key        = ""
      config.consumer_secret     = ""
      config.access_token        = ""
      config.access_token_secret = ""
    else
      # Carlsjr app keys:
      config.consumer_key        = ""
      config.consumer_secret     = ""
      config.access_token        = ""
      config.access_token_secret = ""
  end
end

# Set up the mysql2 gem to connect to the correct database server using the correct
# username, password, and DB name:
#
# This script assumes there is a DB named "simple_twitter_stream" and also assumes that there is already
# a table set up to put the data in. You can set up the table structure in Sequal Pro.
#
# THE DB NEEDS to be in the utf8mb4 format!!! Otherwise all the stupid emoticons will break the script.
db_client = Mysql2::Client.new(:host => "localhost", :username => "root", :password => "", :database => "simple_twitter_stream")
db_client.query("set names utf8mb4");
# Actually, let's make sure that the table exists first:
db_client.query("CREATE TABLE IF NOT EXISTS Tweets(Id INT PRIMARY KEY AUTO_INCREMENT, json TEXT NOT NULL)")

# This whole begin, rescue, end block tries to manage the rate-limit issues. If an 
# exception is throw because we've exceeded our rate limit, the program will pause 
# for about 15 minutes and try again. This is a pain in the ass but there's just no
# other clear way to run these things.
#
# Once we're able to start the stream, this should be an issues. However, restarting
# the app will probably cause us to hit the rate limit REAL quick. This is why the
# streaming API was set up in the first place...
MAX_ATTEMPTS = 3 # Number of times to retry...
num_attempts = 0 # number ot times we've actually tried to hit the API...
begin
  # First, we need to bump up the num_attempts value since this is going to be our "first"
  # attempt at hitting the API
  num_attempts += 1

  # Now we can actually try starting the stream. This acts like an endless loop. It 
  # will run whatever is between "|raw_tweet|" and the matching "end" statement every
  # time the stream sends something back to us.
  client.filter(:track => coder.decode(topics.join(',').to_s)) do |raw_tweet|
    # begin
    #   if raw_tweet.is_a?(Twitter::Tweet)
    #     Tweet.new(:json => raw_tweet.to_json, :brand => brand ).save
    #   end
    # rescue
    #   puts "Parse error! #{raw_tweet.inspect}"
    #   retry
    # end

    # Make sure the thing we got back is actually a Tweet:
    if raw_tweet.is_a?(Twitter::Tweet)
      puts "Here's the tweet text itself: #{raw_tweet.text}"
      puts "Here's the raw Ruby object representing the tweet: #{raw_tweet}"
      puts "Here's the raw Tweet object thrown into Ruby's inspect function #{raw_tweet.inspect}"
      puts "Here's the raw Tweet object dumped to JSON: #{raw_tweet.to_h.to_json}"
      puts "" # empty line just so we can see the individual tweets in the console output

      # Make a vairable so we can hack it:
      raw_json = raw_tweet.to_h.to_json
      
      # # We have to strip the stupid unicode emoticons:
      # # This is taken from:
      # # http://stackoverflow.com/questions/1268289/how-to-get-rid-of-non-ascii-characters-in-ruby
      # # See String#encode
      # encoding_options = {
      #   :invalid           => :replace,  # Replace invalid byte sequences
      #   :undef             => :replace,  # Replace anything not defined in ASCII
      #   :replace           => '?',       # Use a ? for those replacements
      #   :universal_newline => true       # Always break lines with \n
      # }
      # raw_json.encode(Encoding.find('ASCII'), encoding_options)

      # # More attempts at stripping stupid characters:
      # stripped = raw_json.chars.select{|i| i.valid_encoding?}.join
      # stripped_2 = tidy_bytes(stripped)

      # Shove the raw JSON into the DB:
      # First we need to escape the JSON object so it's DB-safe:
      escaped_json = db_client.escape("#{raw_json}")
      # Then we can actually do the insert:
      results = db_client.query("INSERT INTO Tweets(json) VALUES('#{escaped_json}')")
    end
    
  end

rescue Twitter::Error::TooManyRequests => error
  if num_attempts <= MAX_ATTEMPTS
    waittime = error.rate_limit.reset_in || 10
    puts "Too many Requests!"
    puts "The api returned this as the reset_in time: '#{error.rate_limit.reset_in.to_s}'"
    puts "However, we will actually wait #{waittime} seconds because the API seems broken..."
    # NOTE: Your process could go to sleep for up to 15 minutes but if you
    # retry any sooner, it will almost certainly fail with the same exception.
    # sleep error.rate_limit.reset_in
    sleep waittime
    retry
  else
    puts "Oops! We tried #{MAX_ATTEMPTS} and still were not able to connect..."
    raise
  end
end
