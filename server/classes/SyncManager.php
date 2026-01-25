<?php

class SyncManager {
    private $pdo;
    
    public function __construct($pdo) {
        $this->pdo = $pdo;
    }
    
    /**
     * Sauvegarde un shop avec gestion des conflits
     */
    public function saveShop($data) {
        try {
            // Vérifier si le shop existe déjà
            $existing = $this->getEntityById('shops', $data['id'] ?? null);
            
            if ($existing) {
                // Vérifier les conflits
                $conflict = $this->detectConflict($existing, $data);
                
                if ($conflict) {
                    // Résoudre le conflit (last modified wins)
                    $resolved = $this->resolveConflict($existing, $data);
                    return $this->updateShop($resolved);
                } else {
                    return $this->updateShop($data);
                }
            } else {
                return $this->insertShop($data);
            }
            
        } catch (Exception $e) {
            throw new Exception("Erreur sauvegarde shop: " . $e->getMessage());
        }
    }
    
    /**
     * Insère un nouveau shop
     */
    private function insertShop($data) {
        $sql = "INSERT IGNORE INTO shops (
            id,
            designation, localisation, is_principal, is_transfer_shop,
            capital_initial, 
            devise_principale, devise_secondaire,
            capital_actuel, capital_cash, capital_airtel_money, capital_mpesa, capital_orange_money,
            capital_actuel_devise2, capital_cash_devise2, capital_airtel_money_devise2, capital_mpesa_devise2, capital_orange_money_devise2,
            creances, dettes,
            last_modified_at, last_modified_by, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        
        $stmt = $this->pdo->prepare($sql);
        $result = $stmt->execute([
            $data['id'] ?? null,  // Forcer l'utilisation de l'ID de l'app
            $data['designation'] ?? '',
            $data['localisation'] ?? '',
            $data['is_principal'] ?? 0,
            $data['is_transfer_shop'] ?? 0,
            $data['capital_initial'] ?? 0,
            $data['devise_principale'] ?? 'USD',
            $data['devise_secondaire'] ?? null,
            $data['capital_actuel'] ?? 0,
            $data['capital_cash'] ?? 0,
            $data['capital_airtel_money'] ?? 0,
            $data['capital_mpesa'] ?? 0,
            $data['capital_orange_money'] ?? 0,
            $data['capital_actuel_devise2'] ?? null,
            $data['capital_cash_devise2'] ?? null,
            $data['capital_airtel_money_devise2'] ?? null,
            $data['capital_mpesa_devise2'] ?? null,
            $data['capital_orange_money_devise2'] ?? null,
            $data['creances'] ?? 0,
            $data['dettes'] ?? 0,
            $data['last_modified_at'] ?? date('Y-m-d H:i:s'),
            $data['last_modified_by'] ?? 'system',
            $data['created_at'] ?? date('Y-m-d H:i:s')
        ]);
        
        if ($result) {
            $insertId = $data['id'] ?? $this->pdo->lastInsertId();  // Utiliser l'ID de l'app
            
            // Si INSERT IGNORE a ignoré la ligne (doublon), trouver l'ID existant
            if ($insertId == 0 || $insertId === null) {
                $findStmt = $this->pdo->prepare("SELECT id FROM shops WHERE designation = ? LIMIT 1");
                $findStmt->execute([$data['designation'] ?? '']);
                $existing = $findStmt->fetch(PDO::FETCH_ASSOC);
                if ($existing) {
                    $insertId = $existing['id'];
                }
            }
            
            // Marquer comme synchronisé seulement après insertion réussie
            if ($insertId > 0) {
                // Use the client's synced_at timestamp to maintain timezone consistency
                $syncedAt = $data['synced_at'] ?? date('c'); // Use ISO 8601 format
                $updateSql = "UPDATE shops SET is_synced = 1, synced_at = ? WHERE id = ?";
                $updateStmt = $this->pdo->prepare($updateSql);
                $updateStmt->execute([$syncedAt, $insertId]);
            }
            
            return $insertId;
        }
        
        throw new Exception("Échec insertion shop");
    }
    
