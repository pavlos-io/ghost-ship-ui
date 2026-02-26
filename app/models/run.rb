class Run < ApplicationRecord
  has_many :run_entries, dependent: :destroy

  validates :creator, presence: true
  validates :source, presence: true
  validates :status, inclusion: { in: %w[queued running completed failed] }
end
