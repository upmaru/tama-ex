ExUnit.start()

# Add Jason and Bypass for testing
Application.ensure_all_started(:bypass)
Application.ensure_all_started(:jason)

defmodule TestHelpers do
  @doc """
  Creates a mock client for testing without authentication.
  This is used for testing validation logic and other non-authenticated functionality.
  """
  def mock_client(namespace, base_url \\ "https://api.example.com") do
    base_client =
      Req.new(
        base_url: base_url,
        headers: [{"authorization", "Bearer mock_token"}]
      )

    TamaEx.put_namespace(base_client, namespace)
  end

  @doc """
  Creates an authenticated client for integration testing with Bypass.
  """
  def authenticated_client(base_url, client_id \\ "test_client", client_secret \\ "test_secret") do
    bypass = Bypass.open()
    bypass_url = "http://localhost:#{bypass.port}"

    token_response = %{
      access_token: "test_access_token",
      token_type: "Bearer",
      scope: "provision.all",
      expires_in: 3600
    }

    Bypass.expect_once(bypass, "POST", "/auth/tokens", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(token_response))
    end)

    case TamaEx.client(base_url || bypass_url, client_id, client_secret) do
      {:ok, %{client: client}} -> {client, bypass}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Sets up a bypass server with authentication endpoint for testing.
  Returns {bypass, base_url}
  """
  def setup_bypass_with_auth do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    token_response = %{
      access_token: "bypass_test_token",
      token_type: "Bearer",
      scope: "provision.all",
      expires_in: 3600
    }

    Bypass.stub(bypass, "POST", "/auth/tokens", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(token_response))
    end)

    {bypass, base_url}
  end
end
