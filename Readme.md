Simple Twitter Streamer
-----------------------

This app will basically just yank Tweets out of the stream and shove em into MySQL.


Setting up mysql: Part 1
----------------

Because the rest of the world uses crazy, multibyte unicode characters, and because mysql doesn't handle them well out of the box, you need to configure mysql a little differently than how it is set up by default. You need to tell mysql to use the utf8mb4 character set.

To do this, make sure these lines are in your my.cnf configuration file. This file is usually located at /usr/local/mysql/my.cnf on a Mac.

[client]
default-character-set = utf8mb4

[mysql]
default-character-set = utf8mb4

[mysqld]
collation-server = utf8mb4_unicode_ci
init-connect='SET NAMES utf8mb4'
character-set-server = utf8mb4

You'll need to restart the MySQL server after you make this change.

Setting up MySQL: Part 2
------------------------

Before you can run this script, you will need to create a database with the name simple_twitter_stream

It needs to have the correct character encoding as well. Set this to utf8mb4 (at the bottom of the list of options in Sequal Pro).

Once you have this DB created, you should be able to run the script (though you'll need to make sure the script has the right server ip, mysql user, and mysql password in it to get it to work correctly).


Running the script:
-------------------

Follow these steps to get the script running. Do these at the command line:

1. gem install bundler
2. bundle
3. ruby ./stream.rb
