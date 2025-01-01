defmodule TaskOptimizer do
  @moduledoc """
  Provides functionality for optimizing and managing tasks based on various criteria.
  """

  @typedoc """
  Represents a task with required and optional fields.
  """
  @type task :: %{
    required(:name) => String.t(),
    required(:priority) => integer(),
    optional(:deadline) => DateTime.t(),
    optional(:duration) => integer(),
    optional(:dependencies) => list(String.t())
  }

  @doc """
  Optimizes a list of tasks based on multiple criteria:
  - Priority (lower number = higher priority)
  - Deadline (earlier deadline = higher priority)
  - Dependencies (tasks with dependencies come after their dependencies)
  - Duration (shorter tasks get slight priority boost)

  Returns {:ok, optimized_tasks} or {:error, reason}
  """
  @spec optimize(list(task)) :: {:ok, list(task)} | {:error, String.t()}
  def optimize(tasks) when is_list(tasks) do
    try do
      validated_tasks = validate_tasks(tasks)

      optimized = validated_tasks
      |> sort_by_priority()
      |> consider_deadlines()
      |> resolve_dependencies()
      |> optimize_duration()

      {:ok, optimized}
    rescue
      e in ArgumentError -> {:error, "Invalid task format: #{Exception.message(e)}"}
      _ -> {:error, "An unexpected error occurred during optimization"}
    end
  end

  def optimize(_), do: {:error, "Input must be a list of tasks"}

  @doc """
  Returns tasks that can be started immediately (no pending dependencies).
  """
  @spec available_tasks(list(task)) :: list(task)
  def available_tasks(tasks) do
    Enum.filter(tasks, &(!has_pending_dependencies?(&1, tasks)))
  end

  # Private functions

  defp validate_tasks(tasks) do
    Enum.map(tasks, fn task ->
      unless is_binary(task.name), do: raise ArgumentError, "Task name must be a string"
      unless is_integer(task.priority), do: raise ArgumentError, "Priority must be an integer"
      task
    end)
  end

  defp sort_by_priority(tasks) do
    Enum.sort_by(tasks, & &1.priority)
  end

  defp consider_deadlines(tasks) do
    now = DateTime.utc_now()

    Enum.sort_by(tasks, fn task ->
      deadline_score = case Map.get(task, :deadline) do
        nil -> 999_999  # No deadline = lowest priority
        deadline -> DateTime.diff(deadline, now)
      end

      {task.priority, deadline_score}
    end)
  end

  defp resolve_dependencies(tasks) do
    tasks
    |> Enum.reduce([], fn task, acc ->
      case has_pending_dependencies?(task, tasks) do
        true -> acc ++ [task]  # Add to end if has dependencies
        false -> [task | acc]  # Add to front if no dependencies
      end
    end)
    |> Enum.reverse()
  end

  defp optimize_duration(tasks) do
    Enum.sort_by(tasks, fn task ->
      duration = Map.get(task, :duration, 100)  # Default duration if not specified
      task.priority * (1 + duration / 1000)  # Slight boost for shorter tasks
    end)
  end

  defp has_pending_dependencies?(task, all_tasks) do
    case Map.get(task, :dependencies) do
      nil -> false
      deps ->
        completed_tasks = Enum.map(all_tasks, & &1.name)
        Enum.any?(deps, &(&1 in completed_tasks))
    end
  end
end
