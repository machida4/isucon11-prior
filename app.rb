require "sinatra/json"
require "active_support/json"
require "active_support/time"
require_relative "db"

Time.zone = "UTC"

class App < Sinatra::Base
  enable :logging

  set :session_secret, "tagomoris"
  set :sessions, key: "session_isucon2021_prior", expire_after: 3600
  set :show_exceptions, false
  # set :public_folder, "./public"
  set :json_encoder, ActiveSupport::JSON

  helpers do
    def db
      DB.connection
    end

    def transaction(name = :default, &block)
      DB.transaction(name, &block)
    end

    # def redis
    #   Thread.current[:redis] ||= Redis.new(host: "127.0.0.1", port: 6380, driver: :hiredis)
    # end

    def required_login!
      halt(401, JSON.generate(error: "login required")) if current_user.nil?
    end

    def required_staff_login!
      halt(401, JSON.generate(error: "login required")) if current_user.nil? || !current_user[:staff]
    end

    def current_user
      @current_user ||= db.xquery("SELECT `id`, `email`, `nickname`, `staff`, `nickname` FROM `users` WHERE `id` = ? LIMIT 1", session[:user_id]).first
    end

    def get_reservations(schedule)
      reservations = db.xquery("SELECT `id`, `schedule_id`, `user_id`, `created_at` FROM `reservations` WHERE `schedule_id` = ?", schedule[:id])
      if !(reservations.size == 0)
        reservation_user_ids = reservations.map { |reservation| reservation[:user_id] }

        users = db.xquery("SELECT `id`, `email`, `nickname`, `staff`, `nickname` FROM `users` WHERE `id` IN (?)", [reservation_user_ids])
        users_map = users.map do |user|
          user[:email] = "" if !current_user || !current_user[:staff]

          [user[:id], user]
        end.to_h

        reservations = reservations.map do |reservation|
          reservation[:user] = users_map[reservation[:user_id]]
          reservation
        end
      end

      schedule[:reservations] = reservations
      schedule[:reserved] = reservations.size
    end
  end

  error do
    err = env["sinatra.error"]
    warn err.full_message
    halt 500, JSON.generate(error: err.message)
  end

  post "/initialize" do
    transaction do |tx|
      tx.query("TRUNCATE `reservations`")
      tx.query("TRUNCATE `schedules`")
      tx.query("TRUNCATE `users`")

      id = ULID.generate
      tx.xquery("INSERT INTO `users` (`id`, `email`, `nickname`, `staff`, `created_at`) VALUES (?, ?, ?, true, NOW(6))", id, "isucon2021_prior@isucon.net", "isucon")
    end

    # redis.flushall

    json(language: "ruby")
  end

  get "/api/session" do
    json(current_user)
  end

  post "/api/signup" do
    id = ""
    nickname = ""

    user = transaction do |tx|
      id = ULID.generate
      email = params[:email]
      nickname = params[:nickname]
      created_at = Time.now
      tx.xquery("INSERT INTO `users` (`id`, `email`, `nickname`, `created_at`) VALUES (?, ?, ?, ?)", id, email, nickname, created_at)

      {id: id, email: email, nickname: nickname, created_at: created_at}
    end

    json(user)
  end

  post "/api/login" do
    email = params[:email]

    user = db.xquery("SELECT `id`, `nickname` FROM `users` WHERE `email` = ? LIMIT 1", email).first

    if user
      session[:user_id] = user[:id]
      json({id: current_user[:id], email: current_user[:email], nickname: current_user[:nickname], created_at: current_user[:created_at]})
    else
      session[:user_id] = nil
      halt 403, JSON.generate({error: "login failed"})
    end
  end

  post "/api/schedules" do
    required_staff_login!

    transaction do |tx|
      id = ULID.generate
      title = params[:title].to_s
      capacity = params[:capacity].to_i
      created_at = Time.now

      tx.xquery("INSERT INTO `schedules` (`id`, `title`, `capacity`, `created_at`) VALUES (?, ?, ?, ?)", id, title, capacity, created_at)

      json({id: id, title: title, capacity: capacity, created_at: created_at})
    end
  end

  post "/api/reservations" do
    required_login!

    transaction do |tx|
      id = ULID.generate
      schedule_id = params[:schedule_id].to_s
      user_id = current_user[:id]

      halt(403, JSON.generate(error: "schedule not found")) if tx.xquery("SELECT 1 FROM `schedules` WHERE `id` = ? LIMIT 1 FOR UPDATE", schedule_id).first.nil?
      halt(403, JSON.generate(error: "user not found")) unless tx.xquery("SELECT 1 FROM `users` WHERE `id` = ? LIMIT 1", user_id).first
      halt(403, JSON.generate(error: "already taken")) if tx.xquery("SELECT 1 FROM `reservations` WHERE `schedule_id` = ? AND `user_id` = ? LIMIT 1", schedule_id, user_id).first

      capacity = tx.xquery("SELECT `capacity` FROM `schedules` WHERE `id` = ? LIMIT 1", schedule_id).first[:capacity]
      reserved = tx.xquery("SELECT COUNT(*) AS count FROM `reservations` WHERE `schedule_id` = ?", schedule_id).first[:count]

      halt(403, JSON.generate(error: "capacity is already full")) if reserved >= capacity

      created_at = Time.now
      tx.xquery("INSERT INTO `reservations` (`id`, `schedule_id`, `user_id`, `created_at`) VALUES (?, ?, ?, ?)", id, schedule_id, user_id, created_at)

      json({id: id, schedule_id: schedule_id, user_id: user_id, created_at: created_at})
    end
  end

  get "/api/schedules" do
    schedules = db.xquery("SELECT `id`, `title`, `capacity`, `created_at` FROM `schedules` ORDER BY `id` DESC")
    schedule_id_count = db.xquery("SELECT schedule_id, COUNT(schedule_id) AS count FROM reservations GROUP BY schedule_id")
    schedule_id_count_map = schedule_id_count.map do |si|
      [si[:schedule_id], si[:count]]
    end.to_h

    schedules = schedules.map do |schedule|
      schedule[:reserved] = schedule_id_count_map.fetch(schedule[:id], 0)
      schedule
    end

    json(schedules.to_a)
  end

  get "/api/schedules/:id" do
    id = params[:id]
    schedule = db.xquery("SELECT `id`, `title`, `capacity`, `created_at` FROM `schedules` WHERE id = ? LIMIT 1", id).first
    halt(404, {}) unless schedule

    get_reservations(schedule)

    json(schedule)
  end
end
