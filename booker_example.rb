#!/usr/bin/ruby 
require File.dirname(__FILE__) + '/lib/booker.rb'

b = Booker.new('http://www.multcolib.org/', {
	:card => 'your library card number',
	:pin => 'your libary card pin',
	:email => 'your gmail address',
	:pass => 'you gmail password',
	:to => 'the email address to send notifications to'
})

b.renew_books
