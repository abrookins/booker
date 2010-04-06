#!/usr/bin/ruby 

require 'rubygems'
require 'mechanize' 
require 'tlsmail'

class Booker 
	attr_writer :card, :pin, :user, :pass, :to, :email

    def initialize(uri) 
		@agent = Mechanize.new 
        @home_page = @agent.get(uri)
    end
	def login
		@account_page = @agent.click(@home_page.link_with(:text => 'My account'))
		login_form = @account_page.form('patform')
		login_form.code = @card
		login_form.pin = @pin
		@user_page = @agent.submit(login_form, login_form.buttons.first)
    end
	def renew_books
		target = '' 
		renew_uri = ''
		holds = ''

		@user_page.links.each do |link|
			target = link.text.strip if /Items currently checked out/.match(link.text.strip)
		end
		@renew_page = @agent.click(@user_page.link_with(:text => target))

		# The link for the 'renew all' button is JavaScript-enabled to send 
		# the user to the current URI with an added GET param.
		@result_page = @agent.get(@renew_page.uri + '?action=renewall')

		# Search for any renewal messages
		@result_page.search('tr.patFuncEntry').each do |row|
			holds = holds + row.content.gsub(/\n/, '') + "\n" if /ON HOLD/.match(row.content)
		end
		
		# Send an email if it's time to give up the books 
		notify('on hold', holds) unless holds.empty?
	end
	def check_books
		login
		renew_books 
	end
	def notify(message, books)
		content = <<ENDOFMESSAGE
From: Me <#{@email}>
To: Me <#{@to}>
Subject: Library Books on Hold

The following books are #{message}:
#{books}
ENDOFMESSAGE

		Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)
		Net::SMTP.start('smtp.gmail.com', 587, 'gmail.com', @email, @pass, :login) do |smtp|
			smtp.send_message(content, @email, @to) 
		end
	end
end
