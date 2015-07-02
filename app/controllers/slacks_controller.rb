class SlacksController < ApplicationController

	def respond
		command = params[:text].split[0]
		body = params[:text].split[1]
		user = params[:user_name]
		message = ''

		case command.downcase
		when 'whats_on'
			unacceptedchallenges = Challenge.where(:status=>0)
			activematches = Challenge.where(:status=>1)
			unacceptedchallenges.each do |challenge|
				message = message + ":speech_balloon: Waiting on #{Player.find(challenge.to_id).name} to accept #{Player.find(challenge.from_id).name}'s challenge
"
			end
			activematches.each do |match|
				message = message + ":pingpong: Waiting on #{Player.find(match.to_id).name} and #{Player.find(match.from_id).name}'s match to finish
"
			end
			if message == ''
				message = "Meow ma mia! :pizza: Nothing's on, maybe you should start something! :dizzy:"
			end
		when 'add_me'
			max_rank = Player.maximum('rank') || 0
			if Player.exists?(:name => params[:user_name])
				message = "You're already on the ladder foo'!"
			else
				Player.create(:name => params[:user_name], :status=> 1, :rank=> max_rank+1)
				message = "Player #{params[:user_name]} added with rank #{max_rank+1}"
			end
		when 'kill_me'
			player = Player.find_by(:name => params[:user_name])
			player.destroy if !player.blank?
			message = "I killed #{params[:user_name]}, muahahahaha :knife: :syringe:" if !player.blank?
			message = "Couldn't find player" if player.blank?
			self.rerank(nil)
		when 'im_afk'
			player = Player.find_by(:name => params[:user_name])
			if player.status == 1
				current_rank = player.rank
				deactivate(player)
				message = "Meow ma mia! :pizza: You are inactive.  Use im_back to challenge at rank #{current_rank} to come back."
			else
				message = "Gnocchi! :pizza: You must finish all challenges or matches before you can leave! Use decline or i_lost!"
			end
		when 'ranking'
			players  = Player.where('status != -1 AND rank > 0').order('rank')
			message = ''
			players.each_with_index do |player, index|
				extra_thing = ':mushroom:'
				if(player.rank < 4)
					extra_thing = ':trophy:'
				end

				message = message + "#{player.rank}. #{player.name}#{extra_thing}
