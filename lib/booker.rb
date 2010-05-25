#!/usr/bin/ruby 

require 'rubygems'
require 'mechanize' 
require 'tlsmail'

class Booker 
	def initialize(uri, config) 
		@agent = Mechanize.new 
		@home_page = @agent.get(uri)

		validate(config)
		@config = config 
	end
	def validate(config)
		[:card, :pin, :email, :pass, :to].each do |key|
			unless config.has_key?(key)
				raise "Config missing #{key.to_str} key."
			end
		end
	end
	def login
		@account_page = @agent.click(@home_page.link_with(:text => 'My account'))
		login_form = @account_page.form('patform')
		login_form.code = @config[:card]
		login_form.pin = @config[:pin]
		@user_page = @agent.submit(login_form, login_form.buttons.first)
	end
	def renew_books
		target = '' 
		renew_uri = ''
		holds = ''
                
		login 

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
	def notify(message, books)
		uc_message = message.upcase
		content = <<ENDOFMESSAGE
From: Me <#{@config[:email]}>
To: Me <#{@config[:to]}>
Subject: Library Books #{uc_message} 

The following books are #{message}:
#{books}
ENDOFMESSAGE

		Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)
		Net::SMTP.start('smtp.gmail.com', 587, 'gmail.com', @config[:email], @config[:pass], :login) do |smtp|
			smtp.send_message(content, @config[:email], @config[:to]) 
		end
	end
end
