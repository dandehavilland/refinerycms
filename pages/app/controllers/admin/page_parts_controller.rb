module Admin
  class PagePartsController < Admin::BaseController
    
    def new
      @prefix = "page[parts_attributes][#{params[:part_index]}]"
      part = PagePart.new(:page_id => params[:page_id], :title => params[:title], :index => params[:part_index], :meta => {:type => params[:type]})
      
      render :partial => "/admin/pages/insert_page_part_field", :locals => {
        :part => part,
        :new_part => true,
        :part_index => params[:part_index]
      }
    end
    
    def destroy
      part = PagePart.find(params[:id])
      page = part.page
      if part.destroy
        page.reposition_parts!
        render :text => "'#{part.title}' deleted."
      else
        render :text => "'#{part.title}' not deleted."
      end
    end

  end
end
