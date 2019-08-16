# Title: Asset path tag for Jekyll
# Authors:
#     Sam Rayner http://samrayner.com
#     Otto Urpelainen http://koti.kapsi.fi/oturpe/projects/
#
# Description: Output a relative URL for assets based on the post or page
#
# Syntax
#    {% asset_path filename post_id %}
#    {% asset_path "filename with whitespace" post_id %}
#
# Examples:
# {% asset_path kitten.png %} on post 2013-01-01-post-title
# {% asset_path pirate.mov %} on page page-title
# {% asset_path document.pdf /2012/05/25/another-post-title %}
# {% asset_path "document with spaces in name.pdf" /2012/05/25/another-post-title %}
# {% asset_path image.jpg /my_collection/document_in_collection %}
#
# Output:
# /assets/posts/post-title/kitten.png
# /assets/page-title/pirate.mov
# /assets/posts/another-post-title/document.pdf
# /assets/posts/another-post-title/document with spaces in name.pdf
# /assets/my_collection/document_in_collection/image.jpg
#
# Looping example using a variable for the pathname:
#
# File _data/image.csv contains:
#   file
#   image_one.png
#   image_two.png
#
# {% for image in site.data.images %}{% asset_path {{ image.file }} %}{% endfor %} on post 2015-03-21-post-title
#
# Output:
# /assets/posts/post-title/image_one.png
# /assets/posts/post-title/image_two.png
#
# Looping example over posts:
#
# Site contains posts:
#   post-title
#   another-post-title
#
# {% for post in site.posts %}{% asset_path cover.jpg {{post.id}} %}{% endfor %} on index.html
#
# Output:
# /assets/posts/post-title/cover.jpg
# /assets/posts/another-post-title/cover.jpg

module Jekyll

  def self.get_post_path(page_id, collections)
    #loop through all pages and all collections to find match and get slug
    collections.each do |collection|
      doc = collection.docs.find { |doc| doc.id == page_id }
      if doc != nil
        slug = Jekyll::VERSION  >= '3.0.0' ? doc.data["slug"] : doc.slug
        return "#{collection.label}/#{slug}"
      end
    end

    return ""
  end

  class AssetPathTools
    def self.resolve(context, filename, page_id=nil)
      if page_id == nil or page_id.empty?
        # current page
        page = context.environments.first["page"]
        page_id = page["id"]
      end

      if page_id
        # is a post
        collections = context.registers[:site].collections.map { |collectionFromRegister| collectionFromRegister[1] }
        path = Jekyll.get_post_path(page_id, collections)
      else
        path = page["url"]
      end

      #strip filename
      path = File.dirname(path) if path =~ /\.\w+$/

      #fix double slashes
      "#{context.registers[:site].config['baseurl']}/assets/#{path}/#{filename}".gsub(/\/{2,}/, '/')
    end
  end

  class AssetPathTag < Liquid::Tag
    @markup = nil

    def initialize(tag_name, markup, tokens)
      #strip leading and trailing spaces
      @markup = markup.strip
      super
    end

    def parseNextParameter(parameterString)
      if (parameterString == nil)
        return nil, ""
      end

      parameterString.strip!

      if (parameterString.length == 0)
        return nil, ""
      end

      if ['"', "'"].include? parameterString[0] 
        # Quoted or whitespace limited field, possibly followed by more fields
        next_quote_index = parameterString.index(parameterString[0], 1)
        nextParameter = parameterString[1 ... next_quote_index]
        if parameterString.length > next_quote_index
          remaining = parameterString[(next_quote_index + 1) .. -1]
        else
          remaining = ""
        end
      else
        # Unquoted parameter
        whitespace_index = parameterString.index(' ', 0)
        if (whitespace_index == nil)
          nextParameter = parameterString
          remaining = ""
        else
          nextParameter = parameterString[0 ... whitespace_index]
          remaining = parameterString[(whitespace_index + 1) .. -1]
        end
      end

      return nextParameter, remaining
    end

    def parseParameters(parameterString)
      parameterString.strip!

      filename, parameterString = parseNextParameter(parameterString)
      page_id, parameterString = parseNextParameter(parameterString)

      return filename, page_id
    end

    def render(context)
      if @markup.empty?
        return "Error processing input, expected syntax: {% asset_path filename [post id] %}"
      end

      #render the markup
      parameters = Liquid::Template.parse(@markup).render context
      filename, page_id, collection_name = parseParameters(parameters)
      AssetPathTools.resolve(context, filename, page_id)
    end
  end
end

Liquid::Template.register_tag('asset_path', Jekyll::AssetPathTag)
