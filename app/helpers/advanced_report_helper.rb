module AdvancedReportHelper
  def order_states_options
    order_states.inject([]){ |acc, value| acc << [t("order_state.#{value}"), value]; acc}
  end
  
  def order_states
    if Spree::Order.respond_to? :progress_states
      Spree::Order.progress_states.unshift "complete"
    else
      Spree::Order.state_machines[:state].states.map(&:name)
    end
  end
end
