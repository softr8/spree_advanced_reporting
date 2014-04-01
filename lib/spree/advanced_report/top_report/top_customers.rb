class Spree::AdvancedReport::TopReport::TopCustomers < Spree::AdvancedReport::TopReport
  def name
    I18n.t("adv_report.top_report.top_customers.name")
  end

  def description
    I18n.t("adv_report.top_report.top_customers.description")
  end

  def initialize(params, limit)
    super(params)

    orders.each do |order|
      if order.user
        data[order.user.id] ||= {
          :email => order.user.email,
          :revenue => 0,
          :units => 0
        }
        data[order.user.id][:revenue] += revenue(order)
        data[order.user.id][:units] += units(order)
      end
    end

    self.ruportdata = Table(I18n.t("adv_report.top_report.top_customers.table"))
    data.inject({}) { |h, (k, v) | h[k] = v[:revenue]; h }.sort { |a, b| a[1] <=> b [1] }.reverse[0..limit].each do |k, v|
      ruportdata << { "email" => data[k][:email], "Units" => data[k][:units], "Revenue" => data[k][:revenue] } 
    end
    ruportdata.replace_column(I18n.t("adv_report.revenue")) { |r| "$%0.2f" % r.send(I18n.t("adv_report.revenue")) }
    ruportdata.rename_column("email", I18n.t("adv_report.top_report.top_customers.customer_email"))
  end
end
