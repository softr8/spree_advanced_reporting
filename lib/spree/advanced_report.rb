module Spree
  class AdvancedReport
    include Ruport
    attr_accessor :orders, :product_text, :date_text, :taxon_text, :ruportdata, 
                  :data, :params, :taxon, :product, :product_in_taxon, :unfiltered_params, 
                  :product_in_group, :group, :group_text

    def name
      I18n.t("adv_report.base.name")
    end

    def description
      I18n.t("adv_report.base.description")
    end

    def prepare_for_interval(params, criteria)
      greater = "#{criteria}_greater_than".to_sym
      less = "#{criteria}_less_than".to_sym
      if params[:search][greater].blank?
        if (Order.count > 0) && Order.minimum(:completed_at)
          params[:search][greater] = Order.minimum(:completed_at).beginning_of_day
        end
      else
        params[:search][greater] = Time.zone.parse(params[:search][greater]).beginning_of_day rescue ""
      end
      if params[:search][less].blank?
        if (Order.count > 0) && Order.maximum(:completed_at)
          params[:search][less] = Order.maximum(:completed_at).end_of_day
        end
      else
        params[:search][less] = Time.zone.parse(params[:search][less]).end_of_day rescue ""
      end
      return params
    end

    def initialize(params)
      self.params = params
      self.data = {}
      self.ruportdata = {}
      self.unfiltered_params = params[:search].blank? ? {} : params[:search].clone

      params[:search] ||= {}

      params[:search][:state_equals] ||= "complete"

      if params[:search][:state_equals] == "complete"
        params = prepare_for_interval(params, "completed_at")
      end
      params = prepare_for_interval(params, "created_at")
      

      search = Order.metasearch(params[:search])
      self.orders = search.state_does_not_equal('canceled')

      self.product_in_taxon = true
      self.product_in_group = true
      if params[:advanced_reporting]
        if params[:advanced_reporting][:taxon_id] && params[:advanced_reporting][:taxon_id] != ''
          self.taxon = Taxon.find(params[:advanced_reporting][:taxon_id])
        end
        if params[:advanced_reporting][:group_id] && params[:advanced_reporting][:group_id] != ''
          self.group = ProductGroup.find(params[:advanced_reporting][:group_id])
        end
        if params[:advanced_reporting][:product_id] && params[:advanced_reporting][:product_id] != ''
          self.product = Product.find(params[:advanced_reporting][:product_id])
        end
      end
      if taxon && product && !in_taxonomy?(product, taxon)
        self.product_in_taxon = false
      end
      if group && product && !in_group?(product, group)
        self.product_in_group = false
      end

      if product
        self.product_text = "Product: #{self.product.name}<br />"
      end
      if taxon
        self.taxon_text = "Taxon: #{self.taxon.name}<br />"
      end
      if group
        self.group_text = "Group: #{self.group.name}<br />"
      end


      # Above searchlogic date settings
      self.date_text = "#{I18n.t("adv_report.base.range")}:"
      if self.unfiltered_params
        if self.unfiltered_params[:created_at_greater_than] != '' && self.unfiltered_params[:created_at_less_than] != ''
          self.date_text += " #{I18n.t("adv_report.base.from")} #{self.unfiltered_params[:created_at_greater_than]} to #{self.unfiltered_params[:created_at_less_than]}"
        elsif self.unfiltered_params[:created_at_greater_than] != ''
          self.date_text += " #{I18n.t("adv_report.base.after")} #{self.unfiltered_params[:created_at_greater_than]}"
        elsif self.unfiltered_params[:created_at_less_than] != ''
          self.date_text += " #{I18n.t("adv_report.base.before")} #{self.unfiltered_params[:created_at_less_than]}"
        else
          self.date_text += " #{I18n.t("adv_report.base.all")}"
        end
      else
        self.date_text += " #{I18n.t("adv_report.base.all")}"
      end
    end

    def in_taxonomy?(product, taxon)
      (product.taxons & taxon.self_and_children).present?
    end

    def in_group?(product, group)
      product.in? group.products
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
        rev = order.line_items.select { |li| li.product && in_taxonomy?(li.product, taxon) }.inject(0) { |a, b| a += b.quantity * b.price }
      elsif !self.group.nil?
        rev = order.line_items.select { |li| li.product && in_group?(li.product, group) }.inject(0) { |a, b| a += b.quantity * b.price }        
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
        profit = order.line_items.select { |li| li.product && in_taxonomy?(li.product, taxon) }
                .inject(0) { |profit, li| profit + (li.variant.price - li.variant.cost_price.to_f)*li.quantity }
      elsif !group.nil?
        profit = order.line_items.select { |li| li.product && in_group?(li.product, group) }
                .inject(0) { |profit, li| profit + (li.variant.price - li.variant.cost_price.to_f)*li.quantity }
      end
      adjustments_profit = order.adjustments.sum(:amount) - order.adjustments.sum(:cost)
      profit += adjustments_profit
      self.product_in_taxon ? profit : 0
    end

    def units(order)
      units = order.line_items.inject(0){ |units, li| units + line_items_units(li)}
      if !self.product.nil? && product_in_taxon
        units = order.line_items.select { |li| li.product == self.product }.inject(0) { |a, b| a += line_items_units(b) }
      elsif !self.taxon.nil?
        units = order.line_items.select { |li| li.product && in_taxonomy?(li.product, taxon) }.inject(0) { |a, b| a += line_items_units(b) }
      elsif !self.group.nil?
        units = order.line_items.select { |li| li.product && in_group?(li.product, group) }.inject(0) { |a, b| a += line_items_units(b) }
      end
      self.product_in_taxon ? units : 0
    end

    def line_items_units(line_item)
      line_item.variant.respond_to?(:bundle_quantity) ? line_item.quantity * line_item.variant.bundle_quantity : line_item.quantity
    end

    def order_count(order)
      self.product_in_taxon ? 1 : 0
    end
  end
end
