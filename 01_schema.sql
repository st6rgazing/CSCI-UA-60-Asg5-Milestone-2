DROP DATABASE IF EXISTS cloudnine;
CREATE DATABASE cloudnine;
USE cloudnine;

CREATE TABLE region (
  region_id INT PRIMARY KEY,
  region_name VARCHAR(50) NOT NULL UNIQUE,
  country VARCHAR(50) NOT NULL,
  regulatory_regime VARCHAR(50) NOT NULL
);

CREATE TABLE availability_zone (
  zone_id INT PRIMARY KEY,
  region_id INT NOT NULL,
  zone_code VARCHAR(10) NOT NULL,
  redundancy_level VARCHAR(20) NOT NULL CHECK (redundancy_level IN ('standard','high','critical')),
  UNIQUE (region_id, zone_code),
  FOREIGN KEY (region_id) REFERENCES region (region_id)
);

CREATE TABLE data_center (
  dc_id INT PRIMARY KEY,
  zone_id INT NOT NULL,
  dc_name VARCHAR(50) NOT NULL UNIQUE,
  city VARCHAR(50) NOT NULL,
  opened_date DATE NOT NULL,
  FOREIGN KEY (zone_id) REFERENCES availability_zone (zone_id)
);

CREATE TABLE staff (
  staff_id INT PRIMARY KEY,
  first_name VARCHAR(40) NOT NULL,
  last_name VARCHAR(40) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE,
  staff_role VARCHAR(20) NOT NULL CHECK (staff_role IN ('account_manager','engineer','technician','billing','support')),
  home_dc_id INT NOT NULL,
  FOREIGN KEY (home_dc_id) REFERENCES data_center (dc_id)
);

