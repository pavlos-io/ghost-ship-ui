class RunEntriesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]
  
  def create
    run = Run.find(params[:run_id])
    entry = run.run_entries.new(entry_permitted_params)

    if entry.save
      render json: entry, status: :created
    else
      render json: { errors: entry.errors }, status: :unprocessable_entity
    end
  end

  private

  def entry_permitted_params
    params.expect(run_entry: {}).tap do |permitted|
      permitted[:data] = params[:run_entry][:data]&.permit!
    end
  end
end
