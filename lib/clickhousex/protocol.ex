defmodule Clickhousex.Protocol do
  @moduledoc false

  use DBConnection

  alias Clickhousex.HTTPClient, as: Client
  alias Clickhousex.Error

  defstruct conn_opts: [], base_address: "", conn: nil

  @type state :: %__MODULE__{
          conn_opts: Keyword.t(),
          base_address: String.t(),
          conn: Mint.HTTP.t()
        }

  @type query :: Clickhousex.Query.t()
  @type result :: Clickhousex.Result.t()
  @type cursor :: any
  @type post_date :: any
  @type query_string_data :: any

  @ping_query Clickhousex.Query.new("SELECT 1") |> DBConnection.Query.parse([])
  @ping_params DBConnection.Query.encode(@ping_query, [], [])

  @doc false
  @spec connect(opts :: Keyword.t()) ::
          {:ok, state}
          | {:error, Exception.t()}
  def connect(opts) do
    scheme = opts[:scheme] || :http
    hostname = opts[:hostname] || "localhost"
    port = opts[:port] || 8123
    database = opts[:database] || "default"
    username = opts[:username] || nil
    password = opts[:password] || nil
    timeout = opts[:timeout] || Clickhousex.timeout()

    {:ok, conn} = Client.connect(scheme, hostname, port)

    case Client.request(conn, @ping_query, @ping_params, timeout, username, password, database) do
      {:ok, conn, {:selected, _, _}} ->
        {
          :ok,
          %__MODULE__{
            conn: conn,
            conn_opts: [
              scheme: scheme,
              hostname: hostname,
              port: port,
              database: database,
              username: username,
              password: password,
              timeout: timeout
            ]
          }
        }

      resp ->
        resp
    end
  end

  @doc false
  @spec disconnect(err :: Exception.t(), state) :: :ok
  def disconnect(_err, _state) do
    :ok
  end

  @doc false
  @spec ping(state) :: {:ok, state} | {:disconnect, Exception.t(), state}
  def ping(state) do
    case do_query(state.conn, @ping_query, @ping_params, [], state) do
      {:ok, _, _, new_state} -> {:ok, new_state}
      {:error, reason, new_state} -> {:disconnect, reason, new_state}
      other -> other
    end
  end

  @doc false
  @spec reconnect(new_opts :: Keyword.t(), state) :: {:ok, state}
  def reconnect(new_opts, state) do
    with :ok <- disconnect(Error.exception("Reconnecting"), state) do
      connect(new_opts)
    end
  end

  @doc false
  @spec checkin(state) :: {:ok, state}
  def checkin(state) do
    {:ok, state}
  end

  @doc false
  @spec checkout(state) :: {:ok, state}
  def checkout(state) do
    {:ok, state}
  end

  @doc false
  def handle_status(_, state) do
    {:idle, state}
  end

  @doc false
  @spec handle_prepare(query, Keyword.t(), state) :: {:ok, query, state}
  def handle_prepare(query, _, state) do
    {:ok, query, state}
  end

  @doc false
  @spec handle_execute(
          query,
          %{post_data: post_date, query_string_data: query_string_data},
          opts :: Keyword.t(),
          state
        ) ::
          {:ok, query, result, state}
          | {:error | :disconnect, Exception.t(), state}
  def handle_execute(query, params, opts, state) do
    do_query(state.conn, query, params, opts, state)
  end

  defp do_query(conn, query, params, _opts, state) do
    username = state.conn_opts[:username]
    password = state.conn_opts[:password]
    timeout = state.conn_opts[:timeout]
    database = state.conn_opts[:database]

    res =
      conn
      |> Client.request(query, params, timeout, username, password, database)
      |> handle_errors()

    case res do
      {:error, conn, %Error{code: :connection_exception} = reason} ->
        {:disconnect, reason, %{state | conn: conn}}

      {:error, conn, reason} ->
        {:error, reason, %{state | conn: conn}}

      {:ok, conn, {:selected, columns, rows}} ->
        {
          :ok,
          query,
          %Clickhousex.Result{
            command: :selected,
            columns: columns,
            rows: rows,
            num_rows: Enum.count(rows)
          },
          %{state | conn: conn}
        }

      {:ok, conn, {:updated, count}} ->
        {
          :ok,
          query,
          %Clickhousex.Result{
            command: :updated,
            columns: ["count"],
            rows: [[count]],
            num_rows: 1
          },
          %{state | conn: conn}
        }
    end
  end

  @doc false
  def handle_declare(_query, _params, _opts, state) do
    msg = "cursors_not_supported"
    {:error, Error.exception(msg), state}
  end

  @doc false
  def handle_deallocate(_query, _cursor, _opts, state) do
    msg = "cursors_not_supported"
    {:error, Error.exception(msg), state}
  end

  def handle_fetch(_query, _cursor, _opts, state) do
    msg = "cursors_not_supported"
    {:error, Error.exception(msg), state}
  end

  @doc false
  defp handle_errors({:error, conn, reason}) do
    {:error, conn, Error.exception(reason)}
  end

  defp handle_errors(term), do: term

  @doc false
  @spec handle_begin(opts :: Keyword.t(), state) :: {:ok, result, state}
  def handle_begin(_opts, state) do
    {:ok, %Clickhousex.Result{}, state}
  end

  @doc false
  @spec handle_close(query, Keyword.t(), state) :: {:ok, result, state}
  def handle_close(_query, _opts, state) do
    {:ok, %Clickhousex.Result{}, state}
  end

  @doc false
  @spec handle_commit(opts :: Keyword.t(), state) :: {:ok, result, state}
  def handle_commit(_opts, state) do
    {:ok, %Clickhousex.Result{}, state}
  end

  @doc false
  @spec handle_info(opts :: Keyword.t(), state) :: {:ok, state}
  def handle_info(_msg, state) do
    {:ok, state}
  end

  @doc false
  @spec handle_rollback(opts :: Keyword.t(), state) :: {:ok, result, state}
  def handle_rollback(_opts, state) do
    {:ok, %Clickhousex.Result{}, state}
  end
end
