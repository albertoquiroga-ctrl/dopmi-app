import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { configuredApi } from './api';
import './styles.css';
const api = configuredApi();
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><App api={api} /></React.StrictMode>);
