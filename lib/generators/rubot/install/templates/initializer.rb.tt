Rubot.configure do |config|
  # Pipe events into your app's logging or tracing stack.
  config.event_subscriber = lambda do |run, event|
    Rails.logger.info("[rubot] #{run.id} #{event.type} #{event.payload.to_json}")
  end

  # The install generator also creates the Rubot tables, so default to the
  # Active Record-backed store. For local-only demos, MemoryStore is still
  # available as a lightweight alternative.
  config.store = Rubot::Stores::ActiveRecordStore.new
end