"
			end
		when 'challenge'
			from_username = params[:user_name].gsub(/@/, '')
			from_user = Player.find_by(:name => from_username)
			to_user = Player.find_by(:name => body)

			if from_user.blank?
				message = "Gnocchi! :pizza: You are not a ping pong player"
			elsif to_user.blank?
				message = "Gnocchi! :pizza: #{body} is not a ping pong player"
			elsif from_user.status == 0
				message = "Gnocchi! :pizza: You cannot challenge because you are already in a challenge or match"
			elsif from_user.status == -1
				message = "Gnocchi! :pizza: You cannot challenge because you are inactive, type im_back to get back on the ranking first"
			elsif to_user.status == 0
				message = "Gnocchi! :pizza: #{to_user.name} is already in a challenge or match"
			elsif to_user.status == -1
				message = "Gnocchi! :pizza: #{to_user.name} is not active right now.  They are OOO or injured, take it easy."
			elsif ([to_user.rank, from_user.rank].max - [to_user.rank, from_user.rank].min) > 2
				message = "Gnocchi! :pizza: Challenge not valid, ranking difference is more than 2"
			elsif from_user.status == 1 && to_user.status ==1
				challenge = Challenge.create(:from_id => from_user.id, :to_id=>to_user.id, :status=> 0)
				from_user.update(:status=>0)
				to_user.update(:status=>0)
				message = "Challenge to #{to_user.name} issued. @#{to_user.name}, you are challenged by @#{from_username}"
			end

		when 'accept'
			user = Player.find_by(:name => params[:user_name])
			if user.blank?
				message = "Meow-ma mia :pizza: You are not a ping pong player"
			else
				challenge = Challenge.where(:to_id => user.id, :status=>0).first
				if challenge
					from_user = Player.find(challenge.from_id)
					challenge.update(:status=>1)
					message = "Challenge from @#{from_user.name} accepted, go play :pizza:"
				else
					message = "Meow-ma mia :pizza: No active challenges to you found"
				end
			end

		when 'decline'
			user = Player.find_by(:name => params[:user_name])
			if user.blank?
				message = "Gnocchi! :pizza: You are not a ping pong player"
			else
				challenge = Challenge.where(:to_id => user.id, :status=>0).first
				if challenge
					from_user = Player.find(challenge.from_id)
					to_user = Player.find(challenge.to_id)
					last_rank = to_user.rank
					challenge.update(:status=>-1)
					from_user.update(:status=>1)
					deactivate(to_user)
					message = "Meow-ma mia :pizza: Challenge from @#{from_user.name} declined, you are now off the ranking.  You must challenge at #{last_rank} to get back.  Type im_back when you're ready"
				else
					message = "Meow-ma mia :pizza: No active challenges to you found"
				end
			end

		when 'i_won', 'i_lost'
			user = Player.find_by(:name => params[:user_name])
			challenge = Challenge.where("(to_id = ? OR from_id = ?) AND status = 1", user.id, user.id).first
			array_of_players = buildArrayOfPlayers

			if challenge
				if command == 'i_won'
					winning_user = Player.find_by(:name => params[:user_name])
					if winning_user.id == challenge.from_id
						losing_user = Player.find(challenge.to_id)
					else
						losing_user = Player.find(challenge.from_id)
					end
				end

				if command == 'i_lost'
					losing_user = Player.find_by(:name => params[:user_name])
					if losing_user.id == challenge.from_id
						winning_user = Player.find(challenge.to_id)
					else
						winning_user = Player.find(challenge.from_id)
					end
				end

				from_an_inactive_user = (Player.find(challenge.from_id).rank == 0)
				winning_user_is_inactive = (winning_user.id == challenge.from_id)
				losing_user_is_inactive = (losing_user.id == challenge.from_id)
				winning_user_rank_is_lower = (winning_user.rank > losing_user.rank)

				if from_an_inactive_user
					if winning_user_is_inactive
						array_of_players.insert(losing_user.rank-1, winning_user.id)
					elsif losing_user_is_inactive
						array_of_players.insert(winning_user.rank, losing_user.id)
					end
				else
					if winning_user_rank_is_lower
						array_of_players.delete(winning_user.id)
						array_of_players.insert(losing_user.rank-1, winning_user.id)
					end
				end
				rerank(array_of_players)
				winning_user.update(:status => 1)
				losing_user.update(:status => 1)
				challenge.update(:status => -1)

				message = "Match complete. @#{winning_user.name} won, ranking #{Player.find(winning_user.id).rank}. @#{losing_user.name} lost, ranking #{Player.find(losing_user.id).rank}"
			else
				message = 'Gnocchi! :pizza: You are not in an active match right now.  Either accept one, or challenge someone! '
			end

		when 'im_back'
			user = Player.find_by(:name => params[:user_name])
			if user.status != -1
				message = "Gnocchi! :pizza: What are you talking about? You were never away! :anger:"
			else
				player_to_challenge = Player.find_by(:rank=>user.last_rank)
				if player_to_challenge.status != 1
					message = "Meow-ma mia :pizza: You need to challenge #{player_to_challenge.name} to get your rank back, but they are already challenged or playing.  Try again later! :sweat_drops:"
				else
					Challenge.create(:to_id=>player_to_challenge.id, :from_id=>user.id, :status => 0)
					message = "Challenge sent to @#{player_to_challenge.name} for rank #{player_to_challenge.rank}.  Good luck! :four_leaf_clover: :pizza:"
				end
			end
		when 'meow'
			message = "http://lorempixel.com/400/400/cats/"
		when 'meow2'
			message = 'http://imashon.com/wp-content/uploads/2014/12/Meow-Cute-Cat.jpg'
		when 'help'
			message = "Available commands: :collision:\n
						*add_me* - adds you to the ladder\n
						*kill_me* - removes you from the ladder\n
						*im_afk* - removes you from the ladder temporarily\n
						*im_back* - brings you back from being off the ladder, and automatically issues a challenge to whoever is in your spot\n
						*ranking* - shows you the ladder\n
						*challenge [name] ex: 'challenge ryo'- issues a challenge\n
						*accept* - accept a challenge\n
						*decline* - decline a challenge, you will be taken off the ladder and you have to say 'im_back'\n
						*i_won* - declares victory\n
						*i_lost* - declares your epic failure\n
						*whats_on* - shows all open challenges and matches\n
			"
		else
			message = ''
		end

		if user == 'slackbot'
			message = ''
		end

		render :json => {:text=>message, :mrkdwn => true}, :status=>201
	end


	def deactivate(player)
		player.update(:status => -1, :last_rank=>player.rank, :rank=>0) if !player.blank?
		self.rerank(nil)
	end

	def rerank(player_array)
		if player_array
			i = 1
			player_array.each do |player|
				Player.find(player).update(:rank=>i)
				i = i + 1
			end
		else
			players = Player.where('status != -1 AND rank > 0').order('rank')
			i = 1
			players.each do |player|
				player.update(:rank=>i)
				i = i + 1
			end
		end
	end

	def buildArrayOfPlayers
		players = Player.where('status != -1 AND rank > 0').order('rank')
		player_array = []
		players.each do |player|
			player_array << player.id
		end
		return player_array
	end


end
