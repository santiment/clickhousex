defmodule Clickhousex.HTTPClient.Mint do

  alias Clickhousex.HTTPClient.Response
  alias Clickhousex.Query
  @moduledoc false

  @req_headers [{"Content-Type", "text/plain"}]

  def connect(scheme, host, port) do
    Mint.HTTP.connect(scheme, host, port, mode: :passive)
  end

  def disconnect(conn) do
    Mint.HTTP.close(conn)
  end

  def request(conn, query, request, timeout, nil, _password, database) do
    post(conn, query, request, database, timeout: timeout, recv_timeout: timeout)
  end

  def request(conn, query, request, timeout, username, password, database) do
    opts = [auth_params: {username, password}, timeout: timeout, recv_timeout: timeout]
    post(conn, query, request, database, opts)
  end

  defp post(conn, query, request, database, opts) do
    {recv_timeout, opts} = Keyword.pop(opts, :recv_timeout, 5000)

    query_opts = %{
      database: database,
      query: IO.iodata_to_binary(request.query_string_data)
    }

    query_opts =
      case Keyword.get(opts, :auth_params) do
        nil ->
          query_opts

        {username, password} ->
          %{user: username, password: password} |> Map.merge(query_opts)
      end

    query_string = URI.encode_query(query_opts)

    path = "/?#{query_string}"
    post_body = maybe_append_format(query, request)
    headers = headers(opts, post_body)

    with {:ok, conn, ref} <- Mint.HTTP.request(conn, "POST", path, headers, post_body),
         {:ok, conn, %Response{} = response} <-
           receive_response(conn, recv_timeout, Response.new(ref)) do
      decode_response(conn, query, response)
    else
      {:error, conn, error, _messages} ->
        {:error, conn, error}
    end
  end

  defp decode_response(conn, %Query{type: :select}, %Response{} = response) do
    case Response.decode(response) do
      {:ok, %{column_names: column_names, column_types: column_types, rows: rows}} ->
        {:ok, conn, {:selected, column_names, column_types, rows, response.resp_headers}}
      {:error, error} -> {:error, conn, error.reason}
    end
  end

  defp decode_response(conn, %Query{}, response) do
    case Response.decode(response) do
      {:error, reason} -> {:error, conn, reason}
      _ -> {:ok, conn, {:updated, 1}}
    end
  end

  defp headers(_opts, post_iodata) do
    content_length = post_iodata |> IO.iodata_length() |> Integer.to_string()
    [{"content-length", content_length} | @req_headers]
  end

  defp receive_response(conn, _recv_timeout, %Response{complete?: true} = response) do
    {:ok, conn, response}
  end

  defp receive_response(conn, recv_timeout, response) do
    case Mint.HTTP.recv(conn, 0, recv_timeout) do
      {:ok, conn, messages} ->
        response = Response.append_messages(response, messages)
        receive_response(conn, recv_timeout, response)

      {:error, conn, err, messages} ->
        response = Response.append_messages(response, messages)
        {:error, conn, err, response}
    end
  end

  defp maybe_append_format(%Query{type: :select}, request) do
    [request.post_data, " FORMAT ", Response.format()]
  end

  defp maybe_append_format(_, request) do
    [request.post_data]
  end
end
