class Accounts::AiFollowupsController < InternalController
  def index
    ai_events = Event
      .joins(:contact)
      .joins('INNER JOIN deals ON deals.id = events.deal_id')
      .where("events.additional_attributes ->> 'ai_generated' = 'true'")
      .includes(:contact, deal: :stage)

    @pending_events = ai_events.where(done_at: nil).order(:scheduled_at)
    @done_events    = ai_events.where.not(done_at: nil).order(done_at: :desc).limit(20)
    @total_pending  = @pending_events.count
    @total_done     = ai_events.where.not(done_at: nil).count
  end
end
