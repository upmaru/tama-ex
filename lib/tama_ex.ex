defmodule TamaEx do
  @moduledoc """
  Documentation for `Tama`.
  """

  @doc """
  Creates a new HTTP client with the given base URL.

  ## Examples

      iex> client = TamaEx.client(base_url: "https://api.example.com")
      iex> client.options[:base_url]
      "https://api.example.com"

  """
  def client(base_url: base_url) do
    Req.new(base_url: base_url)
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

      iex> client = TamaEx.client(base_url: "https://api.example.com/provision")
      iex> {:ok, validated_client} = TamaEx.validate_client(client, ["provision"])
      iex> validated_client == client
      true

      iex> client = TamaEx.client(base_url: "https://api.example.com/ingest")
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
