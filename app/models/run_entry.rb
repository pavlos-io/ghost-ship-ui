class RunEntry < ApplicationRecord
  belongs_to :run

  validates :data, presence: true
  validates :run, presence: true
end
