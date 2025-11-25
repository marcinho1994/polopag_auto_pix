# canary_auto_pix
```markdown
# Works with PIX from: https://polopag.com -> DISCORD: marcinho1994#8446
# First PIX Project to work! Need help installing? -> DISCORD: marcinho1994#8446

## Instructions for Linux Machines
```
0. **Verify if pip is installed**
  ```sh
sudo apt install python3-pip
  ```

### For Newer Linux Machines

1. **Update package lists for upgrades and new package installations:**
  ```sh
  sudo apt update
  ```

2. **Install MySQL connector for Python:**
  ```sh
  # Try Install with pip
  python3 -m pip install mysql-connector-python
  # If it fails (e.g., due to a managed environment error), use APT instead.
  sudo apt install python3-mysql.connector
  ```
  
### For Older Linux Machines
1. **Update package lists for upgrades and new package installations:**
  ```sh
  sudo apt update
  ```

2. **Install Python 3.7:**
  ```sh
  sudo apt install python3.7
  ```

3. **Verify Python 3.7 installation:**
  ```sh
  python3.7 -V
  ```

4. **Verify pip for Python 3.7 installation (Install pip for Python 3.7 if not already installed):**
  ```sh
  pip3.7 -V
  python3.7 -m pip install --upgrade pip
  ```

6. **Install MySQL connector for Python 3.7:**
  ```sh
  python3.7 -m pip install mysql-connector-python
  ```

7. **Note:** If your machine is old, remember to change `python3` to `python3.7` in the `pix_class` script.

## SQL Statement to Create Table

Use the following SQL statement to create the `polopag_transacoes` table:
```sql
CREATE TABLE `polopag_transacoes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) NOT NULL,
  `reference` varchar(255) DEFAULT NULL,
  `type` varchar(50) DEFAULT NULL,
  `txid` varchar(255) NOT NULL,
  `internalId` varchar(255) NOT NULL,
  `base64` mediumtext DEFAULT NULL,
  `copia_e_cola` mediumtext DEFAULT NULL,
  `price` decimal(10,2) DEFAULT NULL,
  `points` int(11) DEFAULT NULL,
  `coins_table` varchar(255) DEFAULT NULL,
  `status` varchar(50) DEFAULT NULL,
  `expires_at` datetime DEFAULT NULL,
  `origin` enum('game', 'site') NOT NULL DEFAULT 'site',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
```


## File Configuration

1. **Edit `pix_class.lua`:** Customize the file with your preferences and `api_key`.

2. **Place `polopag.py`:** Ensure `polopag.py` is in the main directory alongside `config.lua`.  
   If it doesn't work, you may try using `polopag_alternative_for_mariadb.py.dist` instead.

3. **Place `polopag_webhook.php`:** Ensure `polopag_webhook.php` is in the main directory of your site alongside `index.php`. This file is necessary to both PIX works (game and site).

4. **Place ALL SITE FILES in the root folder of your website.**
   - These files are essential for generating PIX transactions and checking their status.

5. **Edit `polopag_config.php`:**
   - This file contains important configuration settings for your PIX integration. Ensure that you configure the file correctly by adding your API keys, database connection details, and any other necessary parameters.
   - Example settings include API credentials, PIX URLs, and database credentials.

6. **Integration Steps:**
*   - `callpixgenerator.html`: This file is an example to be used to trigger the PIX generation process from the web interface. You can integrate on you site and need to edit the account_name value.*

1. **Final Notes:**
   - Ensure that all files are properly configured with your specific server settings and that the appropriate permissions are granted for PHP and Python scripts to execute.
