class Spree::AdvancedReport::TopReport::TopProducts < Spree::AdvancedReport::TopReport
  
  def name
    I18n.t("adv_report.top_report.top_products.name")
  end

  def description
    I18n.t("adv_report.top_report.top_products.description")
  end

  def initialize(params, limit)
    super(params)

    orders.each do |order|
      order.line_items.each do |li|
        if !li.product.nil?
          data[li.product.id] ||= {
            :name => li.product.name.to_s,
            :revenue => 0,
            :units => 0
          }
          data[li.product.id][:revenue] += li.quantity*li.price 
          data[li.product.id][:units] += li.quantity
        end
      end
    end

    self.ruportdata = Table(I18n.t("adv_report.top_report.top_products.table"))
    data.inject({}) { |h, (k, v) | h[k] = v[:revenue]; h }.sort { |a, b| a[1] <=> b [1] }.reverse[0..limit].each do |k, v|
      ruportdata << { "name" => data[k][:name], I18n.t("adv_report.units") => data[k][:units], I18n.t("adv_report.revenue") => data[k][:revenue] } 
    end

    ruportdata.replace_column(I18n.t("adv_report.revenue")) { |r| "$%0.2f" % r.send(I18n.t("adv_report.revenue")) }
    ruportdata.rename_column("name", I18n.t("adv_report.top_report.top_products.product_name"))
  end
end
