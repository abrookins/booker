#!/usr/bin/ruby 
require File.dirname(__FILE__) + '/lib/booker.rb'

b = Booker.new('http://www.multcolib.org/')
b.card = "your library card number"
b.pin = "your library card pin"
b.email = 'your gmail address'
b.pass = 'you gmail password'
b.to = 'the email address to send notifications to'
b.check_books
