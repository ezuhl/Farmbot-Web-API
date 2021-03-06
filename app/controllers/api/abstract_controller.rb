module Api
  class AbstractController < ApplicationController
    respond_to :json
    before_action :authenticate_user!
    skip_before_action :verify_authenticity_token

    rescue_from(JWT::VerificationError) { |e| auth_err }

    rescue_from Errors::Forbidden do |exc|
      sorry "You can't perform that action. #{exc.message}", 403
    end

    rescue_from ActiveRecord::RecordNotFound do |exc|
      sorry "Document not found.", 404
    end

    rescue_from ActiveRecord::RecordInvalid do |exc|
      render json: {error: exc.message}, status: 422
    end

private

    def current_device
      @current_device ||= (current_user.try(:device) || null_device)
    end

    def null_device
      @null_device ||= NullDevice.new(name:  'null_device',
                                      uuid: '-')
    end

    def authenticate_user!
      # All possible information that could be needed for any of the 3 auth
      # strategies.
      context = { 
                  jwt:           request.headers["Authorization"],
                  user:          current_user }
      # Returns a symbol representing the appropriate auth strategy, or nil if
      # unknown.
      strategy = Auth::DetermineAuthStrategy.run!(context)
      case strategy
      when :jwt
        sign_in(Auth::FromJWT.run!(context))
      when :already_connected
        # Probably provided a cookie.
        return true
      else
        auth_err
      end
    rescue Mutations::ValidationException => e
      errors = e.errors.message.merge(strategy: strategy)
      render json: {error: errors}, status: 401
    end

    def auth_err
      sorry("You failed to authenticate with the API. Ensure that you " \
          "have provided a `bot_token` and `bot_uuid` header in the HTTP" \
          " request. Alternatively, you may provide a JSON Web Token in the " \
          " `Authorization:` header" , 401)
    end

    def sorry(msg, status)
      render json: { error: msg }, status: status
    end

    def mutate(outcome, options = {})
      if outcome.success?
        render options.merge(json: outcome.result)
      else
        render options.merge(json: outcome.errors.message, status: 422)
      end
    end

    def default_serializer_options
      {root: false, user: current_user}
    end
  end
end
