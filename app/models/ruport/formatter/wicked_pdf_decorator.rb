Ruport::Formatter::WickedPDF.class_eval do
  def finalize_table
    # TODO would be great to eliminate this hack
    
    # I think the reason the helper doesn't work is because of the pdf_from_string call vs the standard render :pdf
    # <%= wicked_pdf_stylesheet_link_tag "pdf" %>

    output.replace(WickedPdf.new.pdf_from_string("<style>" + Rails.application.assets.find_asset("pdf").body + "</style>" + output,
      :print_media_type => false
    ))
  end
end