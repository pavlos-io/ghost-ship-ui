class RunsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]

  def index
    runs = Run.order(created_at: :desc)
    render :index, locals: { runs: runs }
  end

  def show
    run = Run.includes(:run_entries).find(params[:id])
    raw_data = run.run_entries.order(:created_at).map(&:data)
    result = EventNormalizer.normalize(raw_data)
    session = build_session(result[:events])
    render :show, locals: { run: run, session: session, normalizer_name: result[:normalizer] }
  end

  def new
    render :new
  end

  def create
    respond_to do |format|
      format.html do
        prompt = params.require(:prompt)
        run = Run.create!(creator: "web", source: "web", status: "queued")
        SandboxJob.perform_later(run.id, prompt)
        redirect_to run_path(run)
      end

      format.json do
        run = Run.new(run_permitted_params)
        if run.save
          render json: run.id, status: :created
        else
          render json: { errors: run.errors }, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def run_permitted_params
    params.expect(run: [:creator, :source])
  end

  def build_session(events)
    session = {
      source: nil,
      session_id: nil,
      model: nil,
      status: "running",
      turns: [],
      errors: [],
      started_at: nil,
      ended_at: nil
    }

    events.each do |event|
      case event["type"]
      when "session.start"
        session[:source] = event["source"]
        session[:session_id] = event["session_id"]
        session[:model] = event["model"]
        session[:started_at] = event["ts"]

      when "turn.start"
        session[:turns] << {
          turn_index: event["turn_index"],
          message_id: event["message_id"],
          status: "running",
          thinking_text: "",
          message_text: "",
          tools: [],
          stop_reason: nil,
          usage: nil,
          errors: [],
          started_at: event["ts"],
          ended_at: nil
        }

      when "message.delta"
        turn = session[:turns][event["turn_index"]]
        turn[:message_text] << event["text"] if turn

      when "message"
        turn = session[:turns][event["turn_index"]]
        turn[:message_text] = event["text"] if turn

      when "thinking.delta"
        turn = session[:turns][event["turn_index"]]
        turn[:thinking_text] << event["text"] if turn

      when "thinking"
        turn = session[:turns][event["turn_index"]]
        turn[:thinking_text] = event["text"] if turn

      when "tool.start"
        turn = session[:turns][event["turn_index"]]
        if turn
          turn[:tools] << {
            tool_use_id: event["tool_use_id"],
            tool: event["tool"],
            input: event["input"],
            status: "running",
            started_at: event["ts"],
            ended_at: nil
          }
        end

      when "tool.end"
        turn = session[:turns][event["turn_index"]]
        if turn
          tool = turn[:tools].find { |t| t[:tool_use_id] == event["tool_use_id"] }
          if tool
            tool[:input] = event["input"]
            tool[:status] = "completed"
            tool[:ended_at] = event["ts"]
          end
        end

      when "turn.end"
        turn = session[:turns][event["turn_index"]]
        if turn
          turn[:status] = event["status"] || "completed"
          turn[:stop_reason] = event["stop_reason"]
          turn[:usage] = event["usage"]
          turn[:ended_at] = event["ts"]
        end

      when "error"
        error_entry = { message: event["message"], ts: event["ts"] }
        last_turn = session[:turns].last
        if last_turn && last_turn[:status] == "running"
          last_turn[:errors] << error_entry
        else
          session[:errors] << error_entry
        end

      when "session.end"
        session[:status] = event["status"] || "completed"
        session[:ended_at] = event["ts"]
      end
    end

    # Handle interrupted streams
    session[:turns].each do |turn|
      turn[:status] = "interrupted" if turn[:status] == "running"
    end
    session[:status] = "interrupted" if session[:status] == "running" && session[:ended_at].nil?

    session
  end
end
