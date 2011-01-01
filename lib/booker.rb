#!/usr/bin/ruby 

require 'rubygems'
require 'mechanize' 
require 'tlsmail'
require 'ostruct'

class Booker 
    def initialize(url, config) 
        @agent = Mechanize.new 
        @library_url = url
        @home_page = nil
        @config = config 
        @book_groups = [
            new_book_group(/ON HOLD/, 'on hold'),
            new_book_group(/RENEWED/, 'renewed'),
            new_book_group(/TOO SOON TO RENEW/, 'not renewed (too soon)')
        ]
        self.validate(@config)
    end
    def new_book_group(pattern, message)
        OpenStruct.new({
            'pattern' => pattern,
            'message' => message,
            'found' => []
        })
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
        @home_page = @agent.get(@library_url)

        def row_content_with_pattern(pattern, row)
            row.content.gsub(/\n/, "") + "\n" if pattern.match(row.content)
        end 

        self.login 

        @user_page.links.each do |link|
            target = link.text.strip if /Items currently checked out/.match(link.text.strip)
        end

        @renew_page = @agent.click(@user_page.link_with(:text => target))

        # The link for the 'renew all' button is JavaScript-enabled to send 
        # the user to the current URI with an added GET param.
        @result_page = @agent.get(@renew_page.uri + '?action=renewall')

        # Search for any renewal messages
        @result_page.search('tr.patFuncEntry').each do |row|
            @book_groups.each do |group|
                content = row_content_with_pattern(group.pattern, row)
                group.found << content if content  
            end
        end

        notify(@book_groups)
    end
    def notify(book_groups)
        notices = ""
        content = "From: Me <#{@config[:email]}>\n"
        content += "To: Me <#{@config[:to]}>\n"
        content += "Subject: Library Books\n\n"

        book_groups.each do |group|
            group_string = "The following books were %s:\n %s"
            notices += group_string % [group.message, group.found] if not group.found.empty?
        end

        notices = "Nothing to update." if notices.empty?
        content += notices

        Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)
        Net::SMTP.start('smtp.gmail.com', 587, 'gmail.com', @config[:email], @config[:pass], :login) do |smtp|
            smtp.send_message(content, @config[:email], @config[:to]) 
        end
    end
end
