const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const path = require('path');
const { Pool } = require('pg');
const chalk = require('chalk');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// ==================== MIDDLEWARE ====================
app.use(cors({
    origin: '*', // En production, spécifiez les origines autorisées
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Middleware de logging avec style ANSI
app.use((req, res, next) => {
    const methodColors = {
        'GET': chalk.blue,
        'POST': chalk.green,
        'PUT': chalk.yellow,
        'DELETE': chalk.red,
        'PATCH': chalk.magenta
    };
    const colorMethod = methodColors[req.method] || chalk.white;
    const timestamp = chalk.gray(new Date().toISOString());
    console.log(`${timestamp} ${colorMethod(req.method.padEnd(6))} ${chalk.cyan(req.path)}`);
    next();
});

// ==================== CONFIGURATION POSTGRESQL ====================
const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'tododb',
    user: process.env.DB_USER || 'todouser',
    password: process.env.DB_PASSWORD || 'todopass',
    max: 20, // Nombre maximum de clients dans le pool
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// Gérer les erreurs de connexion du pool
pool.on('error', (err, client) => {
    console.error(chalk.red.bold('❌ Erreur inattendue du client PostgreSQL:'), chalk.red(err));
    process.exit(-1);
});

// Test de connexion initial (non-bloquant)
pool.connect()
    .then((client) => {
        console.log(chalk.green.bold('✅ Connecté à PostgreSQL avec succès'));
        console.log(chalk.cyan(`📍 Base de données: ${chalk.white.bold(process.env.DB_NAME || 'tododb')} sur ${chalk.white.bold(process.env.DB_HOST || 'localhost')}:${chalk.white.bold(process.env.DB_PORT || '5432')}`));
        client.release();
    })
    .catch((err) => {
        console.error(chalk.red.bold('⚠️  Avertissement: Impossible de se connecter à la base de données'));
        console.error(chalk.yellow('Le serveur démarrera quand même, mais les fonctionnalités de base de données ne seront pas disponibles.'));
        console.error(chalk.gray(`  DB_HOST: ${process.env.DB_HOST || 'localhost (par défaut)'}`));
        console.error(chalk.gray(`  DB_PORT: ${process.env.DB_PORT || '5432 (par défaut)'}`));
        console.error(chalk.gray(`  DB_NAME: ${process.env.DB_NAME || 'tododb (par défaut)'}`));
        console.error(chalk.gray(`  DB_USER: ${process.env.DB_USER || 'todouser (par défaut)'}`));
        console.error(chalk.gray(`  Erreur: ${err.message}`));
    });

// ==================== ROUTES ====================

// Route de documentation API (déplacée vers /api pour permettre le frontend sur /)
app.get('/api', (req, res) => {
    res.json({
        message: '🎉 Bienvenue sur l\'API Todo App!',
        version: '1.0.0',
        endpoints: {
            health: 'GET /health',
            todos: {
                list: 'GET /api/todos',
                get: 'GET /api/todos/:id',
                create: 'POST /api/todos',
                update: 'PUT /api/todos/:id',
                delete: 'DELETE /api/todos/:id',
                stats: 'GET /api/todos/stats'
            }
        },
        documentation: 'https://github.com/votre-username/aws-todo-cicd'
    });
});

// Route de santé / health check
app.get('/health', async (req, res) => {
    try {
        // Vérifier la connexion à la base de données
        const result = await pool.query('SELECT NOW()');

        res.json({
            status: 'OK',
            timestamp: new Date().toISOString(),
            environment: process.env.NODE_ENV || 'development',
            uptime: process.uptime(),
            database: {
                connected: true,
                serverTime: result.rows[0].now
            },
            system: {
                platform: process.platform,
                nodeVersion: process.version,
                memory: {
                    total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024) + ' MB',
                    used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + ' MB'
                }
            }
        });
    } catch (err) {
        console.error(chalk.red.bold('❌ Erreur health check:'), chalk.red(err.message));
        res.status(503).json({
            status: 'ERROR',
            timestamp: new Date().toISOString(),
            database: {
                connected: false,
                error: err.message
            }
        });
    }
});

// ==================== CRUD TODOS ====================

// GET - Récupérer toutes les tâches
app.get('/api/todos', async (req, res) => {
    try {
        const { completed, limit, offset } = req.query;

        let query = 'SELECT * FROM todos';
        let params = [];

        // Filtrer par statut completed
        if (completed !== undefined) {
            query += ' WHERE completed = $1';
            params.push(completed === 'true');
        }

        query += ' ORDER BY created_at DESC';

        // Pagination
        if (limit) {
            params.push(limit);
            query += ` LIMIT $${params.length}`;
        }
        if (offset) {
            params.push(offset);
            query += ` OFFSET $${params.length}`;
        }

        const result = await pool.query(query, params);

        res.json({
            success: true,
            data: result.rows,
            count: result.rows.length,
            timestamp: new Date().toISOString()
        });
    } catch (err) {
        console.error(chalk.red.bold('❌ Erreur lors de la récupération des tâches:'), chalk.red(err.message));
        res.status(500).json({
            success: false,
            error: 'Erreur serveur lors de la récupération des tâches',
            message: err.message,
            timestamp: new Date().toISOString()
        });
    }
});

// GET - Récupérer une tâche par ID
app.get('/api/todos/:id', async (req, res) => {
    try {
        const { id } = req.params;

        // Valider que l'ID est un nombre
        if (isNaN(id)) {
            return res.status(400).json({
                success: false,
                error: 'ID invalide. L\'ID doit être un nombre.'
            });
        }

        const result = await pool.query(
            'SELECT * FROM todos WHERE id = $1',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: `Tâche avec l'ID ${id} non trouvée`
            });
        }

        res.json({
            success: true,
            data: result.rows[0],
            timestamp: new Date().toISOString()
        });
    } catch (err) {
        console.error(chalk.red.bold('❌ Erreur lors de la récupération de la tâche:'), chalk.red(err.message));
        res.status(500).json({
            success: false,
            error: 'Erreur serveur lors de la récupération de la tâche',
            message: err.message,
            timestamp: new Date().toISOString()
        });
    }
});

