class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session 

  def ranking
	@players  = Player.where('status != -1 AND rank > 0').order('rank')
	render json: { success: true, players: @players }, status: 201
  end

end