    /**
     * Met à jour un shop existant
     */
    private function updateShop($data) {
        $sql = "UPDATE shops SET 
            designation = ?, localisation = ?, is_principal = ?, is_transfer_shop = ?,
            capital_initial = ?,
            devise_principale = ?, devise_secondaire = ?,
            capital_actuel = ?, capital_cash = ?, capital_airtel_money = ?, capital_mpesa = ?, capital_orange_money = ?,
            capital_actuel_devise2 = ?, capital_cash_devise2 = ?, capital_airtel_money_devise2 = ?, capital_mpesa_devise2 = ?, capital_orange_money_devise2 = ?,
            creances = ?, dettes = ?,
            last_modified_at = ?, last_modified_by = ?
            WHERE id = ?";
        
        $stmt = $this->pdo->prepare($sql);
        $result = $stmt->execute([
            $data['designation'] ?? '',
            $data['localisation'] ?? '',
            $data['is_principal'] ?? 0,
            $data['is_transfer_shop'] ?? 0,
            $data['capital_initial'] ?? 0,
            $data['devise_principale'] ?? 'USD',
            $data['devise_secondaire'] ?? null,
            $data['capital_actuel'] ?? 0,
            $data['capital_cash'] ?? 0,
            $data['capital_airtel_money'] ?? 0,
            $data['capital_mpesa'] ?? 0,
            $data['capital_orange_money'] ?? 0,
            $data['capital_actuel_devise2'] ?? null,
            $data['capital_cash_devise2'] ?? null,
            $data['capital_airtel_money_devise2'] ?? null,
            $data['capital_mpesa_devise2'] ?? null,
            $data['capital_orange_money_devise2'] ?? null,
            $data['creances'] ?? 0,
            $data['dettes'] ?? 0,
            $data['last_modified_at'] ?? date('Y-m-d H:i:s'),
            $data['last_modified_by'] ?? 'system',
            $data['id']
        ]);
        
        if ($result) {
            // Marquer comme synchronisé seulement après mise à jour réussie
            // Use the client's synced_at timestamp to maintain timezone consistency
            $syncedAt = $data['synced_at'] ?? date('c'); // Use ISO 8601 format
            $updateSql = "UPDATE shops SET is_synced = 1, synced_at = ? WHERE id = ?";
            $updateStmt = $this->pdo->prepare($updateSql);
            $updateStmt->execute([$syncedAt, $data['id']]);
            
            return $data['id'];
        }
        
        throw new Exception("Échec mise à jour shop");
    }
    
    /**
     * Sauvegarde un agent avec gestion des conflits
     */
    public function saveAgent($data) {
        try {
            $existing = $this->getAgentByUsername($data['username'] ?? '');
            
            if ($existing) {
                $conflict = $this->detectConflict($existing, $data);
                if ($conflict) {
                    $resolved = $this->resolveConflict($existing, $data);
                    return $this->updateAgent($resolved);
                } else {
                    return $this->updateAgent($data);
                }
            } else {
                return $this->insertAgent($data);
            }
            
        } catch (Exception $e) {
            throw new Exception("Erreur sauvegarde agent: " . $e->getMessage());
        }
    }
    
    /**
     * Insère un nouvel agent
     */
    private function insertAgent($data) {
        $sql = "INSERT INTO agents (
            username, password, nom, shop_id, role, is_active,
            last_modified_at, last_modified_by, created_at, is_synced, synced_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        
        $stmt = $this->pdo->prepare($sql);
        $result = $stmt->execute([
            $data['username'] ?? '',
            $data['password'] ?? '',
            $data['nom'] ?? '',
            $data['shop_id'] ?? 1,
            $data['role'] ?? 'AGENT',
            $data['is_active'] ?? 1,
            $data['last_modified_at'] ?? date('c'),
            $data['last_modified_by'] ?? 'system',
            $data['created_at'] ?? date('c'),
            $data['is_synced'] ?? 1,
            $data['synced_at'] ?? date('c')
        ]);
        
        if ($result) {
            return $this->pdo->lastInsertId();
        }
        
        throw new Exception("Échec insertion agent");
    }
    
