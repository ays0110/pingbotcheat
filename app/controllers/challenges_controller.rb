class ChallengesController < ApplicationController

	def reset
		old_challenges = Challenge.where('status != -1')
		old_challenges.update_all(:status=>-1)
		players = Player.where('status = 0')
		players.update_all(:status=>1)
		render :json => {:text=>'Challenges and games reset'}, :status=>201
	end

end
