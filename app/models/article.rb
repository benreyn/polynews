# frozen_string_literal: true

# == Schema Information
#
# Table name: articles
#
#  id           :bigint           not null, primary key
#  content      :text
#  description  :text
#  guid         :string           not null
#  published_at :datetime
#  title        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  channel_id   :bigint           not null
#
# Indexes
#
#  index_articles_on_channel_id  (channel_id)
#  index_articles_on_guid        (guid) UNIQUE
#
# Foreign Keys
#
#  fk_rails_64fe6f9351  (channel_id => channels.id)
#
class Article < ApplicationRecord
  belongs_to :channel

  validates :title, presence: true

  validates :guid, presence: true, uniqueness: true

  paginates_per 5
end