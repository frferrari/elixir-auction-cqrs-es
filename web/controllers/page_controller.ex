defmodule Andycot.PageController do
  use Andycot.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
