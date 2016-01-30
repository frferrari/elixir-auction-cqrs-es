defmodule Andycot.Model.UserEvent do 
	use Ecto.Model
	import Ecto.Query
	import Andycot.Tools.Timestamp

	@closed_by_system :system
	@suspended_by_sytem @closed_by_system
	@renewed_by_sytem @closed_by_system
	@resumed_by_sytem @closed_by_system

	@primary_key {:id, :binary_id, autogenerate: true}
	schema "user_events" do
		field :event_type, :string
		field :user_id, :integer
		field :event_data, :map
		field :created_at, :integer
	end

	@doc """
	Generates and returns an UserEvent event with the given date/time as timestamp.
	Used during the replay phase to keep the created_at field value.
	"""
	def make_event(event_type, event_data, :replay) do
		created_at = event_data |> Map.get(:created_at)
		data = event_data |> Map.delete(:created_at)

		%__MODULE__{event_type: Atom.to_string(event_type),
								user_id: event_data.user_id,
								created_at: created_at,
								event_data: data}
	end

	@doc """
	Generates and returns an UserEvent event with the given date/time as timestamp.
	Used during the migration phase to keep the created_at field value.
	"""
	def make_event(event_type, event_data, :legacy) do
		created_at = event_data |> Map.get(:created_at)
		data = event_data |> Map.delete(:created_at)

		%__MODULE__{event_type: Atom.to_string(event_type),
								user_id: event_data.user_id,
								created_at: created_at,
								event_data: data}
	end

	@doc """
	Generates and returns an UserEvent event with the given date/time as timestamp.
	Used in `:standard` mode
	"""
	def make_event(event_type, event_data, :standard) do
		%__MODULE__{event_type: Atom.to_string(event_type), 
								user_id: event_data.user_id, 
								created_at: now(),
								event_data: event_data}
	end

	@doc """
	"""
	def get_closed_by_system do
		@closed_by_system
	end

	@doc """
	"""
	def get_suspended_by_system do
		@suspended_by_system
	end

	@doc """
	"""
	def get_renewed_by_system do
		@renewed_by_system
	end

	@doc """
	"""
	def get_resumed_by_system do
		@resumed_by_system
	end

end
