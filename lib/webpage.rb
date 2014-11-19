#coding:UTF-8
require 'webpage/common'
class Webpage
    attr_reader :nokogiri
    def initialize(body,options={})
        raise ArgumentError 'body cannot be empty' unless body
        @options = options
        #@body = @body.force_encoding(@options[:encoding]).encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "") if @options.has_key?:encoding
        @nokogiri = Nokogiri::HTML(body)
        if options.has_key?:uri
            @uri = fuzzy_uri(@options[:uri])
            raise '@uri should be absolute' unless @uri.absolute?
            @host = @uri.host
        end
        @domain = options[:domain]
    end
    def h1
        @nokogiri.xpath("//h1").text
    end
    def title
        @nokogiri.xpath("//title").text
    end

    def text
        @nokogiri.xpath("//text()").text
        #return body.gsub(/<\/?[^>]*>/, "")
    end

    def canonical
        self['canonical'].first['href']
    end

    def [] (tag)
        return @nokogiri.xpath("//link[@rel='canonical']") if tag == 'canonical'
        return @nokogiri.xpath("//meta[@name='keywords']") if tag == 'keywords'
        return @nokogiri.xpath("//meta[@name='description']") if tag == 'description'
        if tag == 'charset'
            charset = @nokogiri.xpath("//meta[@charset]")[0]['charset'] rescue nil
            return charset if charset
            charset = @nokogiri.xpath("//meta[@http-equiv='content-type' or @http-equiv='Content-Type']").attr('content').text.split('=')[1]  rescue nil
            return charset
        end
        return @nokogiri.xpath("//#{tag}")
    end

    def nodes_with(key)
        @nokogiri.xpath("//@#{key}")
    end

    def keywords
        @keywords ||= @nokogiri.xpath("//meta[@name='keywords']").map{|meta|meta['content']}.flatten.join.split(',')
    end

    def description
        @description ||= @nokogiri.xpath("//meta[@name='description']").map{|meta|meta['content']}.flatten.join
    end

    def links
        @links ||= %w(a area).map do |tag|
            @nokogiri.xpath("//#{tag}[@href and not(@rel='nofollow')]")
        end.flatten
    end

    def link_to?(target_uri)
        links.any?{|link|
            #p make_href_absolute(link['href'].to_s)
            fuzzy_uri(link['href'].to_s).equal? fuzzy_uri(target_uri)
        }

        #links.any?{|link|fuzzy_uri(make_href_absolute(link['href'].to_s)).equal? fuzzy_uri(target_uri)}
    end

    def link_to_host?(host)
        links.any?{|link|fuzzy_uri(link['uri'].to_s).host == host}
    end

    def links_to_different_host
        raise '@host cannot be empty' unless @host
        @links_to_different_host ||= links.delete_if do|link|
            #fuzzy_uri(link['href'].to_s).host == @host or fuzzy_uri(link['href'].to_s).host.to_s.empty?
            uri = fuzzy_uri(link['href'].to_s)
            uri.host.to_s.empty? or uri.host == @host
        end
    end

    def links_to_different_domain
        raise '@domain cannot be empty' unless @domain
        @links_to_different_domain ||= links.delete_if do|link|
            begin
                uri = fuzzy_uri(link['href'].to_s)
                uri.host.nil? or uri.host.end_with? @domain 
            rescue
                next
            end
        end
    end

    def comments
        @nokogiri.xpath("//comment()").map{|comment|comment.to_s}.delete_if{|comment|comment.downcase.start_with?'[if ie' or comment.downcase.include?'google' or comment.downcase.include?'baidu'}
    end

    private
    def make_href_absolute(href)
        href = fuzzy_uri(href.to_s)
        return href.to_s if href.absolute?
        raise 'need :uri in options when initialize' unless @uri
        URI.join(@uri,href)
    end
end
