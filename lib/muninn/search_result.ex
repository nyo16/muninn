defmodule Muninn.SearchResult do
  @moduledoc """
  Represents the results of a search query.
  """

  @type t :: %__MODULE__{
          total_hits: non_neg_integer(),
          hits: [Muninn.SearchHit.t()]
        }

  defstruct [:total_hits, :hits]
end

defmodule Muninn.SearchHit do
  @moduledoc """
  Represents a single search result hit.
  """

  @type t :: %__MODULE__{
          score: float(),
          doc: map()
        }

  defstruct [:score, :doc]
end
