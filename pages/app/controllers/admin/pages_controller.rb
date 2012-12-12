module Admin
  class PagesController < Admin::BaseController
    helper :copywriting
    crudify :page,
            :conditions => nil, # only pages this users can access
            :order => "pages.lft ASC",
            :include => [:slugs, :translations, :children, :users, :parts],
            :paging => false

    rescue_from FriendlyId::ReservedError, :with => :show_errors_for_reserved_slug

    after_filter lambda{::Page.expire_page_caching}, :only => [:update_positions]

    before_filter :restrict_access, :only => [:create, :update, :update_positions, :destroy], :if => proc {|c|
      ::Refinery.i18n_enabled?
    }
    

    after_filter :update_users, :only => [:create, :update]

    def find_page
      conditions = {:slugs => {:scope => params[:scope] || nil }}
      @page = Page.includes([:slugs, :translations, :children]).\
        where(conditions).find(params[:id])
    end
    
    def new
      @page = Page.new
    end
    
    def find_all_pages(conditions = {})
      conditions.merge!({"users.id" => current_user.id}) unless current_user.has_role?(:superuser)
      
      @pages = ActiveRecord::Base.uncached do
        Page.where(conditions).includes(
                    [:slugs, :translations, :children, :users]).order("pages.lft ASC")
      end
    end
    
    def create
      # if the position field exists, set this object as last object, given the conditions of this class.
      if Page.column_names.include?("position")
        params[:page].merge!({
          :position => ((Page.maximum(:position)||-1) + 1)
        })
      end
      
      if (@page = Page.create(params[:page])).valid?
        (request.xhr? ? flash.now : flash).notice = t(
          'refinery.crudify.created',
          :what => "'#{@page.title}'")

        unless from_dialog?
          unless params[:continue_editing] =~ /true|on|1/
            redirect_back_or_default(admin_pages_path)
          else
            unless request.xhr?
              redirect_to :back
            else
              render :partial => "/shared/message"
            end
          end
        else
          render :text => "<script>parent.window.location = '#{admin_pages_path}';</script>"
        end
      else
        
        invalid_parts = @page.parts.reject {|part|
          part.valid? && items.all?(&:valid?) }
        
        unless request.xhr?
          render :action => 'new', :locals => {:invalid_parts => invalid_parts}
        else
          render :partial => "/shared/admin/error_messages",
                 :locals => {
                   :object => @page,
                   :include_object_name => true, 
                   :invalid_parts => invalid_parts
                 }
        end
      end
    end
    
    def update
      if @page.update_attributes(params[:page])
        (request.xhr? ? flash.now : flash).notice = t(
          'refinery.crudify.updated',
          :what => "'#{@page.title}'"
        )
        
        @page.touch

        unless from_dialog?
          unless params[:continue_editing] =~ /true|on|1/
            redirect_to redirect_path
          else
            unless request.xhr?
              redirect_to edit_admin_page_path(@page, :scope => @page.parent_id)
            else
              render :partial => "/shared/message"
            end
          end
        else
          render :text => "<script>parent.window.location = '#{admin_pages_path}';</script>"
        end
      else
        unless request.xhr?
          render :action => 'edit'
        else
          render :partial => "/shared/admin/error_messages",
                 :locals => {
                   :object => @page,
                   :include_object_name => true
                 }
        end
      end
    end
    
    def preview
      @menu_items = {
        :locations => Page.location.in_menu.live.uniq,
        :other => Page.top_level.in_menu.not_location.not_footer.live.uniq
      }
      @footer_items = Page.in_footer.in_menu.live.uniq
      @language_items = Refinery::I18n.locales_with_flags
      @page = Page.new(params[:page])
      
      
      # <oh dear>
      # Preview relies on the parts_items relationships which have not yet
      # been created, so this patch simulates them
      @page.parts.each do |part|
        part.parts_items.each do |parts_item|
          part.items << parts_item.item
        end
      end
      # </oh dear>
      
      render '/pages/show', :layout => "application"
    end
  
  protected
  
    def redirect_path
      params[:redirect].present? ? (edit_admin_page_path(@page) + params[:redirect]) : admin_pages_path
    end
    
    # We can safely assume Refinery::I18n is defined because this method only gets
    # Invoked when the before_filter from the plugin is run.
    def globalize!
      unless action_name.to_s == 'index'
        super

        # Check whether we need to override e.g. on the pages form.
        unless params[:switch_locale] || @page.nil? || @page.new_record? || @page.slugs.where({
          :locale => Refinery::I18n.current_locale
        }).nil?
          @page.slug = @page.slugs.first if @page.slug.nil? && @page.slugs.any?
          Thread.current[:globalize_locale] = @page.slug.locale if @page.slug
        end
      else
        # Always display the tree of pages from the default frontend locale.
        Thread.current[:globalize_locale] = params[:switch_locale].try(:to_sym) || ::Refinery::I18n.default_frontend_locale
      end
    end

    def show_errors_for_reserved_slug(exception)
      flash[:error] = t('reserved_system_word', :scope => 'admin.pages')
      if action_name == 'update'
        find_page
        render :edit
      else
        @page = Page.new(params[:page])
        render :new
      end
    end

    def restrict_access
      if current_user.has_role?(:translator) && !current_user.has_role?(:superuser) &&
           (params[:switch_locale].blank? || params[:switch_locale] == ::Refinery::I18n.default_frontend_locale.to_s)
        flash[:error] = t('translator_access', :scope => 'admin.pages')
        redirect_to :action => 'index' and return
      end

      return true
    end
    
    def update_users
      if (@page)
        @page.users = (User.find(params[:page][:users]) rescue [])
        params[:page][:users] = nil
      end
    end
    
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
end
