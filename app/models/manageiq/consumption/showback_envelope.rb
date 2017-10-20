class ManageIQ::Consumption::ShowbackEnvelope < ApplicationRecord
  self.table_name = 'showback_envelopes'

  belongs_to :resource, :polymorphic => true

  monetize :accumulated_cost_subunits
  default_value_for :accumulated_cost, Money.new(0)

  before_save :check_pool_state, :if => :state_changed?

  has_many :showback_data_views,
           :dependent  => :destroy,
           :inverse_of => :showback_envelope
  has_many :showback_data_rollups,
           :through    => :showback_data_views,
           :inverse_of => :showback_envelopes

  validates :name,                  :presence => true
  validates :description,           :presence => true
  validates :resource,              :presence => true
  validates :start_time, :end_time, :presence => true
  validates :state,                 :presence => true, :inclusion => { :in => %w(OPEN PROCESSING CLOSED) }

  # Test that end_time happens later than start_time.
  validate  :start_time_before_end_time

  def start_time_before_end_time
    errors.add(:end_time, _('should happen after start_time')) unless end_time.to_i > start_time.to_i
  end

  def check_pool_state
    case state_was
    when 'OPEN' then
      raise _("Pool can't change state to CLOSED from OPEN") unless state != 'CLOSED'
      # s_time = (self.start_time + 1.months).beginning_of_month # This is never used
      s_time = end_time != start_time.end_of_month ? end_time : (start_time + 1.month).beginning_of_month
      e_time = s_time.end_of_month
      generate_pool(s_time, e_time) unless ManageIQ::Consumption::ShowbackEnvelope.exists?(:resource => resource, :start_time => s_time)
    when 'PROCESSING' then raise _("Pool can't change state to OPEN from PROCESSING") unless state != 'OPEN'
    when 'CLOSED' then raise _("Pool can't change state when it's CLOSED")
    end
  end

  def add_event(event)
    if event.kind_of?(ManageIQ::Consumption::ShowbackDataRollup)
      # verify that the event is not already there
      if showback_events.include?(event)
        errors.add(:showback_events, 'duplicate')
      else
        charge = ManageIQ::Consumption::ShowbackDataView.new(:showback_data_rollup => event, :showback_envelope => self)
        charge.save
      end
    else
      errors.add(:showback_data_rollups, "Error Type #{event.type} is not ManageIQ::Consumption::ShowbackDataRollup")
    end
  end

  # Remove events from a pool, no error is thrown

  def remove_event(event)
    if event.kind_of?(ManageIQ::Consumption::ShowbackDataRollup)
      if showback_events.include?(event)
        showback_events.delete(event)
      else
        errors.add(:showback_data_rollups, "not found")
      end
    else
      errors.add(:showback_data_rollups, "Error Type #{event.type} is not ManageIQ::Consumption::ShowbackDataRollup")
    end
  end

  def get_charge(input)
    ch = find_charge(input)
    if ch.nil?
      Money.new(0)
    else
      ch.cost
    end
  end

  def update_charge(input, cost)
    ch = find_charge(input)
    unless ch.nil?
      ch.cost = Money.new(cost)
      ch
    end
  end

  def add_charge(input, cost)
    ch = find_charge(input)
    # updates an existing charge
    if ch
      ch.cost = Money.new(cost)
    elsif input.class == ManageIQ::Consumption::ShowbackDataRolllup # Or create a new one
      ch = showback_data_views.new(:showback_data_rollup => input,
                                :cost           => cost)
    else
      errors.add(:input, 'bad class')
      return
    end
    ch.save
    ch
  end

  def clear_charge(input)
    ch = find_charge(input)
    ch.cost = 0
    ch.save
  end

  def sum_of_charges
    a = Money.new(0)
    showback_charges.each do |x|
      a += x.cost if x.cost
    end
    a
  end

  def clean_all_charges
    showback_charges.each(&:clean_cost)
  end

  def calculate_charge(input)
    ch = find_charge(input)
    if ch.kind_of?(ManageIQ::Consumption::ShowbackDataView)
      ch.cost = ch.calculate_cost(find_price_plan) || Money.new(0)
      save
    elsif input.nil?
      errors.add(:showback_data_view, 'not found')
      Money.new(0)
    else
      input.errors.add(:showback_data_view, 'not found')
      Money.new(0)
    end
  end

  def calculate_all_charges
    # plan = find_price_plan
    showback_charges.each do |x|
      calculate_charge(x)
    end
  end

  def find_price_plan
    # TODO
    # For the demo: return one price plan, we will create the logic later
    # parent = resource
    # do
    # result = ManageIQ::Providers::Consumption::ConsumptionManager::ShowbackPricePlan.where(resource: parent)
    # parent = parent.parent if !result
    # while !result || !parent
    # result || ManageIQ::Providers::Consumption::ConsumptionManager::ShowbackPricePlan.where(resource = MiqEnterprise)
    ManageIQ::Consumption::ShowbackPricePlan.first
  end

  def find_charge(input)
    if input.kind_of?(ManageIQ::Consumption::ShowbackDataRollup)
      showback_charges.find_by(:showback_data_rollup => input, :showback_envelope => self)
    elsif input.kind_of?(ManageIQ::Consumption::ShowbackDataView) && (input.showback_envelope == self)
      input
    end
  end

  private

  def generate_pool(s_time, e_time)
    pool = ManageIQ::Consumption::ShowbackEnvelope.create(:name        => name,
                                                      :description => description,
                                                      :resource    => resource,
                                                      :start_time  => s_time,
                                                      :end_time    => e_time,
                                                      :state       => 'OPEN')
    showback_charges.each do |charge|
      ManageIQ::Consumption::ShowbackDataView.create(:data_snapshot    => {
                                                     charge.data_snapshot_last_key => charge.data_snapshot_last
                                                   },
                                                   :showback_data_rollup => charge.showback_event,
                                                   :showback_envelope  => pool,
                                                   :cost_subunits  => charge.cost_subunits,
                                                   :cost_currency  => charge.cost_currency)
    end
  end
end
