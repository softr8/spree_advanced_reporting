class Spree::AdvancedReport::TransactionReport < Spree::AdvancedReport
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::UrlHelper

  def name
    "Transaction Report"
  end

  def description
    "List of transactions that passed through the gateway"
  end

  def initialize(params)
    super(params)

    self.ruportdata = Ruport::Data::Group.new({
      :name => "#{self.name} #{self.date_range}",
      :column_names => %w[date type id total state]
    })

    card_listing = {}

    orders.each do |order|
      order.payments.each do |payment|
        # create a direct link for easy inspection
        gateway_link = payment.response_code

        if payment.payment_method.type == "Spree::Gateway::AuthorizeNetCim" and payment.response_code.present?
          gateway_link = link_to(payment.response_code, "https://account.authorize.net/UI/themes/anet/transaction/transactiondetail.aspx?transID=#{payment.response_code}", target: '_blank')
        end

        if payment.source.class == Spree::CreditCard
          credit_cart_type = payment.source.cc_type
        else
          # it seems as though a previous payment can be used a payment type
          # links to the previous payment's credit card
          credit_cart_type = payment.source.source.cc_type
        end

        (card_listing[credit_cart_type] ||= []) << {
          "date" => payment.source.created_at.to_formatted_s,
          "type" => credit_cart_type.humanize.titlecase,
          "id" => gateway_link,
          "total" => payment.amount,
          "state" => payment.state,
        }
      end
    end

    @sales_total = 0

    card_listing.keys.sort.each do |card_name|
      card_total = card_listing[card_name].map { |c| c["total"] * (c["state"] == 'void' ? 0 : 1) }.sum
      @sales_total += card_total

      ruportdata << {
        "date" => "<b>#{card_name.humanize.titlecase} (#{card_listing[card_name].count}): #{number_to_currency(card_total)}</b>"
      }

      card_listing[card_name].each do |transaction|
        transaction["total"] = number_to_currency(transaction["total"])
        ruportdata << transaction
      end
    end
    
    ruportdata << { "date" => "<b>Sales Total: #{number_to_currency(@sales_total)}</b>" }

    # spaces don't seem to work in column names (ruport is old...)
    ruportdata.rename_column("date", "Transaction Date")
    ruportdata.rename_column("type", "Card Type")
    ruportdata.rename_column("id", "Transaction ID")
    ruportdata.rename_column("total", "Payment Total")
    ruportdata.rename_column("state", "Payment State")
  end

  def sales_total
    @sales_total
  end
end
