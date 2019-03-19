require "pm2md/version"
require "json"

module Pm2md

  class PM2MDCLI
    def initialize(collection_path, postman_enviroment_path)
      file_text = File.open(collection_path).read
      @enviroments = JSON.parse(File.open(postman_enviroment_path).read)
      enviroments_to_vars
      @collection = JSON.parse(replace_vars(file_text))
    end

    def make_md
      @md = "##{@collection['info']['name']}\n\n"
      @md += "#{@collection['info']['description']}\n\n"
      @collection['item'].each do |item|
        deep_md(1, item)
      end
      puts @md
    end
    
    def enviroments_to_vars
      @enviroments = Hash[@enviroments["values"].map { |env| [env['key'], env['value']] if env['enabled']}]
    end

    def replace_vars(text)
      @enviroments.each do |key, val|
        text = text.gsub("{{#{key}}}", val)
      end
      text
    end

    def deep_md(level, item, name="")
      if item.is_a? Array
        item.each { |i| deep_md(level, i, name) }
      elsif item.is_a? Hash and item.keys.include? 'item'
        @md += "\n#{'#'*level}#{item['name']}\n\n"
        deep_md(level, item['item'], item['name'])
      else
        @md += md_from_item(level+1, item, name)
      end
    end

    def md_from_item_request_headers(headers)
      md = "\n\n**Headers**\n\n| Header name | Value |"
      md += "\n| --- | ----- |"
      headers.each do |header|
        md += "\n|#{header['key']} | #{header['value']}|"
      end
      "#{md}\n\n"
    end

    def curl_example(method, url, headers, body)
      curl_headers = headers.map { |header| "--header \"#{header['key']}: #{header['value']}\" "}
      "```shell
      curl --location --request #{method} \"#{url}\" \\
      #{curl_headers.join(" \\ \n\t")} \\
      --data \"#{body['raw']}\"" + "\n```\n\n"
    end

    def js_example(method, url, headers, body)
      js_headers = Hash[headers.map { |header| [header['key'], header['value']]}]

      "```javascript
      var settings = {
      \"url\": \"#{url}\",
      \"method\": \"#{method}\",
      \"timeout\": 0,
      \"headers\": #{js_headers.to_json},
      \"data\": #{body['raw']},
      };

      $.ajax(settings).done(function (response) {
        console.log(response);
      });" + "\n```\n\n"

    end

    def md_examples_from_item(method, url, headers, body)
      md = curl_example(method, url, headers, body)
      md += js_example(method, url, headers, body)
      md
    end

    def md_from_item(level, item, name)
      method = item['request']['method']
      url = item['request']['url']['raw']
      url_method = "[#{method}] #{url}"
      md = "\n#{'#'*level}#{name}::#{item['name']}\n**_#{url_method}_**\n"
      md += md_from_item_request_headers(item['request']['header'])
      md += md_examples_from_item(method, url, item['request']['header'], item['request']['body'])
      md += item['request']['description'] || ""
      md
    end

  end
end
