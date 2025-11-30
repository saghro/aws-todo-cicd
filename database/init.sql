-- Script d'initialisation de la base de données Todo

-- Créer la base de données
CREATE DATABASE tododb;

-- Se connecter à la base de données
\c tododb;

-- Créer l'utilisateur
CREATE USER todouser WITH ENCRYPTED PASSWORD 'SecurePassword123!';

-- Créer la table todos
CREATE TABLE IF NOT EXISTS todos (
                                     id SERIAL PRIMARY KEY,
                                     title VARCHAR(255) NOT NULL,
    description TEXT,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

-- Donner les permissions à l'utilisateur
GRANT ALL PRIVILEGES ON DATABASE tododb TO todouser;
GRANT ALL PRIVILEGES ON TABLE todos TO todouser;
GRANT USAGE, SELECT ON SEQUENCE todos_id_seq TO todouser;

-- Insérer des données de test
INSERT INTO todos (title, description, completed) VALUES
                                                      ('Configurer AWS Infrastructure', 'Déployer VPC, subnets, EC2', true),
                                                      ('Installer PostgreSQL', 'Installer et configurer PostgreSQL sur EC2 privé', false),
                                                      ('Déployer l''application', 'Déployer React + Node.js sur EC2 public', false),
                                                      ('Configurer CloudWatch', 'Mettre en place monitoring et alertes', false),
                                                      ('Tester le pipeline CI/CD', 'Vérifier que GitHub Actions fonctionne', false);

-- Créer un index sur completed pour optimiser les requêtes
CREATE INDEX idx_todos_completed ON todos(completed);

-- Afficher les données insérées
SELECT * FROM todos;