CREATE TABLE resource_type (
  type_id INT PRIMARY KEY,
  type_name VARCHAR(50) NOT NULL UNIQUE,
  category VARCHAR(20) NOT NULL CHECK (category IN ('compute','gpu','storage','network','bare_metal')),
  performance_tier VARCHAR(20) NOT NULL CHECK (performance_tier IN ('standard','performance','premium')),
  vcpus INT NOT NULL DEFAULT 0 CHECK (vcpus >= 0),
  memory_gb INT NOT NULL DEFAULT 0 CHECK (memory_gb >= 0),
  storage_gb INT NOT NULL DEFAULT 0 CHECK (storage_gb >= 0),
  gpu_count INT NOT NULL DEFAULT 0 CHECK (gpu_count >= 0),
  is_reassignable BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE resource_group (
  group_id INT PRIMARY KEY,
  group_name VARCHAR(50) NOT NULL UNIQUE,
  group_type VARCHAR(20) NOT NULL CHECK (group_type IN ('cluster','rack','pool','failover_pair')),
  spans_multiple_zones BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE resource (
  resource_id INT PRIMARY KEY,
  dc_id INT NOT NULL,
  type_id INT NOT NULL,
  group_id INT,
  resource_code VARCHAR(30) NOT NULL,
  purpose VARCHAR(20) NOT NULL CHECK (purpose IN ('production','spare','test')),
  install_date DATE NOT NULL,
  UNIQUE (dc_id, resource_code),
  FOREIGN KEY (dc_id) REFERENCES data_center (dc_id),
  FOREIGN KEY (type_id) REFERENCES resource_type (type_id),
  FOREIGN KEY (group_id) REFERENCES resource_group (group_id)
);

CREATE TABLE resource_status_log (
  status_log_id INT PRIMARY KEY,
  resource_id INT NOT NULL,
  staff_id INT NOT NULL,
  status VARCHAR(20) NOT NULL CHECK (status IN ('maintenance','outage','degraded','retired')),
  is_scheduled BOOLEAN NOT NULL,
  reason VARCHAR(200),
  start_time DATETIME NOT NULL,
  end_time DATETIME,
  CHECK (end_time > start_time),
  FOREIGN KEY (resource_id) REFERENCES resource (resource_id),
  FOREIGN KEY (staff_id) REFERENCES staff (staff_id)
);

CREATE TABLE client (
  client_id INT PRIMARY KEY,
  client_name VARCHAR(100) NOT NULL UNIQUE,
  client_type VARCHAR(20) NOT NULL CHECK (client_type IN ('enterprise','government','startup','academic','nonprofit')),
  industry VARCHAR(20) NOT NULL,
  qualification_level VARCHAR(20) NOT NULL CHECK (qualification_level IN ('standard','silver','gold','platinum')),
  contract_type VARCHAR(20) NOT NULL CHECK (contract_type IN ('pay_as_you_go','annual','multi_year')),
  discount_pct DECIMAL(5,2) NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 50),
  max_priority_level INT NOT NULL CHECK (max_priority_level BETWEEN 1 AND 5),
  is_confidential BOOLEAN NOT NULL DEFAULT FALSE,
  account_manager_id INT NOT NULL,
  FOREIGN KEY (account_manager_id) REFERENCES staff (staff_id)
);

CREATE TABLE team (
  team_id INT PRIMARY KEY,
  client_id INT NOT NULL,
  team_name VARCHAR(50) NOT NULL,
  UNIQUE (client_id, team_name),
  FOREIGN KEY (client_id) REFERENCES client (client_id)
);

CREATE TABLE client_user (
  user_id INT PRIMARY KEY,
  team_id INT NOT NULL,
  first_name VARCHAR(40) NOT NULL,
  last_name VARCHAR(40) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE,
  phone VARCHAR(20),
  is_emergency_contact BOOLEAN NOT NULL DEFAULT FALSE,
  FOREIGN KEY (team_id) REFERENCES team (team_id)
);

CREATE TABLE billing_account (
  billing_account_id INT PRIMARY KEY,
  client_id INT NOT NULL,
  account_name VARCHAR(60) NOT NULL,
  billing_email VARCHAR(100) NOT NULL,
  UNIQUE (client_id, account_name),
  FOREIGN KEY (client_id) REFERENCES client (client_id)
);

CREATE TABLE project (
  project_id INT PRIMARY KEY,
  team_id INT NOT NULL,
  project_name VARCHAR(60) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE,
  CHECK (end_date >= start_date),
  FOREIGN KEY (team_id) REFERENCES team (team_id)
);

CREATE TABLE cost_allocation_rule (
  rule_id INT PRIMARY KEY,
  project_id INT NOT NULL,
  billing_account_id INT NOT NULL,
  share_pct DECIMAL(5,2) NOT NULL CHECK (share_pct > 0 AND share_pct <= 100),
  effective_from DATE NOT NULL,
  effective_to DATE,
  CHECK (effective_to >= effective_from),
  FOREIGN KEY (project_id) REFERENCES project (project_id),
  FOREIGN KEY (billing_account_id) REFERENCES billing_account (billing_account_id)
);

CREATE TABLE service (
  service_id INT PRIMARY KEY,
  service_name VARCHAR(50) NOT NULL UNIQUE,
  category VARCHAR(20) NOT NULL CHECK (category IN ('network','storage','support','security','backup')),
  billing_unit VARCHAR(20) NOT NULL,
  unit_price DECIMAL(8,4) NOT NULL CHECK (unit_price >= 0)
);

CREATE TABLE rate (
  rate_id INT PRIMARY KEY,
  type_id INT NOT NULL,
  pricing_model VARCHAR(20) NOT NULL CHECK (pricing_model IN ('on_demand','reserved','peak','off_peak')),
  price_per_hour DECIMAL(8,4) NOT NULL CHECK (price_per_hour >= 0),
  start_hour INT CHECK (start_hour BETWEEN 0 AND 23),
  end_hour INT CHECK (end_hour BETWEEN 0 AND 23),
  min_hours_per_month INT,
  effective_from DATE NOT NULL,
  effective_to DATE,
  CHECK (effective_to >= effective_from),
  CHECK ((start_hour IS NULL) = (end_hour IS NULL)),
  FOREIGN KEY (type_id) REFERENCES resource_type (type_id)
);

CREATE TABLE reservation (
  reservation_id INT PRIMARY KEY,
  project_id INT NOT NULL,
  region_id INT NOT NULL,
  user_id INT NOT NULL,
  type_id INT NOT NULL,
  quantity INT NOT NULL CHECK (quantity > 0),
  zone_policy VARCHAR(20) NOT NULL CHECK (zone_policy IN ('single_zone','multi_zone','any')),
  start_time DATETIME NOT NULL,
  end_time DATETIME NOT NULL,
  status VARCHAR(20) NOT NULL CHECK (status IN ('pending','confirmed','active','completed','cancelled')),
  deposit_amount DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (deposit_amount >= 0),
  created_at DATETIME NOT NULL,
  CHECK (end_time > start_time),
  FOREIGN KEY (project_id) REFERENCES project (project_id),
  FOREIGN KEY (region_id) REFERENCES region (region_id),
  FOREIGN KEY (user_id) REFERENCES client_user (user_id),
  FOREIGN KEY (type_id) REFERENCES resource_type (type_id)
);

CREATE TABLE reservation_change (
  change_id INT PRIMARY KEY,
  reservation_id INT NOT NULL,
  staff_id INT NOT NULL,
  change_type VARCHAR(20) NOT NULL CHECK (change_type IN ('extend','shorten','add_capacity','reduce_capacity','change_type','cancel')),
  old_value VARCHAR(100),
  new_value VARCHAR(100),
  status VARCHAR(20) NOT NULL CHECK (status IN ('requested','approved','rejected')),
  extra_charge DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (extra_charge >= 0),
  requested_at DATETIME NOT NULL,
  FOREIGN KEY (reservation_id) REFERENCES reservation (reservation_id),
  FOREIGN KEY (staff_id) REFERENCES staff (staff_id)
);

CREATE TABLE deployment (
  deployment_id INT PRIMARY KEY,
  reservation_id INT NOT NULL,
  deployment_name VARCHAR(60) NOT NULL,
  scaling_mode VARCHAR(10) NOT NULL CHECK (scaling_mode IN ('fixed','auto','manual')),
  priority_level INT NOT NULL CHECK (priority_level BETWEEN 1 AND 5),
  is_confidential BOOLEAN NOT NULL DEFAULT FALSE,
  created_at DATETIME NOT NULL,
  FOREIGN KEY (reservation_id) REFERENCES reservation (reservation_id)
);

CREATE TABLE deployment_resource (
  deployment_resource_id INT PRIMARY KEY,
  deployment_id INT NOT NULL,
  resource_id INT NOT NULL,
  added_at DATETIME NOT NULL,
  removed_at DATETIME,
  reason VARCHAR(20) NOT NULL CHECK (reason IN ('initial','scale_up','replacement','migration')),
  CHECK (removed_at > added_at),
  FOREIGN KEY (deployment_id) REFERENCES deployment (deployment_id),
  FOREIGN KEY (resource_id) REFERENCES resource (resource_id)
);

CREATE TABLE resource_assignment (
  assignment_id INT PRIMARY KEY,
  reservation_id INT NOT NULL,
  resource_id INT,
  group_id INT,
  staff_id INT NOT NULL,
  assigned_from DATETIME NOT NULL,
  assigned_to DATETIME NOT NULL,
  replaces_assignment_id INT,
  reason VARCHAR(20) NOT NULL CHECK (reason IN ('initial','failover','maintenance','upgrade','capacity_add')),
  CHECK (assigned_to > assigned_from),
  CHECK ((resource_id IS NULL) <> (group_id IS NULL)),
  CHECK (replaces_assignment_id <> assignment_id),
  FOREIGN KEY (reservation_id) REFERENCES reservation (reservation_id),
  FOREIGN KEY (resource_id) REFERENCES resource (resource_id),
  FOREIGN KEY (group_id) REFERENCES resource_group (group_id),
  FOREIGN KEY (staff_id) REFERENCES staff (staff_id),
  FOREIGN KEY (replaces_assignment_id) REFERENCES resource_assignment (assignment_id)
);

CREATE TABLE deployment_event (
  event_id INT PRIMARY KEY,
  deployment_id INT NOT NULL,
  user_id INT,
  staff_id INT,
  event_type VARCHAR(20) NOT NULL CHECK (event_type IN ('create','start','stop','scale_up','scale_down','config_change','access','restart','failover','delete')),
  auth_method VARCHAR(20) NOT NULL CHECK (auth_method IN ('password','mfa','sso','api_key','staff_console')),
  event_time DATETIME NOT NULL,
  notes VARCHAR(200),
  CHECK ((user_id IS NULL) <> (staff_id IS NULL)),
  FOREIGN KEY (deployment_id) REFERENCES deployment (deployment_id),
  FOREIGN KEY (user_id) REFERENCES client_user (user_id),
  FOREIGN KEY (staff_id) REFERENCES staff (staff_id)
);

CREATE TABLE usage_record (
  usage_id INT PRIMARY KEY,
  deployment_id INT NOT NULL,
  resource_id INT,
  rate_id INT,
  service_id INT,
  period_start DATETIME NOT NULL,
  period_end DATETIME NOT NULL,
  quantity DECIMAL(12,3) NOT NULL CHECK (quantity >= 0),
  is_estimate BOOLEAN NOT NULL DEFAULT FALSE,
  amount DECIMAL(10,2) NOT NULL,
  charge_status VARCHAR(20) NOT NULL CHECK (charge_status IN ('pending','billed','disputed','waived')),
  recorded_at DATETIME NOT NULL,
  CHECK ((resource_id IS NOT NULL AND rate_id IS NOT NULL AND service_id IS NULL)
      OR (resource_id IS NULL AND rate_id IS NULL AND service_id IS NOT NULL)),
  CHECK (period_end > period_start),
  FOREIGN KEY (deployment_id) REFERENCES deployment (deployment_id),
  FOREIGN KEY (resource_id) REFERENCES resource (resource_id),
  FOREIGN KEY (rate_id) REFERENCES rate (rate_id),
  FOREIGN KEY (service_id) REFERENCES service (service_id)
);

CREATE TABLE adjustment (
  adjustment_id INT PRIMARY KEY,
  deployment_id INT NOT NULL,
  staff_id INT NOT NULL,
  assignment_id INT,
  adjustment_type VARCHAR(20) NOT NULL CHECK (adjustment_type IN ('sla_credit','goodwill_credit','change_fee','correction','manual_charge')),
  reason VARCHAR(30) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  created_at DATETIME NOT NULL,
  FOREIGN KEY (deployment_id) REFERENCES deployment (deployment_id),
  FOREIGN KEY (staff_id) REFERENCES staff (staff_id),
  FOREIGN KEY (assignment_id) REFERENCES resource_assignment (assignment_id)
);

CREATE TABLE invoice (
  invoice_id INT PRIMARY KEY,
  billing_account_id INT NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  due_date DATE NOT NULL,
  total_amount DECIMAL(12,2) NOT NULL,
  amount_paid DECIMAL(12,2) NOT NULL DEFAULT 0,
  paid_date DATE,
  status VARCHAR(20) NOT NULL CHECK (status IN ('issued','paid','partial','overdue')),
  UNIQUE (billing_account_id, period_start),
  CHECK (period_end >= period_start AND due_date >= period_end),
  CHECK (amount_paid >= 0 AND amount_paid <= total_amount),
  FOREIGN KEY (billing_account_id) REFERENCES billing_account (billing_account_id)
);

CREATE VIEW deployment_owner AS
SELECT d.deployment_id, r.reservation_id, r.project_id, r.region_id, t.client_id
FROM deployment d
JOIN reservation r ON r.reservation_id = d.reservation_id
JOIN project p ON p.project_id = r.project_id
JOIN team t ON t.team_id = p.team_id;
