#!/usr/bin/env bash
set -e

# Ensure we're in the repo root (run this script from the repo root)
echo "Creating branch feature/react-todo and scaffolding app..."
git checkout -b feature/react-todo

# Create directories
mkdir -p app
mkdir -p app/src/components
mkdir -p app/src/hooks
mkdir -p app/src/__tests__
mkdir -p .github/workflows

# Write app/package.json
cat > app/package.json <<'JSON'
{
  "name": "soyjack-todo-app",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview --port 5173",
    "test": "vitest"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@testing-library/jest-dom": "^5.16.5",
    "@testing-library/react": "^14.0.0",
    "@vitejs/plugin-react": "^4.0.0",
    "jsdom": "^22.1.0",
    "vitest": "^1.6.11",
    "vite": "^5.0.0"
  }
}
JSON

# Write app/index.html
cat > app/index.html <<'HTML'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Soyjack To‑Do (React)</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
HTML

# Write src files
cat > app/src/main.jsx <<'JS'
import React from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'
import './styles.css'

createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
JS

cat > app/src/App.jsx <<'JS'
import React from 'react'
import TodoList from './components/TodoList'

export default function App(){
  return (
    <div className="app-root">
      <header className="app-header">
        <h1>Soyjack To‑Do</h1>
        <p className="muted">Local-only demo (localStorage)</p>
      </header>
      <main>
        <TodoList />
      </main>
    </div>
  )
}
JS

cat > app/src/components/TodoList.jsx <<'JS'
import React, { useState } from 'react'
import useLocalTodos from '../hooks/useLocalTodos'
import TodoItem from './TodoItem'

export default function TodoList(){
  const { todos, addTodo, toggleComplete, removeTodo, importTodos, exportTodos } = useLocalTodos()
  const [text, setText] = useState('')

  function onAdd(e){
    e?.preventDefault()
    const v = text.trim()
    if (!v) return
    addTodo(v)
    setText('')
  }

  return (
    <section className="card" aria-label="todo app">
      <form className="new" onSubmit={onAdd}>
        <input aria-label="New task" value={text} onChange={e=>setText(e.target.value)} placeholder="Add a task" />
        <button className="btn" type="submit">Add</button>
      </form>

      <div className="controls">
        <div className="actions-left">
          <button className="btn secondary" onClick={()=>{ if(confirm('Clear completed?')){ const completed = todos.filter(t=>t.completed).map(t=>t.id); completed.forEach(id=>removeTodo(id)) }}}>Clear completed</button>
        </div>
        <div style={{marginLeft:'auto', display:'flex', gap:8}}>
          <button className="btn secondary" onClick={()=>exportTodos()}>Export</button>
          <label className="btn secondary" style={{cursor:'pointer'}}>
            Import
            <input type="file" accept="application/json" style={{display:'none'}} onChange={async e=>{ const f = e.target.files?.[0]; if(!f) return; const txt = await f.text(); try{ importTodos(JSON.parse(txt)) }catch(err){ alert('Invalid file') } }} />
          </label>
        </div>
      </div>

      <ul className="tasks" aria-live="polite">
        {todos.length === 0 && <li className="empty">No tasks yet.</li>}
        {todos.map(t=> (
          <TodoItem key={t.id} todo={t} onToggle={()=>toggleComplete(t.id)} onDelete={()=>removeTodo(t.id)} />
        ))}
      </ul>

    </section>
  )
}
JS

cat > app/src/components/TodoItem.jsx <<'JS'
import React from 'react'

export default function TodoItem({ todo, onToggle, onDelete }){
  return (
    <li className={`task ${todo.completed? 'completed':''}`}>
      <input aria-label={`Mark ${todo.title} complete`} type="checkbox" checked={todo.completed} onChange={onToggle} />
      <div className="title" contentEditable suppressContentEditableWarning onBlur={(e)=>{ const val = e.target.textContent.trim(); if(!val) onDelete(); else todo.title = val }}>
        {todo.title}
      </div>
      <div className="actions">
        <button className="btn secondary" onClick={()=>{ const el = document.querySelector('.title'); if(el) el.focus() }}>Edit</button>
        <button className="btn secondary" onClick={onDelete}>Delete</button>
      </div>
    </li>
  )
}
JS

cat > app/src/hooks/useLocalTodos.js <<'JS'
import { useState, useEffect } from 'react'

const KEY = 'soyjack_todos_v1'

