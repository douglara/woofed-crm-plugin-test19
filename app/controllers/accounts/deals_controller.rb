Plugins::FilePatch.define target: 'app/controllers/accounts/deals_controller.rb' do
  replace_line containing: 'only: %i[show edit update destroy events_to_do events_done deal_products deal_assignees mark_as_lost mark_as_won drag_and_drop]',
               with: '                only: %i[show edit update destroy events_to_do events_done deal_products deal_assignees mark_as_lost mark_as_won drag_and_drop toggle_ai_followup]'

  before_line containing: '  private' do
    <<-RUBY

  def toggle_ai_followup
    enabled = !@deal.custom_attributes.fetch('ai_followup_enabled', false)
    @deal.update_column(:custom_attributes, @deal.custom_attributes.merge('ai_followup_enabled' => enabled))

    if enabled
      create_ai_followup_events
    else
      delete_ai_followup_events
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to account_deal_path(current_user.account, @deal) }
    end
  end

    RUBY
  end

  before_line containing: '# Only allow a list of trusted parameters through.' do
    <<-'RUBY'

  def create_ai_followup_events
    templates = [
      { days: 3,  title: "Follow-up #{@deal.contact.full_name} (3 dias)",  content: "Olá #{@deal.contact.full_name}, como está? Queria verificar se você teve a chance de pensar em #{@deal.name}. Estou à disposição para tirar qualquer dúvida!" },
      { days: 7,  title: "Follow-up #{@deal.contact.full_name} (7 dias)",  content: "#{@deal.contact.full_name}, passando para verificar se houve alguma evolução em relação a #{@deal.name}. Podemos agendar uma conversa rápida?" },
      { days: 14, title: "Follow-up #{@deal.contact.full_name} (14 dias)", content: "Olá #{@deal.contact.full_name}! Ainda temos interesse em avançar com #{@deal.name}? Fique à vontade para entrar em contato quando quiser." }
    ]

    templates.each do |t|
      event = @deal.contact.events.build(
        deal: @deal,
        kind: 'note',
        title: t[:title],
        scheduled_at: Time.current + t[:days].days,
        auto_done: true,
        additional_attributes: { 'ai_generated' => true, 'followup_days' => t[:days] }
      )
      event.content = t[:content]
      event.save!
    end
  end

  def delete_ai_followup_events
    @deal.contact.events
      .where(deal: @deal)
      .where("additional_attributes ->> 'ai_generated' = 'true'")
      .where(done_at: nil)
      .destroy_all
  end

    RUBY
  end
end
