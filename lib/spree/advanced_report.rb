module Spree
  class AdvancedReport
    include Ruport
    attr_accessor :orders, :product_text, :date_text, :taxon_text, :ruportdata, :search,
                  :data, :params, :taxon, :product, :product_in_taxon, :unfiltered_params

    def name
      I18n.t("adv_report.base.name")
    end

    def description
      I18n.t("adv_report.base.description")
    end

    def initialize(params)
      # this enables subclasses to provide different defaults to the search
      # by setting the defaults before calling super
      self.params ||= params

      self.data = {}
      self.ruportdata = {}
      self.unfiltered_params = params[:search].blank? ? {} : params[:search].clone

      params[:search] ||= {}
      params[:advanced_reporting] ||= {}

      if Order.count > 0
        begin
          params[:search][:created_at_gt] = Time.zone.parse(params[:search][:created_at_gt]).beginning_of_day
        rescue 
          params[:search][:created_at_gt] = Date.today.beginning_of_day
        end

        # TODO if lt is defined, and gt is not, gt then should use better default than end of today
        # maybe 24 hours before the defined lt end of day
        
        begin
          params[:search][:created_at_lt] = Time.zone.parse(params[:search][:created_at_lt]).end_of_day
        rescue
          params[:search][:created_at_lt] = Date.today.end_of_day
        end
      end

      # offer shipped vs completed order filtering
      # in some cases, revenue reports should be based on the time when the revenue
      # is earned (i.e. shipped) not when the order was made or the credit card was processed

      # it is also important to exclude canceled orders and orders that were not completed
      # before spree 1.1.3 there was a bug that caused Spree::Shipment.shipped_at not be filled
      # easy fix is to copy the completed_at from the order associated with the shipment
      #   https://gist.github.com/3187793#file_shipments_shipped_at_fix.rb

      filter_address = 'billing'

      if params[:advanced_reporting][:state_based_on_taxable_address] == '1'
        filter_address = Spree::Config[:tax_using_ship_address] ? 'shipping' : 'billing'
      end

      if params[:advanced_reporting][:order_type] == 'shipped'
        shipped_search_params = {
          :shipped_at_gt => params[:search][:created_at_gt],
          :shipped_at_lt => params[:search][:created_at_lt],
          :order_state_not_eq => 'canceled',
          :order_completed_at_not_null => true
        }

        if params[:advanced_reporting][:state_id].present?
          shipped_search_params[
            filter_address == 'shipping' ? :order_ship_address_state_id_eq : :order_bill_address_state_id_eq
          ] = params[:advanced_reporting][:state_id]
        end

        # including the ransack predicate will not speed up the SQL query but will not include only fully shipped orders
        # TODO hopefully we can trust spree's built in shipment state in the future
        # https://github.com/spree/spree/blob/1-3-stable/core/app/models/spree/order_updater.rb#L68
        only_fully_shipped = params[:advanced_reporting][:shipment] == 'fully_shipped'
        shipped_search_params[:order_inventory_units_shipment_id_not_null] = true if only_fully_shipped

        # the tricky part here is that orders can have multiple shipments
        # we need to prevent orders from being included twice in the report
        # by choosing to include the order in the earliest report possible
        # (i.e. the first order that shipped) and exclude it from any reports after that

        @search = Shipment.includes(:order).search shipped_search_params

        self.orders = @search.result(:distinct => true).select do |shipment|
          # these manual exclusions could not be done via SQL queries as far as I could tell
          # they are ordered by least to greatest SQL complexity

          # if the shipment retrieved is the last shipment shipped for the order, then include the order
          next false if shipment.order.shipments.size > 1 && shipment.order.shipments.sort { |a, b| b.shipped_at <=> a.shipped_at }.first == shipment

          # conditionally exclude orders which are not fully shipped
          next false if only_fully_shipped && shipment.order.inventory_units.where(:shipment_id => nil).present?

          true
        end.map(&:order)
      else
        params[:search][:completed_at_not_null] = true
        params[:search][:state_not_eq] = 'canceled'

        if params[:advanced_reporting][:state_id].present?
          params[:search][
            filter_address == 'shipping' ? :ship_address_state_id_eq : :bill_address_state_id_eq
          ] = params[:advanced_reporting][:state_id]
        end

        only_fully_shipped = params[:advanced_reporting][:shipment] == 'fully_shipped'
        params[:inventory_units_shipment_id_not_null] = true if only_fully_shipped

        @search = Order.search(params[:search])

        self.orders = @search.result(:distinct => true).select do |order|
          # exclude orders that are not fully shipped
          next false if only_fully_shipped && order.inventory_units.where(:shipment_id => nil).present?
          true
        end
      end

      self.product_in_taxon = true
      if params[:advanced_reporting]
        if params[:advanced_reporting][:taxon_id] && params[:advanced_reporting][:taxon_id] != ''
          self.taxon = Taxon.find(params[:advanced_reporting][:taxon_id])
        end
        if params[:advanced_reporting][:product_id] && params[:advanced_reporting][:product_id] != ''
          self.product = Product.find(params[:advanced_reporting][:product_id])
        end
      end
      if self.taxon && self.product && !self.product.taxons.include?(self.taxon)
        self.product_in_taxon = false
      end

      if self.product
        self.product_text = "Product: #{self.product.name}<br />"
      end
      if self.taxon
        self.taxon_text = "Taxon: #{self.taxon.name}<br />"
      end

      # Above searchlogic date settings
      self.date_text = "#{I18n.t("adv_report.base.range")}:"
      if self.unfiltered_params
        if self.unfiltered_params[:created_at_gt] != '' && self.unfiltered_params[:created_at_lt] != ''
          self.date_text += " #{I18n.t("adv_report.base.from")} #{self.unfiltered_params[:created_at_gt]} to #{self.unfiltered_params[:created_at_lt]}"
        elsif self.unfiltered_params[:created_at_gt] != ''
          self.date_text += " #{I18n.t("adv_report.base.after")} #{self.unfiltered_params[:created_at_gt]}"
        elsif self.unfiltered_params[:created_at_lt] != ''
          self.date_text += " Before #{self.unfiltered_params[:created_at_lt]}"

        # TODO this was pulled in from another branch and has some nice internationalization improvements
        # if self.unfiltered_params[:created_at_greater_than] != '' && self.unfiltered_params[:created_at_less_than] != ''
        #   self.date_text += " #{I18n.t("adv_report.base.from")} #{self.unfiltered_params[:created_at_greater_than]} to #{self.unfiltered_params[:created_at_less_than]}"
        # elsif self.unfiltered_params[:created_at_greater_than] != ''
        #   self.date_text += " #{I18n.t("adv_report.base.after")} #{self.unfiltered_params[:created_at_greater_than]}"
        # elsif self.unfiltered_params[:created_at_less_than] != ''
        #   self.date_text += " #{I18n.t("adv_report.base.before")} #{self.unfiltered_params[:created_at_less_than]}"
        else
          self.date_text += " #{I18n.t("adv_report.base.all")}"
        end
      else
        self.date_text += " #{I18n.t("adv_report.base.all")}"
      end
    end

    def download_url(base, format, report_type = nil)
      elements = []
      params[:advanced_reporting] ||= {}
      params[:advanced_reporting]["report_type"] = report_type if report_type
      if params
        [:search, :advanced_reporting].each do |type|
          if params[type]
            params[type].each { |k, v| elements << "#{type}[#{k}]=#{v}" }
          end
        end
      end
      base.gsub!(/^\/\//,'/')
      base + '.' + format + '?' + elements.join('&')
    end

    def revenue(order)
      rev = order.item_total
      if !self.product.nil? && product_in_taxon
        rev = order.line_items.select { |li| li.product == self.product }.inject(0) { |a, b| a += b.quantity * b.price }
      elsif !self.taxon.nil?
        rev = order.line_items.select { |li| li.product && li.product.taxons.include?(self.taxon) }.inject(0) { |a, b| a += b.quantity * b.price }
      end
      adjustment_revenue = order.adjustments.sum(:amount)
      rev += adjustment_revenue if rev > 0
      self.product_in_taxon ? rev : 0
    end

    def profit(order)
      profit = order.line_items.inject(0) { |profit, li| profit + (li.variant.price - li.variant.cost_price.to_f)*li.quantity }
      if !self.product.nil? && product_in_taxon
        profit = order.line_items.select { |li| li.product == self.product }.inject(0) { |profit, li| profit + (li.variant.price - li.variant.cost_price.to_f)*li.quantity }
      elsif !self.taxon.nil?
        profit = order.line_items.select { |li| li.product && li.product.taxons.include?(self.taxon) }.inject(0) { |profit, li| profit + (li.variant.price - li.variant.cost_price.to_f)*li.quantity }
      end
      profit += order.adjustments.sum(:amount)
      self.product_in_taxon ? profit : 0
    end

    def units(order)
      units = order.line_items.sum(:quantity)
      if !self.product.nil? && product_in_taxon
        units = order.line_items.select { |li| li.product == self.product }.inject(0) { |a, b| a += b.quantity }
      elsif !self.taxon.nil?
        units = order.line_items.select { |li| li.product && li.product.taxons.include?(self.taxon) }.inject(0) { |a, b| a += b.quantity }
      end
      self.product_in_taxon ? units : 0
    end

    def order_count(order)
      self.product_in_taxon ? 1 : 0
    end

    def date_range
      if self.params[:search][:created_at_gt].to_date == self.params[:search][:created_at_lt].to_date
        self.params[:search][:created_at_gt].to_date.to_s
      else
        "#{self.params[:search][:created_at_gt].to_date} &ndash; #{self.params[:search][:created_at_lt].to_date}"
      end
    end
  end
end
