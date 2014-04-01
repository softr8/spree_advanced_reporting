class Spree::AdvancedReport::IncrementReport::Revenue < Spree::AdvancedReport::IncrementReport
  def name
    I18n.t("adv_report.increment_report.revenue.name")
  end

  def column
    I18n.t("adv_report.increment_report.revenue.column")
  end

  def description
    I18n.t("adv_report.increment_report.revenue.description")
  end

  def initialize(params)
    super(params)
    self.total = 0

    self.orders.each do |order|
      date = {}
      INCREMENTS.each do |type|
        date[type] = get_bucket(type, (order.completed_at || order.updated_at))
        data[type][date[type]] ||= {
          :value => 0,
          :display => get_display(type, (order.completed_at || order.updated_at)),
        }
      end
      rev = revenue(order)
      INCREMENTS.each { |type| data[type][date[type]][:value] += rev }
      self.total += rev
    end

    generate_ruport_data

    INCREMENTS.each { |type| ruportdata[type].replace_column(name) { |r| "$%0.2f" % r[name] } }
  end

  def format_total
    '$' + ((self.total*100).round.to_f / 100).to_s
  end
end
