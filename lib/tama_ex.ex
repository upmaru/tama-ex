defmodule TamaEx do
  @moduledoc """
  Documentation for `Tama`.
  """

  @doc """
  Creates a new HTTP client with the given base URL.

  ## Examples

      iex> TamaEx.client(base_url: "https://api.example.com")
      %Req.Request{}

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

      iex> TamaEx.handle_response({:ok, %Req.Response{status: 200, body: %{"data" => %{}}}}, TamaEx.Neural.Space)
      {:ok, %TamaEx.Neural.Space{}}

      iex> TamaEx.handle_response({:ok, %Req.Response{status: 404}}, TamaEx.Neural.Space)
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
end
