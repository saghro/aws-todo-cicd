import './App.css';

import { useCallback, useEffect, useState } from 'react';

export default function TodoApp() {
    const [todos, setTodos] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [selectedTodo, setSelectedTodo] = useState(null);
    const [lists] = useState([
        { id: 1, name: 'Personal', color: 'red', count: 0 },
        { id: 2, name: 'Work', color: 'blue', count: 0 },
        { id: 3, name: 'List 1', color: 'yellow', count: 10 }
    ]);
    const [tags] = useState(['Tag 1', 'Tag 2']);
    const [activeView, setActiveView] = useState('Today');

    // Configuration de l'URL de l'API
    // Priorité: 1. Variable d'environnement REACT_APP_API_URL
    //           2. window.REACT_APP_API_URL (pour override dynamique)
    //           3. localhost:3000 (par défaut)
    const API_URL = window.REACT_APP_API_URL || process.env.REACT_APP_API_URL || 'http://localhost:3000';
    
    // Log pour débogage (uniquement en développement)
    if (process.env.NODE_ENV === 'development') {
        console.log('🔗 URL de l\'API configurée:', API_URL);
    }

    useEffect(() => {
        fetch(`${API_URL}/health`)
            .then(res => res.json())
            .then(() => {})
            .catch(() => {
                setError('Impossible de se connecter au serveur');
            });
    }, [API_URL]);

    const fetchTodos = useCallback(async () => {
        try {
            setLoading(true);
            const response = await fetch(`${API_URL}/api/todos`);
            const data = await response.json();
            if (data.success) {
                setTodos(data.data);
                setError(null);
            } else {
                setError('Erreur lors du chargement des tâches');
            }
        } catch (err) {
            setError('Impossible de se connecter au serveur');
            console.error('Error:', err);
        } finally {
            setLoading(false);
        }
    }, [API_URL]);

    useEffect(() => {
        fetchTodos();
    }, [fetchTodos]);

    const handleToggleTodo = async (id, completed) => {
        try {
            const response = await fetch(`${API_URL}/api/todos/${id}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ completed: !completed }),
            });
            const data = await response.json();
            if (data.success) {
                setTodos(todos.map(t => t.id === id ? data.data : t));
                if (selectedTodo && selectedTodo.id === id) {
                    setSelectedTodo(data.data);
                }
            }
        } catch (err) {
            console.error('Error updating todo:', err);
        }
    };

    const handleDeleteTodo = async (id) => {
        try {
            const response = await fetch(`${API_URL}/api/todos/${id}`, {
                method: 'DELETE',
            });
            const data = await response.json();
            if (data.success) {
                setTodos(todos.filter(t => t.id !== id));
                if (selectedTodo && selectedTodo.id === id) {
                    setSelectedTodo(null);
                }
            }
        } catch (err) {
            console.error('Error deleting todo:', err);
        }
    };

    const handleUpdateTodo = async () => {
        if (!selectedTodo) return;
        try {
            const response = await fetch(`${API_URL}/api/todos/${selectedTodo.id}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(selectedTodo),
            });
            const data = await response.json();
            if (data.success) {
                setTodos(todos.map(t => t.id === selectedTodo.id ? data.data : t));
                setSelectedTodo(data.data);
            }
        } catch (err) {
            console.error('Error updating todo:', err);
        }
    };

    const handleCreateTodo = async () => {
        try {
            const response = await fetch(`${API_URL}/api/todos`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ title: 'New Task', description: '', completed: false }),
            });
            const data = await response.json();
            if (data.success) {
                setTodos([data.data, ...todos]);
                setSelectedTodo(data.data);
            }
        } catch (err) {
            console.error('Error creating todo:', err);
        }
    };

    const todayTodos = todos.filter(todo => {
        if (activeView === 'Today') {
            const today = new Date().toDateString();
            const todoDate = new Date(todo.created_at).toDateString();
            return todoDate === today;
        }
        return true;
    });

    const todayCount = todos.filter(todo => {
        const today = new Date().toDateString();
        const todoDate = new Date(todo.created_at).toDateString();
        return todoDate === today;
    }).length;

    return (
        <div className="app-container">
            <div className="header-bar">
                <div className="header-left">
                    <div className="header-icon">
                        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                        </svg>
                    </div>
                    <span className="header-text">Échec de l'ouverture de la page</span>
                </div>
                <div className="header-right">
                    <svg fill="currentColor" viewBox="0 0 24 24">
                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
                    </svg>
                    <span className="header-text">React App</span>
                </div>
            </div>

            <div className="main-content">
                <div className="sidebar-left">
                    <div className="menu-header">
                        <h2 className="menu-title">Menu</h2>
                        <input
                            type="text"
                            placeholder="Q Search"
                            className="search-input"
                        />
                    </div>

                    <div className="sidebar-content">
                        <div className="section">
                            <h3 className="section-title">TASKS</h3>
                            <ul className="menu-list">
                                <li>
                                    <button
                                        onClick={() => setActiveView('Upcoming')}
                                        className={`menu-item ${activeView === 'Upcoming' ? 'active' : ''}`}
                                    >
                                        Upcoming12
                                    </button>
                                </li>
                                <li>
                                    <button
                                        onClick={() => setActiveView('Today')}
                                        className={`menu-item ${activeView === 'Today' ? 'active' : ''}`}
                                    >
                                        Today{todayCount}
                                    </button>
                                </li>
                                <li>
                                    <button
                                        onClick={() => setActiveView('Calendar')}
                                        className={`menu-item ${activeView === 'Calendar' ? 'active' : ''}`}
                                    >
                                        Calendar
                                    </button>
                                </li>
                                <li>
                                    <button
                                        onClick={() => setActiveView('Sticky Wall')}
                                        className={`menu-item ${activeView === 'Sticky Wall' ? 'active' : ''}`}
                                    >
                                        Sticky Wall
                                    </button>
                                </li>
                            </ul>
                        </div>

                        <div className="section">
                            <h3 className="section-title">LISTS</h3>
                            <ul className="menu-list">
                                {lists.map((list) => (
                                    <li key={list.id}>
                                        <button className="menu-item menu-item-flex">
                                            <span className={`menu-item-color`} style={{ backgroundColor: list.color === 'red' ? '#ef4444' : list.color === 'blue' ? '#3b82f6' : '#eab308' }}></span>
                                            <span className="menu-item-text">{list.name}{list.count}</span>
                                        </button>
                                    </li>
                                ))}
                                <li>
                                    <button className="menu-item menu-item-gray">
                                        + Add New List
                                    </button>
                                </li>
                            </ul>
                        </div>

                        <div className="section">
                            <h3 className="section-title">TAGS</h3>
                            <ul className="menu-list">
                                {tags.map((tag) => (
                                    <li key={tag}>
                                        <button className="menu-item">{tag}</button>
                                    </li>
                                ))}
                                <li>
                                    <button className="menu-item menu-item-gray">
                                        + Add Tag
                                    </button>
                                </li>
                            </ul>
                        </div>

                        <div className="section">
                            <button className="menu-item">Settings</button>
                            <button className="menu-item">Sign out</button>
                        </div>
                    </div>

                    <div className="sidebar-bottom">
                        <div className="pro-badge">Pro</div>
                    </div>
                </div>

                <div className="content-area">
                    <div className="content-header">
                        <h1 className="content-title">Today {todayCount}</h1>
                        <button onClick={handleCreateTodo} className="add-task-btn">
                            + Add New Task
                        </button>
                    </div>

                    {error ? (
                        <div className="error-message">
                            <div className="error-content">
                                <svg fill="currentColor" viewBox="0 0 20 20">
                                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                                </svg>
                                <span className="error-text">{error}</span>
                            </div>
                        </div>
                    ) : loading ? (
                        <div className="loading-container">
                            <div className="spinner"></div>
                            <p className="loading-text">Chargement...</p>
                        </div>
                    ) : todayTodos.length === 0 ? (
                        <div className="empty-state">
                            <p>Aucune tâche pour le moment</p>
                        </div>
                    ) : (
                        <div className="tasks-list">
                            {todayTodos.map((todo) => (
                                <button
                                    key={todo.id}
                                    type="button"
                                    className={`task-item ${selectedTodo && selectedTodo.id === todo.id ? 'selected' : ''}`}
                                    onClick={() => setSelectedTodo(todo)}
                                >
                                    <input
                                        type="checkbox"
                                        checked={todo.completed}
                                        onChange={(e) => {
                                            e.stopPropagation();
                                            handleToggleTodo(todo.id, todo.completed);
                                        }}
                                        className="task-checkbox"
                                    />
                                    <span className={`task-title ${todo.completed ? 'completed' : ''}`}>
                                        {todo.title}
                                    </span>
                                    <svg className="task-arrow" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                                    </svg>
                                </button>
                            ))}
                        </div>
                    )}
                </div>

                <div className="sidebar-right">
                    {selectedTodo ? (
                        <div className="sidebar-right-content">
                            <div className="task-detail-section">
                                <h2 className="task-detail-label">Task:</h2>
                                <input
                                    type="text"
                                    value={selectedTodo.title}
                                    onChange={(e) => setSelectedTodo({ ...selectedTodo, title: e.target.value })}
                                    className="task-detail-input"
                                />
                            </div>

                            <div className="task-detail-section">
                                <label htmlFor="description" className="detail-field-label">Description</label>
                                <textarea
                                    id="description"
                                    value={selectedTodo.description || ''}
                                    onChange={(e) => setSelectedTodo({ ...selectedTodo, description: e.target.value })}
                                    className="task-detail-textarea"
                                    rows="4"
                                />
                            </div>

                            <div className="task-detail-section">
                                <div className="detail-field">
                                    <label htmlFor="list" className="detail-field-label">List</label>
                                    <div id="list" className="detail-field-box">
                                        <span>Personal</span>
                                        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                                        </svg>
                                    </div>
                                </div>

                                <div className="detail-field">
                                    <label htmlFor="due-date" className="detail-field-label">Due date</label>
                                    <div id="due-date" className="detail-field-box">
                                        <span>11-03-22</span>
                                        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                                        </svg>
                                    </div>
                                </div>

                                <div className="detail-field">
                                    <label htmlFor="tags" className="detail-field-label">Tags</label>
                                    <div id="tags" className="tags-container">
                                        <span className="tag-item">Tag 1</span>
                                        <button className="tag-add-btn">+ Add Tag</button>
                                    </div>
                                </div>
                            </div>

                            <div className="subtasks-section">
                                <h3 className="subtasks-title">Subtasks:</h3>
                                <button className="subtask-add-btn">+ Add New Subtask</button>
                                <div className="subtask-item">
                                    <input type="checkbox" className="subtask-checkbox" />
                                    <span className="subtask-text">Subtask placeholder</span>
                                </div>
                            </div>

                            <div className="action-buttons">
                                <button
                                    onClick={() => handleDeleteTodo(selectedTodo.id)}
                                    className="action-btn delete-btn"
                                >
                                    Delete Task
                                </button>
                                <button
                                    onClick={handleUpdateTodo}
                                    className="action-btn save-btn"
                                >
                                    Save changes
                                </button>
                            </div>
                        </div>
                    ) : (
                        <div className="empty-sidebar">
                            <p>Sélectionnez une tâche pour voir les détails</p>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}
