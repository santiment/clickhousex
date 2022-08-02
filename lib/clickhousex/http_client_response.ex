defmodule Clickhousex.HTTPClient.Response do
  defstruct ref: nil, codec_state: nil, status: nil, error_buffer: [], resp_headers: [], complete?: false

  @codec Application.compile_env(:clickhousex, :codec, Clickhousex.Codec.JSON)
  def new(ref) do
    codec_state = @codec.new()

    %__MODULE__{ref: ref, codec_state: codec_state}
  end

  def append_messages(%__MODULE__{} = response, messages) do
    Enum.reduce(messages, response, &append(&2, &1))
  end

  def decode(%__MODULE__{status: status, error_buffer: error_buffer}) when status != 200 do
    {:error, IO.iodata_to_binary(error_buffer)}
  end

  def decode(%__MODULE__{codec_state: state, complete?: true}) do
    @codec.decode(state)
  end

  def format do
    @codec.response_format
  end

  defp append(
         %__MODULE__{status: status, ref: ref, error_buffer: error_buffer} = response,
         {:data, ref, data}
       )
       when status != 200 do
    %{response | error_buffer: [error_buffer, data]}
  end

  defp append(%__MODULE__{codec_state: _state, ref: ref} = response, {:headers, ref, headers}) do
    %{
      response | resp_headers: headers ++ response.resp_headers
    }
  end

  defp append(%__MODULE__{codec_state: state, ref: ref} = response, {:data, ref, data}) do
    %{response | codec_state: @codec.append(state, data)}
  end

  defp append(%__MODULE__{ref: ref} = response, {:status, ref, status_code}) do
    %{response | status: status_code}
  end

  defp append(%__MODULE__{ref: ref} = response, {:headers, ref, _headers}) do
    response
  end

  defp append(%__MODULE__{ref: ref} = response, {:done, ref}) do
    %{response | complete?: true}
  end
end
