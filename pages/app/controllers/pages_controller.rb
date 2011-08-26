class PagesController < ApplicationController

  before_filter :find_page_by_path, :only => :show
  
  # This action is usually accessed with the root path, normally '/'
  def home
    error_404 unless (@page = Page.where(:link_url => '/').first).present?
  end

  # This action can be accessed normally, or as nested pages.
  # Assuming a page named "mission" that is a child of "about",
  # you can access the pages with the following URLs:
  #
  #   GET /pages/about
  #   GET /about
  #
  #   GET /pages/mission
  #   GET /about/mission
  #
  def show
    if @page.try(:live?) || (refinery_user? && current_user.authorized_plugins.include?("refinery_pages"))
      # if the admin wants this to be a "placeholder" page which goes to its first child, go to that instead.
      if @page.skip_to_first_child && (first_live_child = @page.children.order('lft ASC').live.first).present?
        redirect_to first_live_child.url and return
      elsif @page.link_url.present?
        redirect_to @page.link_url and return
      end
    else
      error_404
    end
  end
  
  def preview
    @page = Page.new(params[:page])
    error_404 and return unless @page.try(:live?) || (refinery_user? && current_user.authorized_plugins.include?("refinery_pages"))
    render 'show'
  end

  protected
  def find_page_by_path
    path_segments = "#{params[:path]}/#{params[:id]}".split('/')
    
    if path_segments.length == 1
      @page = Page.find(path_segments.pop)
    else
      @page = Page.find(path_segments.shift)
      while (path_segments.present?)
        @page = @page.children.find(path_segments.shift)
      end
    end
  end
end
