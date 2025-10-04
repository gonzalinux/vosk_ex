defmodule VoskExTest do
  use ExUnit.Case
  doctest VoskEx

  test "NIF loads without errors" do
    # Verify the NIF module loaded successfully
    assert Code.ensure_loaded?(VoskEx)
    assert function_exported?(VoskEx, :set_log_level, 1)
  end
end
