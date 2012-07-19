class Spree::AdvancedReport::GeoReport::GeoProfit < Spree::AdvancedReport::GeoReport
  def name
    I18n.t("adv_report.geo_report.profit.name")
  end

  def column
    I18n.t("adv_report.geo_report.profit.column")
  end

  def description
    I18n.t("adv_report.geo_report.profit.description")
  end

  def initialize(params)
    super(params)

    data = { :state => {}, :country => {} }
    orders.each do |order|
      profit = profit(order)
      if order.bill_address.state
        data[:state][order.bill_address.state_id] ||= {
          :name => order.bill_address.state.name,
          :profit => 0
        }
        data[:state][order.bill_address.state_id][:profit] += profit
      end
      if order.bill_address.country
        data[:country][order.bill_address.country_id] ||= {
          :name => order.bill_address.country.name,
          :profit => 0
        }
        data[:country][order.bill_address.country_id][:profit] += profit
      end
    end

    [:state, :country].each do |type|
      ruportdata[type] = Table(%w[location Profit])
      data[type].each { |k, v| ruportdata[type] << { "location" => v[:name], "Profit" => v[:profit] } }
      ruportdata[type].sort_rows_by!(["Profit"], :order => :descending)
      ruportdata[type].rename_column("location", type.to_s.capitalize)
      ruportdata[type].replace_column("Profit") { |r| "$%0.2f" % r.Profit }
    end
  end
end
