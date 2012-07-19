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
        date[type] = get_bucket(type, order.completed_at)
        data[type][date[type]] ||= {
          :value => 0,
          :display => get_display(type, order.completed_at),
        }
      end
      rev = order.item_total
      if !self.product.nil? && product_in_taxon
        rev = order.line_items.select { |li| li.product == self.product }.inject(0) { |a, b| a += b.quantity * b.price }
      elsif !self.taxon.nil?
        rev = order.line_items.select { |li| li.product && li.product.taxons.include?(self.taxon) }.inject(0) { |a, b| a += b.quantity * b.price }
      end
      rev = 0 if !self.product_in_taxon
      INCREMENTS.each { |type| data[type][date[type]][:value] += rev }
      self.total += rev
    end

    generate_ruport_data

    INCREMENTS.each { |type| ruportdata[type].replace_column("Revenue") { |r| "$%0.2f" % r["Revenue"] } }
  end

  def format_total
    '$' + ((self.total*100).round.to_f / 100).to_s
  end
end
