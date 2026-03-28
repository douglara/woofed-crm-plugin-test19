module Plugins
  module AiFeatures
    module DealExtension
      extend ActiveSupport::Concern

      def ai_lead_score
        return @ai_lead_score if defined?(@ai_lead_score)
        score = events_engagement_score + stage_progression_score + deal_completeness_score
        @ai_lead_score = [[score, 0].max, 100].min
      end

      def ai_lead_score_label
        case ai_lead_score
        when 70..100 then :hot
        when 40..69  then :warm
        else              :cold
        end
      end

      def ai_lead_score_badge_classes
        case ai_lead_score_label
        when :hot  then 'bg-auxiliary-palette-green-down text-auxiliary-palette-green'
        when :warm then 'bg-auxiliary-palette-blue-down text-auxiliary-palette-blue'
        else            'bg-brand-palette-07 text-dark-gray-palette-p1'
        end
      end

      def ai_lead_score_label_text
        I18n.t("activerecord.models.deal.ai_lead_score.labels.#{ai_lead_score_label}")
      end

      private

      def events_engagement_score
        all_events = events.where.not(kind: Event::DEAL_UPDATE_KINDS)
        recent_count  = all_events.where('events.created_at > ?', 7.days.ago).count
        monthly_count = all_events.where('events.created_at > ?', 30.days.ago).count
        message_count = all_events.where(kind: %w[chatwoot_message evolution_api_message]).count
        overdue_count = events.planned_overdue.count

        score  = [recent_count  * 8, 30].min
        score += [monthly_count * 3, 15].min
        score += [message_count * 4, 20].min
        score -= [overdue_count * 5, 15].min
        score
      end

      def stage_progression_score
        return 0 unless stage && pipeline
        stages        = pipeline.stages.order(:position).to_a
        current_index = stages.index { |s| s.id == stage_id }
        return 0 unless current_index
        ((current_index.to_f / [stages.count - 1, 1].max) * 30).round
      end

      def deal_completeness_score
        score  = 0
        score += 5 if users.exists?
        score += 5 unless total_amount_in_cents.zero?
        score
      end
    end
  end
end