// POST - Créer une nouvelle tâche
app.post('/api/todos', async (req, res) => {
    try {
        const { title, description } = req.body;

        // Validation
        if (!title || title.trim() === '') {
            return res.status(400).json({
                success: false,
                error: 'Le titre est requis et ne peut pas être vide'
            });
        }

        if (title.length > 255) {
            return res.status(400).json({
                success: false,
                error: 'Le titre ne peut pas dépasser 255 caractères'
            });
        }

        const result = await pool.query(
            'INSERT INTO todos (title, description) VALUES ($1, $2) RETURNING *',
            [title.trim(), description ? description.trim() : '']
        );

        console.log(chalk.green(`✅ Nouvelle tâche créée: ${chalk.white.bold(result.rows[0].id)} - ${chalk.cyan(title)}`));

        res.status(201).json({
            success: true,
            data: result.rows[0],
            message: 'Tâche créée avec succès',
            timestamp: new Date().toISOString()
        });
    } catch (err) {
        console.error(chalk.red.bold('❌ Erreur lors de la création de la tâche:'), chalk.red(err.message));
        res.status(500).json({
            success: false,
            error: 'Erreur serveur lors de la création de la tâche',
            message: err.message,
            timestamp: new Date().toISOString()
        });
    }
});

// PUT - Mettre à jour une tâche
app.put('/api/todos/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { title, description, completed } = req.body;

        // Valider que l'ID est un nombre
        if (isNaN(id)) {
            return res.status(400).json({
                success: false,
                error: 'ID invalide. L\'ID doit être un nombre.'
            });
        }

        // Vérifier que la tâche existe
        const checkResult = await pool.query(
            'SELECT * FROM todos WHERE id = $1',
            [id]
        );

        if (checkResult.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: `Tâche avec l'ID ${id} non trouvée`
            });
        }

        // Validation du titre si fourni
        if (title !== undefined && (title.trim() === '' || title.length > 255)) {
            return res.status(400).json({
                success: false,
                error: 'Le titre ne peut pas être vide et doit faire moins de 255 caractères'
            });
        }

        // Construire la requête de mise à jour
        const result = await pool.query(
            `UPDATE todos 
       SET title = COALESCE($1, title), 
           description = COALESCE($2, description), 
           completed = COALESCE($3, completed), 
           updated_at = NOW() 
       WHERE id = $4 
       RETURNING *`,
            [
                title ? title.trim() : null,
                description !== undefined ? description.trim() : null,
                completed,
                id
            ]
        );

        console.log(chalk.yellow(`✅ Tâche mise à jour: ${chalk.white.bold(id)} - ${chalk.cyan(result.rows[0].title)}`));

        res.json({
            success: true,
            data: result.rows[0],
            message: 'Tâche mise à jour avec succès',
            timestamp: new Date().toISOString()
        });
    } catch (err) {
        console.error(chalk.red.bold('❌ Erreur lors de la mise à jour de la tâche:'), chalk.red(err.message));
        res.status(500).json({
            success: false,
            error: 'Erreur serveur lors de la mise à jour de la tâche',
            message: err.message,
            timestamp: new Date().toISOString()
        });
    }
});

