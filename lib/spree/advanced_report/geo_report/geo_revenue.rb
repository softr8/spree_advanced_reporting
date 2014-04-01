class Spree::AdvancedReport::GeoReport::GeoRevenue < Spree::AdvancedReport::GeoReport
  def name
    I18n.t("adv_report.geo_report.revenue.name")
  end

  def column
    I18n.t("adv_report.geo_report.revenue.column")
  end

  def description
    I18n.t("adv_report.geo_report.revenue.description")
  end

  def initialize(params)
    super(params)

    data = { :state => {}, :country => {} }
    orders.each do |order|
      revenue = revenue(order)
      if order.bill_address.state
        data[:state][order.bill_address.state_id] ||= {
          :name => order.bill_address.state.name,
          :revenue => 0
        }
        data[:state][order.bill_address.state_id][:revenue] += revenue
      end
      if order.bill_address.country
        data[:country][order.bill_address.country_id] ||= {
          :name => order.bill_address.country.name,
          :revenue => 0
        }
        data[:country][order.bill_address.country_id][:revenue] += revenue
      end
    end

    [:state, :country].each do |type|
      ruportdata[type] = Table(I18n.t("adv_report.geo_report.revenue.table"))
      data[type].each { |k, v| ruportdata[type] << { "location" => v[:name], I18n.t("adv_report.revenue") => v[:revenue] } }
      ruportdata[type].sort_rows_by!([I18n.t("adv_report.revenue")], :order => :descending)
      ruportdata[type].rename_column("location", type.to_s.capitalize)
      ruportdata[type].replace_column(I18n.t("adv_report.revenue")) { |r| "$%0.2f" % r.send(I18n.t("adv_report.revenue")) }
    end
  end
end
