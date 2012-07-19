class Spree::AdvancedReport::IncrementReport::Units < Spree::AdvancedReport::IncrementReport
  def name
    I18n.t("adv_report.increment_report.units.name")
  end

  def column
    I18n.t("adv_report.increment_report.units.column")
  end

  def description
    I18n.t("adv_report.increment_report.units.description")
  end

  def initialize(params)
    super(params)
    self.total = 0
    self.orders.each do |order|
      date = {}
      INCREMENTS.each do |type|
        date[type] = get_bucket(type, order.completed_at)
        data[type][date[type]] ||= {
          :value => 0, 
          :display => get_display(type, order.completed_at),
        }
      end
      units = units(order)
      INCREMENTS.each { |type| data[type][date[type]][:value] += units }
      self.total += units
    end

    generate_ruport_data
  end
end
