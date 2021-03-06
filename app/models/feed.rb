require 'htmlentities'

class Feed < ApplicationRecord
  MAX_TITLE_LENGTH = ENV['MAX_TITLE_LENGTH'].to_i || 255
  MAX_BODY_LENGTH  = ENV['MAX_BODY_LENGTH'].to_i  || 1024

  extend FriendlyId

  has_many :links, dependent: :destroy

  validates :slug, :title, :url, presence: true
  validates :slug, :title, :url, uniqueness: true

  after_create :start_fetching
  before_validation :set_title

  friendly_id :title, use: :slugged

  def fetch
    feed.entries.each do |entry|
      # Find or start a new link for the url
      link = links.find_or_initialize_by(url: entry.url)

      # Set published_at date
      published_date = [entry.published, DateTime.now].compact.min
      link.published_at ||= [published_date, last_fetched_at].compact.max

      # Skip link if older than 1 week
      next if link.published_at < Link::TTL.ago

      # Set guid
      link.guid = [slug, (entry.entry_id || entry.url)].join('_')

      # Set title
      title = ActionController::Base.helpers.strip_tags(entry.title)
      link.title = HTMLEntities.new.decode(title).truncate(MAX_TITLE_LENGTH)

      # Set body
      body = entry.content || entry.summary || title
      body = ActionController::Base.helpers.strip_tags(body)
      link.body  = HTMLEntities.new.decode(body).truncate(MAX_BODY_LENGTH)

      # Set author
      author_name = ActionController::Base.helpers.strip_tags entry.author
      link.author = Author.find_or_create_by(name: author_name)

      # Save changes
      link.save
    end

    # Update the last fetched time once done
    update(last_fetched_at: DateTime.now)
  end

  def publish_rate
    Link::TTL / (links_count + 1)
  end

  def score
    return 0.0 if links.sum(:impressions_count).zero?
    links.sum(:clicks_count) / links.sum(:impressions_count)
  end

  private

  def start_fetching
    FetchLinksJob.perform_later id
  end

  def set_title
    self.title ||= feed.title
  end

  def feed
    @feed ||= Feedjira::Feed.fetch_and_parse(url)
  end
end
