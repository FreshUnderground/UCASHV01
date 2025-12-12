<?php

/**
 * Classe de connexion à la base de données UCASH
 * Pattern Singleton pour garantir une seule instance de connexion
 */
class Database {
    private static $instance = null;
    private $connection;
    
    // Configuration de la base de données
    private $host = '91.216.107.185';
    private $dbname = 'inves2504808_1n6a7b';
    private $username = 'inves2504808';
    private $password = '31nzzasdnh';
    private $charset = 'utf8mb4';
    
    /**
     * Constructeur privé pour empêcher l'instanciation directe
     */
    private function __construct() {
        try {
            // Utiliser les constantes définies dans config/database.php si elles existent
            if (defined('DB_HOST')) {
                $this->host = DB_HOST;
            }
            if (defined('DB_NAME')) {
                $this->dbname = DB_NAME;
            }
            if (defined('DB_USER')) {
                $this->username = DB_USER;
            }
            if (defined('DB_PASS')) {
                $this->password = DB_PASS;
            }
            
            $dsn = "mysql:host={$this->host};dbname={$this->dbname};charset={$this->charset}";
            
            $options = [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
                PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES {$this->charset}"
            ];
            
            $this->connection = new PDO($dsn, $this->username, $this->password, $options);
            
        } catch (PDOException $e) {
            throw new Exception("Erreur de connexion à la base de données: " . $e->getMessage());
        }
    }
    
    /**
     * Récupère l'instance unique de Database
     * 
     * @return Database Instance unique
     */
    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    /**
     * Récupère la connexion PDO
     * 
     * @return PDO Connexion PDO
     */
    public function getConnection() {
        return $this->connection;
    }
    
    /**
     * Empêche le clonage de l'instance
     */
    private function __clone() {}
    
    /**
     * Empêche la désérialisation de l'instance
     */
    public function __wakeup() {
        throw new Exception("Cannot unserialize singleton");
    }
    
    /**
     * Ferme la connexion à la base de données
     */
    public function closeConnection() {
        $this->connection = null;
    }
    
    /**
     * Teste la connexion à la base de données
     * 
     * @return bool True si connecté, false sinon
     */
    public function testConnection() {
        try {
            $stmt = $this->connection->query("SELECT 1");
            return $stmt !== false;
        } catch (PDOException $e) {
            return false;
        }
    }
    
    /**
     * Exécute une requête préparée
     * 
     * @param string $sql Requête SQL
     * @param array $params Paramètres de la requête
     * @return PDOStatement Statement exécuté
     */
    public function query($sql, $params = []) {
        try {
            $stmt = $this->connection->prepare($sql);
            $stmt->execute($params);
            return $stmt;
        } catch (PDOException $e) {
            throw new Exception("Erreur d'exécution de la requête: " . $e->getMessage());
        }
    }
    
    /**
     * Démarre une transaction
     * 
     * @return bool True si la transaction a démarré
     */
    public function beginTransaction() {
        return $this->connection->beginTransaction();
    }
    
    /**
     * Valide une transaction
     * 
     * @return bool True si la transaction a été validée
     */
    public function commit() {
        return $this->connection->commit();
    }
    
    /**
     * Annule une transaction
     * 
     * @return bool True si la transaction a été annulée
     */
    public function rollback() {
        return $this->connection->rollBack();
    }
    
    /**
     * Récupère le dernier ID inséré
     * 
     * @return string Dernier ID inséré
     */
    public function lastInsertId() {
        return $this->connection->lastInsertId();
    }
}

?>
