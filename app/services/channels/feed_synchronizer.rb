# frozen_string_literal: true

require 'open-uri'
require 'action_view'

module Channels
  class FeedSynchronizer < ApplicationService
    include ActionView::Helpers::SanitizeHelper

    attr_reader :channel, :feed, :invalid_entry_count, :discard_articles_before,
                :allowed_invalid_entry_percent

    delegate :last_build_date, to: :channel

    def initialize(
      channel,
      allowed_invalid_entry_percent: 0.1,
      discard_articles_before: DateTime.now - 2.days
    )
      @channel = channel
      @invalid_entry_count = 0
      @allowed_invalid_entry_percent = allowed_invalid_entry_percent
      @discard_articles_before = discard_articles_before
    end

    def call
      download_feed

      return success(:no_update_required) unless requires_update?

      update_channel
      create_or_update_articles
      success(:update_completed)
    end

    def download_feed
      @feed = Feedjira.parse(
        URI.parse(channel.url).read
      )
    end

    def requires_update?
      return true unless feed.respond_to?(:last_built)
      return true unless last_build_date

      last_build_date < feed.last_built
    end

    def update_channel
      return unless feed.respond_to?(:last_built)

      channel.update!(last_build_date: feed&.last_built)
    end

    def create_or_update_articles
      feed.entries.each do |item|
        next unless item.published
        next unless discard_articles_before < item.published

        article = Article.find_or_initialize_by(
          guid: item.entry_id || item.url,
          channel: channel
        )

        create_article_from_item(article, item) unless article.persisted?
      end
    end

    private

    def create_article_from_item(article, item)
      article.update!(
        title: item.title,
        description: item.summary,
        published_at: item.published,
        content: item.content,
        url: item.url,
        image_url: Channels::ImageUrlParser.new(item).url
      )
    rescue StandardError => e # rubocop:disable Lint/UselessAssignment
      handle_article_creation_error(item)
    end

    def handle_article_creation_error(item)
      # These feeds sometimes have invalid data (like malformed urls for an
      # entry) that prevent processing.
      #
      # For our purposes it's usually ok to drop a few articles so long as the
      # balance of the feed is behaving itself.
      #
      # Continue processing the feed and ignore up to the specified threshold
      @invalid_entry_count += 1

      if invalid_entry_count > max_allowed_invalid_entries # rubocop:disable Style/GuardClause
        raise ExceededMaxInvalidEntryCount, \
              "Channel: #{channel.id} is invalid. Item: #{item.inspect}"
      end
    end

    def max_allowed_invalid_entries
      allowed_invalid_entry_percent * feed.entries.count.to_f
    end

    class ExceededMaxInvalidEntryCount < StandardError; end
  end
end
