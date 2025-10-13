defmodule TamaEx do
  @moduledoc """
  Documentation for `TamaEx`.
  """

  @doc """
  Creates a new HTTP client with authentication.

  This function performs OAuth2 client credentials authentication and returns
  an authenticated HTTP client. The base_url should be the root URL of the API server.

  ## Parameters
    - base_url - The root base URL for the API server (e.g., "https://api.example.com")
    - client_id - The OAuth2 client ID
    - client_secret - The OAuth2 client secret
    - options - Optional configuration (e.g., scopes)

  ## Returns
    - `{:ok, %{client: client, expires_in: seconds}}` on successful authentication
    - `{:error, reason}` on authentication failure

  ## Examples

      # Create client with root URL
      {:ok, %{client: client}} = TamaEx.client("https://api.example.com", "client_id", "client_secret")

      # Add namespace for specific operations
      namespaced_client = TamaEx.put_namespace(client, "provision")

  """
  def client(
        base_url,
        client_id,
        client_secret,
        options \\ []
      ) do
    scopes = Keyword.get(options, :scopes) || ["provision.all"]

    token = Base.url_encode64("#{client_id}:#{client_secret}", padding: false)

    body = %{
      "grant_type" => "client_credentials",
      "scope" => Enum.join(scopes, " ")
    }

    case Req.new(
           base_url: base_url,
           headers: [{"authorization", "Bearer #{token}"}]
         )
         |> Req.post(url: "/auth/tokens", json: body) do
      {:ok, %Req.Response{status: 200, body: token}} ->
        headers = [{"authorization", "Bearer #{token["access_token"]}"}]

        {:ok,
         %{client: Req.new(base_url: base_url, headers: headers), expires_in: token["expires_in"]}}

      {:ok, %Req.Response{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Adds a namespace to the client's base URL.

  ## Parameters
    - client - The HTTP client
    - namespace - The namespace to append (e.g., "provision", "ingest")

  ## Returns
    - Updated client with namespaced base URL

  ## Examples

      iex> client = Req.new(base_url: "https://api.example.com")
      iex> namespaced_client = TamaEx.put_namespace(client, "provision")
      iex> namespaced_client.options[:base_url]
      "https://api.example.com/provision"

  """
  def put_namespace(%Req.Request{} = client, namespace) when is_binary(namespace) do
    current_base_url = client.options[:base_url] || ""
    new_base_url = "#{current_base_url}/#{namespace}"

    Req.merge(client, base_url: new_base_url)
  end

  @doc """
  Handles API response and parses data using the provided schema module.

  ## Parameters
    - response - The response from Req.get/post/etc
    - schema_module - The module to use for parsing (e.g., TamaEx.Neural.Space)

  ## Examples

      iex> defmodule DocSchema do
      ...>   def parse(data), do: %{parsed: data}
      ...> end
      iex> TamaEx.handle_response({:ok, %Req.Response{status: 200, body: %{"data" => %{"id" => "123"}}}}, DocSchema)
      {:ok, %{parsed: %{"id" => "123"}}}

      iex> TamaEx.handle_response({:ok, %Req.Response{status: 404}}, DocSchema)
      {:error, :not_found}

  """
  def handle_response(response, schema_module) do
    case response do
      {:ok, %Req.Response{status: 200, body: %{"data" => data}}} ->
        {:ok, schema_module.parse(data)}

      {:ok, %Req.Response{status: 201, body: %{"data" => data}}} ->
        {:ok, schema_module.parse(data)}

      {:ok, %Req.Response{status: 404}} ->
        {:error, :not_found}

      {:ok, %Req.Response{status: 422, body: %{"errors" => errors}}} ->
        {:error, {:validation_error, errors}}

      {:ok, %Req.Response{status: status, body: body}} when status >= 400 ->
        {:error, {:http_error, status, body}}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Validates that the client's base URL namespace is valid for the operation.

  ## Parameters
    - client - The HTTP client with base_url
    - valid_namespaces - List of valid namespace strings

  ## Examples

      iex> client = %Req.Request{options: %{base_url: "https://api.example.com/provision"}}
      iex> {:ok, validated_client} = TamaEx.validate_client(client, ["provision"])
      iex> validated_client == client
      true

      iex> client = %Req.Request{options: %{base_url: "https://api.example.com/ingest"}}
      iex> try do
      ...>   TamaEx.validate_client(client, ["provision"])
      ...> rescue
      ...>   ArgumentError -> :error_raised
      ...> end
      :error_raised

  """
  def validate_client(%Req.Request{} = client, valid_namespaces) when is_list(valid_namespaces) do
    case extract_namespace_from_client(client) do
      {:ok, namespace} ->
        if namespace in valid_namespaces do
          {:ok, client}
        else
          raise ArgumentError, """
          Invalid client namespace. Expected one of #{inspect(valid_namespaces)}, got '#{namespace}'.

          The client's base_url is configured for '#{namespace}' operations, but this function requires #{inspect(valid_namespaces)}.
          Please use a client configured with the correct base_url namespace.
          """
        end

      {:error, reason} ->
        raise ArgumentError, "Failed to extract namespace from client: #{reason}"
    end
  end

  defp extract_namespace_from_client(%Req.Request{options: options}) do
    case Map.get(options, :base_url) do
      nil ->
        {:error, "No base_url configured"}

      base_url when is_binary(base_url) ->
        uri = URI.parse(base_url)

        case String.split(uri.path || "", "/", trim: true) do
          [] ->
            {:error, "No namespace found in base_url path"}

          segments ->
            namespace = List.last(segments)
            {:ok, namespace}
        end

      _ ->
        {:error, "Invalid base_url format"}
    end
  end
end
