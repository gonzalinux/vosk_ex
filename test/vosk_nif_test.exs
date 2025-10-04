defmodule VoskNifTest do
  use ExUnit.Case
  doctest VoskNif

  test "NIF loads without errors" do
    # Verify the NIF module loaded successfully
    assert Code.ensure_loaded?(VoskNif)
    assert function_exported?(VoskNif, :set_log_level, 1)
  end
end
