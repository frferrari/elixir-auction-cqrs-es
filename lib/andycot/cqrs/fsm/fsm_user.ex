defmodule Fsm.User do 
	@moduledoc """
	"""
	use Fsm, initial_state: :idle, initial_data: %Fsm.User.Data{}
	alias Andycot.Repo
	alias Andycot.Service.UserEmailRegistry
	import Andycot.Tools.Timestamp

	require Logger

	# 	
	# 	  ###   ######  #       #######
	# 	   #    #     # #       #
	# 	   #    #     # #       #
	# 	   #    #     # #       #####
	# 	   #    #     # #       #
	# 	   #    #     # #       #
	# 	  ###   ######  ####### #######
	# 	
	defstate idle do

		#
		defevent user_registered(event, mode) do

			tmp_fsm_data = struct(Fsm.User.Data, Map.from_struct(event)) 
			# Initialize the list of watched auctions
			new_fsm_data = put_in(tmp_fsm_data.watched_auctions, MapSet.new)

			event
			|> Repo.persist_event(mode, new_fsm_data)

			if mode == :replay, do: UserEmailRegistry.add(event.email, event.user_id)

			next_state(:awaiting_activation, new_fsm_data)
		end

		#
		defevent _, state: state do
			next_state(state)
		end

	end

	# 	
	# 	   #    #     #    #      ###   #######   ###   #     #  #####
	# 	  # #   #  #  #   # #      #       #       #    ##    # #     #
	# 	 #   #  #  #  #  #   #     #       #       #    # #   # #
	# 	#     # #  #  # #     #    #       #       #    #  #  # #  ####
	# 	####### #  #  # #######    #       #       #    #   # # #     #
	# 	#     # #  #  # #     #    #       #       #    #    ## #     #
	# 	#     #  ## ##  #     #   ###      #      ###   #     #  #####
	# 	
	defstate awaiting_activation do

		# A user has activated its account
		defevent account_activated(event, mode), data: fsm_data do

			new_fsm_data = %Fsm.User.Data{fsm_data | activated_at: event.activated_at}

			event
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(:active, new_fsm_data)

		end

		#
		defevent _, state: state do
			next_state(state)
		end

	end

	# 	
	# 	   #     #####  #######   ###   #     # #######
	# 	  # #   #     #    #       #    #     # #
	# 	 #   #  #          #       #    #     # #
	# 	#     # #          #       #    #     # #####
	# 	####### #          #       #     #   #  #
	# 	#     # #     #    #       #      # #   #
	# 	#     #  #####     #      ###      #    #######
	# 	
	defstate active do

		#
		defevent user_unregistered(event, mode), data: fsm_data do

			new_fsm_data = %Fsm.User.Data{fsm_data | unregistered_at: event.unregistered_at}

			event
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(:unregistered, new_fsm_data)

		end

		# Lock a user account
		defevent account_locked(event, mode), data: fsm_data do

			new_fsm_data = %Fsm.User.Data{fsm_data | locked_at: event.locked_at}

			event
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(:locked, new_fsm_data)

		end

		# A user adds an auction to its list of favorites
		defevent auction_watched(event, mode), state: state, data: fsm_data do

			new_fsm_data = %Fsm.User.Data{fsm_data | watched_auctions: MapSet.put(fsm_data.watched_auctions, event.auction_id)}

			event
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(state, new_fsm_data)

		end

		# A auction watch was rejected
		defevent watch_rejected(event, mode), state: state, data: fsm_data do

			event 
			|> Repo.persist_event(mode, fsm_data)

			next_state(state, fsm_data)

		end

		# A user removes an auction from its list of favorites
		defevent auction_unwatched(event, mode), state: state, data: fsm_data do
			new_fsm_data = %Fsm.User.Data{fsm_data | watched_auctions: MapSet.delete(fsm_data.watched_auctions, event.auction_id)}

			event
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(state, new_fsm_data)			
		end

		#
		defevent password_changed(new_password), data: fsm_data do
			# TODO
			# TODO
			# next_state(:active, %Fsm.User.Data{user_data | password: new_password})
			# TODO
			# TODO
		end

		#
		defevent _, state: state do
			next_state(state)
		end

	end

	# 	
	# 	#     # #     # ######  #######  #####    ###    #####  ####### ####### ######  ####### ######
	# 	#     # ##    # #     # #       #     #    #    #     #    #    #       #     # #       #     #
	# 	#     # # #   # #     # #       #          #    #          #    #       #     # #       #     #
	# 	#     # #  #  # ######  #####   #  ####    #     #####     #    #####   ######  #####   #     #
	# 	#     # #   # # #   #   #       #     #    #          #    #    #       #   #   #       #     #
	# 	#     # #    ## #    #  #       #     #    #    #     #    #    #       #    #  #       #     #
	# 	 #####  #     # #     # #######  #####    ###    #####     #    ####### #     # ####### ######
	# 	

	defstate unregistered do

		defevent _, state: state do
			next_state(state)
		end

	end

	# 	
	# 	#       #######  #####  #    #  ####### ######
	# 	#       #     # #     # #   #   #       #     #
	# 	#       #     # #       #  #    #       #     #
	# 	#       #     # #       ###     #####   #     #
	# 	#       #     # #       #  #    #       #     #
	# 	#       #     # #     # #   #   #       #     #
	# 	####### #######  #####  #    #  ####### ######
	# 	
	defstate locked do

		#
		defevent account_unlocked(event, mode), data: fsm_data do

			new_fsm_data = %Fsm.User.Data{fsm_data | locked_at: nil, activated_at: event.unlocked_at}

			event
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(:active, new_fsm_data)

		end

		#
		defevent user_unregistered(event, mode), data: fsm_data do

			new_fsm_data = %Fsm.User.Data{fsm_data | unregistered_at: event.unregistered_at}

			event
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(:unregistered, new_fsm_data)

		end

		#
		defevent _, state: state do
			next_state(state)
		end
	end

end