    /**
     * Met à jour un agent existant
     */
    private function updateAgent($data) {
        $sql = "UPDATE agents SET 
            password = ?, nom = ?, shop_id = ?, role = ?, is_active = ?,
            last_modified_at = ?, last_modified_by = ?, is_synced = ?, synced_at = ?
            WHERE username = ?";
        
        $stmt = $this->pdo->prepare($sql);
        $result = $stmt->execute([
            $data['password'] ?? '',
            $data['nom'] ?? '',
            $data['shop_id'] ?? 1,
            $data['role'] ?? 'AGENT',
            $data['is_active'] ?? 1,
            $data['last_modified_at'] ?? date('c'),
            $data['last_modified_by'] ?? 'system',
            $data['is_synced'] ?? 1,
            $data['synced_at'] ?? date('c'),
            $data['username']
        ]);
        
        return $result;
    }
    
    /**
     * Sauvegarde un client avec gestion des conflits
     */
    public function saveClient($data) {
        try {
            $existing = $this->getClientByPhone($data['telephone'] ?? '');
            
            if ($existing) {
                $conflict = $this->detectConflict($existing, $data);
                if ($conflict) {
                    $resolved = $this->resolveConflict($existing, $data);
                    return $this->updateClient($resolved);
                } else {
                    return $this->updateClient($data);
                }
            } else {
                return $this->insertClient($data);
            }
            
        } catch (Exception $e) {
            throw new Exception("Erreur sauvegarde client: " . $e->getMessage());
        }
    }
    
    /**
     * Insère un nouveau client
     */
    private function insertClient($data) {
        $sql = "INSERT INTO clients (
            nom, telephone, adresse, solde, shop_id, agent_id, role,
            last_modified_at, last_modified_by, created_at, is_synced, synced_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        
        $stmt = $this->pdo->prepare($sql);
        $result = $stmt->execute([
            $data['nom'] ?? '',
            $data['telephone'] ?? '',
            $data['adresse'] ?? '',
            $data['solde'] ?? 0,
            $data['shop_id'] ?? 1,
            $data['agent_id'] ?? 1,
            $data['role'] ?? 'CLIENT',
            $data['last_modified_at'] ?? date('c'),
            $data['last_modified_by'] ?? 'system',
            $data['created_at'] ?? date('c'),
            $data['is_synced'] ?? 1,
            $data['synced_at'] ?? date('c')
        ]);
        
        if ($result) {
            return $this->pdo->lastInsertId();
        }
        
        throw new Exception("Échec insertion client");
    }
    
    /**
     * Met à jour un client existant
     */
    private function updateClient($data) {
        $sql = "UPDATE clients SET 
            nom = ?, adresse = ?, solde = ?, shop_id = ?, agent_id = ?,
            last_modified_at = ?, last_modified_by = ?, is_synced = ?, synced_at = ?
            WHERE telephone = ?";
        
        $stmt = $this->pdo->prepare($sql);
        $result = $stmt->execute([
            $data['nom'] ?? '',
            $data['adresse'] ?? '',
            $data['solde'] ?? 0,
            $data['shop_id'] ?? 1,
            $data['agent_id'] ?? 1,
            $data['last_modified_at'] ?? date('c'),
            $data['last_modified_by'] ?? 'system',
            $data['is_synced'] ?? 1,
            $data['synced_at'] ?? date('c'),
            $data['telephone']
        ]);
        
        return $result;
    }
    
    /**
     * Sauvegarde une opération
     */
    public function saveOperation($data) {
        try {
            $existing = null;
            if (isset($data['reference']) && $data['reference']) {
                $existing = $this->getOperationByReference($data['reference']);
            }
            
            if ($existing) {
                $conflict = $this->detectConflict($existing, $data);
                if ($conflict) {
                    $resolved = $this->resolveConflict($existing, $data);
                    return $this->updateOperation($resolved);
                } else {
                    return $this->updateOperation($data);
                }
            } else {
                return $this->insertOperation($data);
            }
            
        } catch (Exception $e) {
            throw new Exception("Erreur sauvegarde opération: " . $e->getMessage());
        }
    }
    