// DELETE - Supprimer une tâche
app.delete('/api/todos/:id', async (req, res) => {
    try {
        const { id } = req.params;

        // Valider que l'ID est un nombre
        if (isNaN(id)) {
            return res.status(400).json({
                success: false,
                error: 'ID invalide. L\'ID doit être un nombre.'
            });
        }

        const result = await pool.query(
            'DELETE FROM todos WHERE id = $1 RETURNING *',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: `Tâche avec l'ID ${id} non trouvée`
            });
        }

        console.log(chalk.red(`✅ Tâche supprimée: ${chalk.white.bold(id)} - ${chalk.cyan(result.rows[0].title)}`));

        res.json({
            success: true,
            data: result.rows[0],
            message: 'Tâche supprimée avec succès',
            timestamp: new Date().toISOString()
        });
    } catch (err) {
        console.error(chalk.red.bold('❌ Erreur lors de la suppression de la tâche:'), chalk.red(err.message));
        res.status(500).json({
            success: false,
            error: 'Erreur serveur lors de la suppression de la tâche',
            message: err.message,
            timestamp: new Date().toISOString()
        });
    }
});

// GET - Statistiques des tâches
app.get('/api/todos/stats', async (req, res) => {
    try {
        const result = await pool.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE completed = true) as completed,
        COUNT(*) FILTER (WHERE completed = false) as pending,
        COUNT(*) FILTER (WHERE DATE(created_at) = CURRENT_DATE) as today
      FROM todos
    `);

        res.json({
            success: true,
            data: {
                total: parseInt(result.rows[0].total),
                completed: parseInt(result.rows[0].completed),
                pending: parseInt(result.rows[0].pending),
                today: parseInt(result.rows[0].today)
            },
            timestamp: new Date().toISOString()
        });
    } catch (err) {
        console.error(chalk.red.bold('❌ Erreur lors de la récupération des statistiques:'), chalk.red(err.message));
        res.status(500).json({
            success: false,
            error: 'Erreur serveur lors de la récupération des statistiques',
            message: err.message,
            timestamp: new Date().toISOString()
        });
    }
});

// ==================== SERVIR LE FRONTEND (PRODUCTION) ====================
// Servir les fichiers statiques du frontend React en production
// IMPORTANT: Ce middleware doit être placé APRÈS toutes les routes API
const fs = require('fs');
const frontendBuildPath = path.join(__dirname, '../frontend/build');
if (process.env.NODE_ENV === 'production' && fs.existsSync(frontendBuildPath)) {
    // Servir les fichiers statiques du frontend
    app.use(express.static(frontendBuildPath));
    
    // Pour toutes les routes non-API, servir index.html (pour React Router)
    // Cette route catch-all doit être la dernière
    app.use((req, res, next) => {
        // Ne pas intercepter les routes API ou health
        if (req.path.startsWith('/api') || req.path.startsWith('/health')) {
            return next();
        }
        // Vérifier si c'est une requête pour un fichier statique
        const ext = req.path.split('.').pop();
        const staticExtensions = ['js', 'css', 'png', 'jpg', 'jpeg', 'gif', 'svg', 'ico', 'json', 'woff', 'woff2', 'ttf', 'eot', 'map'];
        if (staticExtensions.includes(ext)) {
            return next();
        }
        // Sinon, servir index.html pour React Router
        res.sendFile(path.join(frontendBuildPath, 'index.html'), (err) => {
            if (err) {
                next(err);
            }
        });
    });
    
    console.log(chalk.green('✅ Frontend React sera servi depuis:'), chalk.white(frontendBuildPath));
}

// Middleware de gestion des erreurs globales
app.use((err, req, res, next) => {
    console.error(chalk.red.bold('❌ Erreur non gérée:'), chalk.red(err));
    res.status(500).json({
        success: false,
        error: 'Erreur interne du serveur',
        message: process.env.NODE_ENV === 'development' ? err.message : 'Une erreur est survenue',
        timestamp: new Date().toISOString()
    });
});

// ==================== DÉMARRAGE DU SERVEUR ====================

const server = app.listen(PORT, '0.0.0.0', () => {
    console.log('');
    console.log(chalk.bgBlue.white.bold(' '.repeat(50)));
    console.log(chalk.bgBlue.white.bold('  🚀 Serveur Todo API démarré avec succès!  '.padEnd(50)));
    console.log(chalk.bgBlue.white.bold(' '.repeat(50)));
    console.log('');
    console.log(chalk.cyan('📡 Port:'), chalk.white.bold(PORT));
    console.log(chalk.cyan('🌍 Environment:'), chalk.white.bold(process.env.NODE_ENV || 'development'));
    console.log(chalk.cyan('🕐 Démarré à:'), chalk.gray(new Date().toISOString()));
    console.log(chalk.cyan('🔗 URL locale:'), chalk.blue.underline(`http://localhost:${PORT}`));
    console.log(chalk.cyan('💾 Base de données:'), chalk.white.bold(`${process.env.DB_NAME || 'tododb'} @ ${process.env.DB_HOST || 'localhost'}`));
    console.log('');
    console.log(chalk.yellow.bold('📚 Endpoints disponibles:'));
    console.log(chalk.blue('  GET    '), chalk.white('/                    '), chalk.gray('- Documentation API'));
    console.log(chalk.blue('  GET    '), chalk.white('/health              '), chalk.gray('- Health check'));
    console.log(chalk.blue('  GET    '), chalk.white('/api/todos           '), chalk.gray('- Liste des tâches'));
    console.log(chalk.blue('  GET    '), chalk.white('/api/todos/:id       '), chalk.gray('- Détails d\'une tâche'));
    console.log(chalk.green('  POST   '), chalk.white('/api/todos           '), chalk.gray('- Créer une tâche'));
    console.log(chalk.yellow('  PUT    '), chalk.white('/api/todos/:id       '), chalk.gray('- Modifier une tâche'));
    console.log(chalk.red('  DELETE '), chalk.white('/api/todos/:id       '), chalk.gray('- Supprimer une tâche'));
    console.log(chalk.blue('  GET    '), chalk.white('/api/todos/stats     '), chalk.gray('- Statistiques'));
    console.log('');
    console.log(chalk.bgGreen.black.bold(' '.repeat(50)));
    console.log(chalk.bgGreen.black.bold('  ✅ Serveur prêt à recevoir des requêtes!  '.padEnd(50)));
    console.log(chalk.bgGreen.black.bold(' '.repeat(50)));
    console.log('');
});

// Gestion de l'arrêt gracieux
process.on('SIGTERM', () => {
    console.log(chalk.yellow.bold('⚠️  Signal SIGTERM reçu. Arrêt gracieux en cours...'));
    server.close(() => {
        console.log(chalk.green('✅ Serveur HTTP fermé'));
        pool.end(() => {
            console.log(chalk.green('✅ Pool PostgreSQL fermé'));
            process.exit(0);
        });
    });
});

process.on('SIGINT', () => {
    console.log(chalk.yellow.bold('⚠️  Signal SIGINT reçu. Arrêt gracieux en cours...'));
    server.close(() => {
        console.log(chalk.green('✅ Serveur HTTP fermé'));
        pool.end(() => {
            console.log(chalk.green('✅ Pool PostgreSQL fermé'));
            process.exit(0);
        });
    });
});

// Gestion des erreurs non capturées
process.on('uncaughtException', (err) => {
    console.error(chalk.red.bold('❌ Exception non capturée:'), chalk.red(err));
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error(chalk.red.bold('❌ Promesse rejetée non gérée à:'), chalk.red(promise), chalk.red('raison:'), chalk.red(reason));
    process.exit(1);
});

module.exports = app;