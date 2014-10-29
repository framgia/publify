module ContentBase
  def self.included base
    base.extend ClassMethods
  end

  def blog
    @blog ||= Blog.default
  end

  attr_accessor :just_changed_published_status
  alias_method :just_changed_published_status?, :just_changed_published_status

  def really_send_notifications
    interested_users.each do |value|
      send_notification_to_user(value)
    end
    return true
  end

  def send_notification_to_user(user)
    notify_user_via_email(user)
  end

  # Return HTML for some part of this object.
  def html(field = :all)
    if field == :all
      generate_html(:all, content_fields.map{|f| self[f].to_s}.join("\n\n"))
    elsif html_map(field)
      generate_html(field)
    else
      raise "Unknown field: #{field.inspect} in content.html"
    end
  end

  def render_as_html(field)
    render_options = {
      # will remove from the output HTML tags inputted by user
      filter_html: true,
      # will insert <br /> tags in paragraphs where are newlines
      # (ignored by default)
      hard_wrap: true,
      # hash for extra link options, for example 'nofollow'
      link_attributes: { rel: 'nofollow' }
      # more
      # will remove <img> tags from output
      # no_images: true
      # will remove <a> tags from output
      # no_links: true
      # will remove <style> tags from output
      # no_styles: true
      # generate links for only safe protocols
      # safe_links_only: true
      # and more ... (prettify, with_toc_data, xhtml)
    }
    renderer = ::PygmentsHTML.new(render_options)

    extensions = {
      #will parse links without need of enclosing them
      autolink: true,
      # blocks delimited with 3 ` or ~ will be considered as code block.
      # No need to indent.  You can provide language name too.
      # ```ruby
      # block of code
      # ```
      fenced_code_blocks: true,
      # will ignore standard require for empty lines surrounding HTML blocks
      lax_spacing: true,
      # will not generate emphasis inside of words, for example no_emph_no
      no_intra_emphasis: true,
      # will parse strikethrough from ~~, for example: ~~bad~~
      strikethrough: true,
      # will parse superscript after ^, you can wrap superscript in ()
      superscript: true
      # will require a space after # in defining headers
      # space_after_headers: true
    }
    Redcarpet::Markdown.new(renderer, extensions).render(self[field]).html_safe
  end # render_as_html

  # Generate HTML for a specific field using the text_filter in use for this
  # object.
  def generate_html(field, text = nil)
    text ||= self[field].to_s
    prehtml = html_preprocess(field, text).to_s
    html = (text_filter || default_text_filter).filter_text_for_content(blog, prehtml, self) || prehtml
    html_postprocess(field, html).to_s
  end

  # Post-process the HTML.  This is a noop by default, but Comment overrides it
  # to enforce HTML sanity.
  def html_postprocess(field, html)
    html
  end

  def html_preprocess(field, html)
    html
  end

  def html_map field
    content_fields.include? field
  end

  def excerpt_text(length = 160)
    if respond_to?(:excerpt) and (excerpt || "") != ""
      text = generate_html(:excerpt, excerpt)
    else
      text = html(:all)
    end

    text = text.strip_html

    return text.slice(0, length) +
      (text.length > length ? '...' : '');
  end

  def invalidates_cache?(on_destruction = false)
    @invalidates_cache ||= if on_destruction
                             just_changed_published_status? || published?
                           else
                             (changed? && published?) || just_changed_published_status?
                           end
  end

  def publish!
    self.published = true
    self.save!
  end

  # The default text filter.  Generally, this is the filter specified by blog.text_filter,
  # but comments may use a different default.
  def default_text_filter
    blog.text_filter_object
  end


  module ClassMethods
    def content_fields *attribs
      class_eval "def content_fields; #{attribs.inspect}; end"
    end

    def default_order
      'published_at DESC'
    end
  end
end