    /**
     * Insère une nouvelle opération
     */
    private function insertOperation($data) {
        $sql = "INSERT INTO operations (
            type, montant_brut, montant_net, commission, client_id, shop_source_id, 
            shop_destination_id, agent_id, mode_paiement, statut, reference, notes,
            observation, billetage,  /* Added billetage column */
            last_modified_at, last_modified_by, created_at, is_synced, synced_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        
        $stmt = $this->pdo->prepare($sql);
        $result = $stmt->execute([
            $data['type'] ?? '',
            $data['montant_brut'] ?? 0,
            $data['montant_net'] ?? 0,
            $data['commission'] ?? 0,
            $data['client_id'] ?? null,
            $data['shop_source_id'] ?? 1,
            $data['shop_destination_id'] ?? null,
            $data['agent_id'] ?? 1,
            $data['mode_paiement'] ?? 'cash',
            $data['statut'] ?? 'terminee',
            $data['reference'] ?? 'OP' . time(),
            $data['notes'] ?? '',
            $data['observation'] ?? '',  /* Added observation */
            $data['billetage'] ?? null,  /* Added billetage */
            $data['last_modified_at'] ?? date('c'),
            $data['last_modified_by'] ?? 'system',
            $data['created_at'] ?? date('c'),
            $data['is_synced'] ?? 1,
            $data['synced_at'] ?? date('c')
        ]);
        
        if ($result) {
            return $this->pdo->lastInsertId();
        }
        
        throw new Exception("Échec insertion opération");
    }
    
    /**
     * Met à jour une opération existante
     */
    private function updateOperation($data) {
        $sql = "UPDATE operations SET 
            type = ?, montant_brut = ?, montant_net = ?, commission = ?, client_id = ?,
            shop_source_id = ?, shop_destination_id = ?, agent_id = ?, mode_paiement = ?,
            statut = ?, notes = ?, observation = ?, billetage = ?,  /* Added observation and billetage */
            last_modified_at = ?, last_modified_by = ?,
            is_synced = ?, synced_at = ?
            WHERE reference = ?";
        
        $stmt = $this->pdo->prepare($sql);
        $result = $stmt->execute([
            $data['type'] ?? '',
            $data['montant_brut'] ?? 0,
            $data['montant_net'] ?? 0,
            $data['commission'] ?? 0,
            $data['client_id'] ?? null,
            $data['shop_source_id'] ?? 1,
            $data['shop_destination_id'] ?? null,
            $data['agent_id'] ?? 1,
            $data['mode_paiement'] ?? 'cash',
            $data['statut'] ?? 'terminee',
            $data['notes'] ?? '',
            $data['observation'] ?? '',  /* Added observation */
            $data['billetage'] ?? null,  /* Added billetage */
            $data['last_modified_at'] ?? date('c'),
            $data['last_modified_by'] ?? 'system',
            $data['is_synced'] ?? 1,
            $data['synced_at'] ?? date('c'),
            $data['reference']
        ]);
        
        return $result;
    }
    