export default function useLocalTodos(){
  const [todos, setTodos] = useState([])

  useEffect(()=>{
    try{
      const raw = localStorage.getItem(KEY)
      setTodos(raw ? JSON.parse(raw) : [])
    }catch(e){ setTodos([]) }
  },[])

  useEffect(()=>{
    // debounce save
    const t = setTimeout(()=> localStorage.setItem(KEY, JSON.stringify(todos)), 150)
    return ()=>clearTimeout(t)
  },[todos])

  function addTodo(title){
    const task = { id: Date.now().toString(36) + Math.random().toString(36).slice(2,8), title, completed:false, createdAt: Date.now() }
    setTodos(prev => [task, ...prev])
  }

  function toggleComplete(id){
    setTodos(prev => prev.map(t => t.id === id ? {...t, completed: !t.completed} : t))
  }

  function removeTodo(id){
    setTodos(prev => prev.filter(t => t.id !== id))
  }

  function importTodos(list){
    if(!Array.isArray(list)) return
    const imported = list.map(x => ({ id: Date.now().toString(36)+Math.random().toString(36).slice(2,6), title: x.title||'', completed: !!x.completed, createdAt: x.createdAt||Date.now() }))
    setTodos(prev => [...imported, ...prev])
  }

  function exportTodos(){
    const blob = new Blob([JSON.stringify(todos, null, 2)], {type:'application/json'})
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url; a.download = 'todos.json'; document.body.appendChild(a); a.click(); a.remove(); URL.revokeObjectURL(url)
  }

  return { todos, addTodo, toggleComplete, removeTodo, importTodos, exportTodos }
}
JS

# Write styles
cat > app/src/styles.css <<'CSS'
:root{--bg:#f7f7fb;--card:#fff;--accent:#6b5ce3;--muted:#777}
*{box-sizing:border-box}
body{margin:0;font-family:Inter,system-ui,-apple-system,Segoe UI,Roboto,"Helvetica Neue",Arial;background:var(--bg);display:flex;align-items:flex-start;justify-content:center;padding:28px}
.app-root{width:100%;max-width:760px}
.app-header{display:flex;align-items:center;gap:12px;margin-bottom:18px}
h1{margin:0;font-size:20px}
.card{background:var(--card);padding:16px;border-radius:10px;box-shadow:0 6px 18px rgba(16,24,40,0.06)}
.new{display:flex;gap:8px;margin-bottom:12px}
.new input{flex:1;padding:10px;border:1px solid #e6e9f0;border-radius:8px;font-size:15px}
.btn{background:var(--accent);color:#fff;padding:10px 12px;border:0;border-radius:8px;cursor:pointer}
.btn.secondary{background:#efefef;color:#111}
.controls{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin-bottom:12px}
.tasks{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:8px}
li.task{display:flex;align-items:center;gap:10px;padding:10px;border:1px solid #eef0fa;border-radius:8px}
li.task.completed{opacity:0.6;text-decoration:line-through}
.title{flex:1}
.actions{display:flex;gap:6px}
.empty{padding:18px;text-align:center;color:var(--muted)}
.muted{color:var(--muted)}
@media (max-width:520px){body{padding:12px}.card{padding:12px}}
CSS

# Vite config
cat > app/vite.config.js <<'CFG'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()]
})
CFG

# .gitignore
cat > app/.gitignore <<'IGN'
node_modules
dist
.env
IGN

# README
cat > app/README.md <<'MD'
# Soyjack To‑Do (React)

This folder contains a Vite + React conversion of the simple localStorage To‑Do example.

Quick start (Chromebook Linux / any system with Node.js):

1. cd app
2. npm install
3. npm run dev
4. Open the URL printed by Vite (http://localhost:5173) in Chrome

Run tests:

npm run test

Build for production:

npm run build

This project preserves the same localStorage key `soyjack_todos_v1` so existing data from the examples will be reused.
MD

# Test
cat > app/src/__tests__/App.test.jsx <<'TEST'
import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, beforeEach } from 'vitest'
import React from 'react'
import App from '../App'

beforeEach(()=>{
  localStorage.clear()
})

describe('App', ()=>{
  it('renders and adds a todo', async ()=>{
    render(<App />)
    const input = screen.getByPlaceholderText(/add a task/i)
    const addBtn = screen.getByText(/add/i)
    fireEvent.change(input, { target: { value: 'Buy milk' } })
    fireEvent.click(addBtn)
    expect(await screen.findByText('Buy milk')).toBeTruthy()
  })
})
TEST

# CI workflow
cat > .github/workflows/ci.yml <<'YML'
name: CI

on:
  push:
    branches: [ main, feature/react-todo ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Use Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
      - name: Install
        working-directory: app
        run: npm ci
      - name: Run tests
        working-directory: app
        run: npm run test
      - name: Build
        working-directory: app
        run: npm run build

  deploy:
    if: github.ref == 'refs/heads/main'
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '18'
      - name: Install
        working-directory: app
        run: npm ci
      - name: Build
        working-directory: app
        run: npm run build
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./app/dist
YML

# Stage and commit
git add app .github/workflows/ci.yml
git commit -m "Add React Vite todo app (feature/react-todo): scaffold, tests, CI"
git push -u origin feature/react-todo

echo "Done. Branch feature/react-todo pushed."
