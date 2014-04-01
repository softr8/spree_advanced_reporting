class Spree::AdvancedReport::GeoReport::GeoUnits < Spree::AdvancedReport::GeoReport
  def name
    I18n.t("adv_report.geo_report.units.name")
  end

  def column
    I18n.t("adv_report.geo_report.units.column")
  end

  def description
    I18n.t("adv_report.geo_report.units.description")
  end
  def initialize(params)
    super(params)

    data = { :state => {}, :country => {} }
    orders.each do |order|
      units = units(order)
      if order.bill_address.state
        data[:state][order.bill_address.state_id] ||= {
          :name => order.bill_address.state.name,
          :units => 0
        }
        data[:state][order.bill_address.state_id][:units] += units
      end
      if order.bill_address.country
        data[:country][order.bill_address.country_id] ||= {
          :name => order.bill_address.country.name,
          :units => 0
        }
        data[:country][order.bill_address.country_id][:units] += units
      end
    end

    [:state, :country].each do |type|
      ruportdata[type] = Table(I18n.t("adv_report.geo_report.units.table"))
      data[type].each { |k, v| ruportdata[type] << { "location" => v[:name], I18n.t("adv_report.units") => v[:units] } }
      ruportdata[type].sort_rows_by!([I18n.t("adv_report.units")], :order => :descending)
      ruportdata[type].rename_column("location", type.to_s.capitalize)
    end
  end
end
