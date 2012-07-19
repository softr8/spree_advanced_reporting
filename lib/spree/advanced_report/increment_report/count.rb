class Spree::AdvancedReport::IncrementReport::Count < Spree::AdvancedReport::IncrementReport
  def name
    I18n.t("adv_report.increment_report.count.name")
  end

  def column
    I18n.t("adv_report.increment_report.count.column")
  end

  def description
    I18n.t("adv_report.increment_report.count.description")
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
      order_count = order_count(order)
      INCREMENTS.each { |type| data[type][date[type]][:value] += order_count }
      self.total += order_count
    end

    generate_ruport_data
  end
end
