defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  # Add logging for debugging and monitoring
  require Logger

  # Add action fallback for handling common error cases
  action_fallback MyAppWeb.FallbackController

  @doc """
  Renders the homepage.
  """
  def index(conn, _params) do
    try do
      # You might want to fetch some data for the homepage
      page_data = %{
        title: "Welcome to MyApp",
        features: [
          "Feature 1",
          "Feature 2",
          "Feature 3"
        ]
      }

      conn
      |> put_status(:ok)
      |> put_resp_header("cache-control", "public, max-age=3600")
      |> render(:index, page_data: page_data)
    rescue
      e ->
        Logger.error("Error rendering homepage: #{inspect(e)}")
        conn
        |> put_status(:internal_server_error)
        |> put_view(MyAppWeb.ErrorView)
        |> render("500.html")
    end
  end

  @doc """
  Health check endpoint for monitoring.
  """
  def health_check(conn, _params) do
    conn
    |> put_status(:ok)
    |> json(%{status: "ok", timestamp: DateTime.utc_now()})
  end

  # Private helper functions
  defp handle_error(conn, error) do
    Logger.error("Controller error: #{inspect(error)}")

    conn
    |> put_status(:internal_server_error)
    |> put_view(MyAppWeb.ErrorView)
    |> render("500.html")
  end
end
