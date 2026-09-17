import { useEffect, useState } from "react";
import "./App.css";

const API = "/api/todos";

export default function App() {
  const [todos, setTodos] = useState([]);
  const [title, setTitle] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  async function loadTodos() {
    try {
      setError("");
      const res = await fetch(API);
      if (!res.ok) throw new Error("Failed to load todos");
      const data = await res.json();
      setTodos(data);
    } catch (err) {
      setError(err.message || "Something went wrong");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadTodos();
  }, []);

  async function handleAdd(e) {
    e.preventDefault();
    const trimmed = title.trim();
    if (!trimmed) return;

    try {
      setError("");
      const res = await fetch(API, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: trimmed }),
      });
      if (!res.ok) throw new Error("Failed to add todo");
      const created = await res.json();
      setTodos((prev) => [created, ...prev]);
      setTitle("");
    } catch (err) {
      setError(err.message || "Something went wrong");
    }
  }

  async function handleToggle(todo) {
    try {
      setError("");
      const res = await fetch(`${API}/${todo._id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ completed: !todo.completed }),
      });
      if (!res.ok) throw new Error("Failed to update todo");
      const updated = await res.json();
      setTodos((prev) => prev.map((t) => (t._id === updated._id ? updated : t)));
    } catch (err) {
      setError(err.message || "Something went wrong");
    }
  }

  async function handleDelete(id) {
    try {
      setError("");
      const res = await fetch(`${API}/${id}`, { method: "DELETE" });
      if (!res.ok) throw new Error("Failed to delete todo");
      setTodos((prev) => prev.filter((t) => t._id !== id));
    } catch (err) {
      setError(err.message || "Something went wrong");
    }
  }

  return (
    <main className="app">
      <h1>Todo</h1>
      <p className="subtitle">Simple three-tier demo</p>

      <form className="add-form" onSubmit={handleAdd}>
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="What needs doing?"
          aria-label="New todo"
        />
        <button type="submit">Add</button>
      </form>

      {error && <p className="error">{error}</p>}
      {loading && <p className="muted">Loading…</p>}

      {!loading && todos.length === 0 && (
        <p className="muted">No todos yet. Add one above.</p>
      )}

      <ul className="todo-list">
        {todos.map((todo) => (
          <li key={todo._id} className={todo.completed ? "done" : ""}>
            <label>
              <input
                type="checkbox"
                checked={todo.completed}
                onChange={() => handleToggle(todo)}
              />
              <span>{todo.title}</span>
            </label>
            <button
              type="button"
              className="delete"
              onClick={() => handleDelete(todo._id)}
            >
              Delete
            </button>
          </li>
        ))}
      </ul>
    </main>
  );
}