    /**
     * Récupère une entité par ID
     */
    private function getEntityById($table, $id) {
        if (!$id) return null;
        
        $sql = "SELECT * FROM $table WHERE id = ?";
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute([$id]);
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    /**
     * Récupère un agent par username
     */
    private function getAgentByUsername($username) {
        if (!$username) return null;
        
        $sql = "SELECT * FROM agents WHERE username = ?";
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute([$username]);
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    /**
     * Récupère un client par téléphone
     */
    private function getClientByPhone($phone) {
        if (!$phone) return null;
        
        $sql = "SELECT * FROM clients WHERE telephone = ?";
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute([$phone]);
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    /**
     * Récupère une opération par référence
     */
    private function getOperationByReference($reference) {
        if (!$reference) return null;
        
        $sql = "SELECT * FROM operations WHERE reference = ?";
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute([$reference]);
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    /**
     * Détecte un conflit entre données locales et distantes
     */
    private function detectConflict($existing, $new) {
        // Use last_modified_at column
        $timestampColumn = 'last_modified_at';
        
        $existingTime = strtotime($existing[$timestampColumn] ?? '');
        $newTime = strtotime($new[$timestampColumn] ?? '');
        
        // Conflit si les timestamps sont différents
        return $existingTime !== $newTime;
    }
    
    /**
     * Sauvegarde une transaction virtuelle avec gestion des conflits
     */
    public function saveVirtualTransaction($data) {
        try {
            // Log incoming data for debugging
            error_log("SyncManager::saveVirtualTransaction - Data: " . json_encode(array_slice($data, 0, 10)));
            
            // Validation basique
            if (empty($data['reference'])) {
                throw new Exception('Référence manquante pour la transaction virtuelle');
            }
            
            // Vérifier si la transaction existe déjà par reference
            $stmt = $this->pdo->prepare("SELECT * FROM virtual_transactions WHERE reference = ? LIMIT 1");
            $stmt->execute([$data['reference'] ?? '']);
            $existing = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($existing) {
                // UPDATE
                $conflict = $this->detectConflict($existing, $data);
                if ($conflict) {
                    $resolved = $this->resolveConflict($existing, $data);
                    return $this->updateVirtualTransaction($resolved);
                } else {
                    return $this->updateVirtualTransaction($data);
                }
            } else {
                // INSERT
                return $this->insertVirtualTransaction($data);
            }
            
        } catch (Exception $e) {
            error_log("Erreur dans saveVirtualTransaction: " . $e->getMessage());
            throw new Exception("Erreur sauvegarde virtual_transaction: " . $e->getMessage());
        }
    }
    
    /**
     * Insère une nouvelle transaction virtuelle
     */
    private function insertVirtualTransaction($data) {
        try {
            $sql = "INSERT INTO virtual_transactions (
                reference, montant_virtuel, frais, montant_cash, devise,
                sim_numero, shop_id, shop_designation,
                agent_id, agent_username,
                client_nom, client_telephone,
                statut, date_enregistrement, date_validation, notes,
                last_modified_at, last_modified_by, is_administrative
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
            
            $stmt = $this->pdo->prepare($sql);
            $result = $stmt->execute([
                $data['reference'],
                $data['montant_virtuel'],
                $data['frais'] ?? 0,
                $data['montant_cash'],
                $data['devise'] ?? 'USD',
                $data['sim_numero'],
                $data['shop_id'],
                $data['shop_designation'] ?? null,
                $data['agent_id'],
                $data['agent_username'] ?? null,
                $data['client_nom'] ?? null,
                $data['client_telephone'] ?? null,
                $data['statut'] ?? 'enAttente',
                $data['date_enregistrement'] ?? date('Y-m-d H:i:s'),
                $data['date_validation'] ?? null,
                $data['notes'] ?? null,
                $data['last_modified_at'] ?? date('Y-m-d H:i:s'),
                $data['last_modified_by'] ?? 'system',
                isset($data['is_administrative']) ? (int)$data['is_administrative'] : 0
            ]);
            
            if ($result) {
                $insertId = $this->pdo->lastInsertId();
                
                // Marquer comme synchronisé seulement après insertion réussie
                if ($insertId > 0) {
                    $syncedAt = $data['synced_at'] ?? date('c');
                    $updateSql = "UPDATE virtual_transactions SET is_synced = 1, synced_at = ? WHERE id = ?";
                    $updateStmt = $this->pdo->prepare($updateSql);
                    $updateStmt->execute([$syncedAt, $insertId]);
                }
                
                return $insertId;
            }
            
            throw new Exception("Échec insertion virtual_transaction - aucune ligne insérée");
            
        } catch (PDOException $e) {
            error_log("PDOException in insertVirtualTransaction: " . $e->getMessage());
            error_log("Data: " . json_encode(array_slice($data, 0, 10)));
            throw new Exception("Erreur base de données: " . $e->getMessage());
        } catch (Exception $e) {
            error_log("Exception in insertVirtualTransaction: " . $e->getMessage());
            throw new Exception("Erreur insertion virtual_transaction: " . $e->getMessage());
        }
    }
    
    /**
     * Met à jour une transaction virtuelle existante
     */
    private function updateVirtualTransaction($data) {
        try {
            $sql = "UPDATE virtual_transactions SET
                montant_virtuel = ?,
                frais = ?,
                montant_cash = ?,
                devise = ?,
                sim_numero = ?,
                shop_id = ?,
                shop_designation = ?,
                agent_id = ?,
                agent_username = ?,
                client_nom = ?,
                client_telephone = ?,
                statut = ?,
                date_enregistrement = ?,
                date_validation = ?,
                notes = ?,
                last_modified_at = ?,
                last_modified_by = ?,
                is_administrative = ?
            WHERE reference = ?";
            
            $stmt = $this->pdo->prepare($sql);
            $result = $stmt->execute([
                $data['montant_virtuel'],
                $data['frais'] ?? 0,
                $data['montant_cash'],
                $data['devise'] ?? 'USD',
                $data['sim_numero'],
                $data['shop_id'],
                $data['shop_designation'] ?? null,
                $data['agent_id'],
                $data['agent_username'] ?? null,
                $data['client_nom'] ?? null,
                $data['client_telephone'] ?? null,
                $data['statut'] ?? 'enAttente',
                $data['date_enregistrement'] ?? date('Y-m-d H:i:s'),
                $data['date_validation'] ?? null,
                $data['notes'] ?? null,
                $data['last_modified_at'] ?? date('Y-m-d H:i:s'),
                $data['last_modified_by'] ?? 'system',
                isset($data['is_administrative']) ? (int)$data['is_administrative'] : 0,
                $data['reference']
            ]);
            
            if ($result) {
                // Récupérer l'ID de la transaction
                $stmt = $this->pdo->prepare("SELECT id FROM virtual_transactions WHERE reference = ?");
                $stmt->execute([$data['reference']]);
                $row = $stmt->fetch(PDO::FETCH_ASSOC);
                
                if ($row) {
                    // Marquer comme synchronisé seulement après mise à jour réussie
                    $syncedAt = $data['synced_at'] ?? date('c');
                    $updateSql = "UPDATE virtual_transactions SET is_synced = 1, synced_at = ? WHERE id = ?";
                    $updateStmt = $this->pdo->prepare($updateSql);
                    $updateStmt->execute([$syncedAt, $row['id']]);
                    
                    return $row['id'];
                }
            }
            
            throw new Exception("Échec mise à jour virtual_transaction - aucune ligne modifiée");
            
        } catch (PDOException $e) {
            error_log("PDOException in updateVirtualTransaction: " . $e->getMessage());
            error_log("Data: " . json_encode(array_slice($data, 0, 10)));
            throw new Exception("Erreur base de données: " . $e->getMessage());
        } catch (Exception $e) {
            error_log("Exception in updateVirtualTransaction: " . $e->getMessage());
            throw new Exception("Erreur mise à jour virtual_transaction: " . $e->getMessage());
        }
    }
    
    /**
     * Résout un conflit (last modified wins)
     */
    private function resolveConflict($existing, $new) {
        // Use last_modified_at column
        $timestampColumn = 'last_modified_at';
        
        $existingTime = strtotime($existing[$timestampColumn] ?? '');
        $newTime = strtotime($new[$timestampColumn] ?? '');
        
        // Retourner la version la plus récente
        return $newTime > $existingTime ? $new : $existing;
    }
    
    /**
     * Récupère toutes les entités d'une table
     */
    public function getAllEntities($table, $since = null) {
        // Use last_modified_at for all tables
        $timestampColumn = 'last_modified_at';
        
        $sql = "SELECT * FROM $table WHERE 1=1";
        $params = [];
        
        if ($since) {
            $sql .= " AND $timestampColumn > ?";
            $params[] = $since;
        }
        
        $sql .= " ORDER BY $timestampColumn DESC";
        
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
?>
