USE cloudnine;

SELECT g.region_name,
       COUNT(DISTINCT o.client_id) AS clients,
       ROUND(SUM(CASE WHEN u.period_start < '2026-04-01' AND u.charge_status = 'billed' THEN u.amount ELSE 0 END), 2) AS q1_billed,
       ROUND(SUM(CASE WHEN u.period_start >= '2026-04-01' AND u.charge_status = 'billed' THEN u.amount ELSE 0 END), 2) AS q2_billed,
       ROUND(SUM(CASE WHEN u.period_start >= '2026-04-01' AND u.is_estimate = TRUE THEN u.amount ELSE 0 END), 2) AS q2_estimated
FROM usage_record u
JOIN deployment_owner o ON o.deployment_id = u.deployment_id
JOIN region g ON g.region_id = o.region_id
WHERE u.period_start >= '2026-01-01' AND u.period_start < '2026-07-01'
GROUP BY g.region_name
ORDER BY q2_billed DESC;

SELECT DATE_FORMAT(u.period_start, '%Y-%m') AS month,
       ROUND(SUM(CASE WHEN u.charge_status = 'billed' THEN u.amount ELSE 0 END), 0) AS billed,
       ROUND(SUM(CASE WHEN u.is_estimate = TRUE THEN u.amount ELSE 0 END), 0) AS estimated,
       ROUND(SUM(CASE WHEN rt.category = 'gpu' THEN u.amount ELSE 0 END), 0) AS gpu,
       ROUND(100.0 * SUM(CASE WHEN rt.category = 'gpu' THEN u.amount ELSE 0 END) / SUM(u.amount), 1) AS gpu_pct
FROM usage_record u
LEFT JOIN rate ra ON ra.rate_id = u.rate_id
LEFT JOIN resource_type rt ON rt.type_id = ra.type_id
WHERE u.period_start >= '2026-01-01' AND u.period_start < '2026-07-01'
  AND (u.charge_status = 'billed' OR u.is_estimate = TRUE)
GROUP BY month
ORDER BY month;

SELECT c.client_name,
       CONCAT(s.first_name, ' ', s.last_name) AS account_manager,
       c.discount_pct,
       ROUND(SUM(u.amount) * (1 - c.discount_pct / 100.0), 0) AS net_billed_jan_may
FROM usage_record u
JOIN deployment_owner o ON o.deployment_id = u.deployment_id
JOIN client c ON c.client_id = o.client_id
JOIN staff s ON s.staff_id = c.account_manager_id
WHERE u.charge_status = 'billed'
  AND u.period_start >= '2026-01-01' AND u.period_start < '2026-06-01'
GROUP BY c.client_id, c.client_name, s.first_name, s.last_name, c.discount_pct
ORDER BY net_billed_jan_may DESC;

SELECT dc.dc_name,
       COUNT(DISTINCT s.resource_id) AS resources,
       ROUND(100.0 * COALESCE(SUM(TIMESTAMPDIFF(SECOND, GREATEST(ra.assigned_from, '2026-04-01 00:00:00'),
                                                       LEAST(ra.assigned_to, '2026-07-01 00:00:00'))), 0) / 3600.0
             / (COUNT(DISTINCT s.resource_id) * 2184), 1) AS reserved_pct
FROM data_center dc
JOIN resource s ON s.dc_id = dc.dc_id
LEFT JOIN resource_assignment ra ON ra.resource_id = s.resource_id
     AND ra.assigned_from < '2026-07-01' AND ra.assigned_to > '2026-04-01'
GROUP BY dc.dc_name
ORDER BY reserved_pct DESC, dc.dc_name;

SELECT dc.dc_name,
       COUNT(*) AS outages,
       ROUND(SUM(TIMESTAMPDIFF(MINUTE, l.start_time, l.end_time)) / 60.0, 1) AS outage_hours,
       ROUND(AVG(TIMESTAMPDIFF(MINUTE, l.start_time, l.end_time)), 0) AS avg_repair_minutes
FROM resource_status_log l
JOIN resource s ON s.resource_id = l.resource_id
JOIN data_center dc ON dc.dc_id = s.dc_id
WHERE l.status = 'outage'
  AND l.start_time >= '2026-01-01' AND l.start_time < '2026-07-01'
GROUP BY dc.dc_name
ORDER BY outages DESC, dc.dc_name;

SELECT rt.category,
       COUNT(*) AS failovers,
       ROUND(AVG(TIMESTAMPDIFF(MINUTE, ra.assigned_from, dr.added_at)), 0) AS avg_recovery_minutes,
       MAX(TIMESTAMPDIFF(MINUTE, ra.assigned_from, dr.added_at)) AS worst_recovery_minutes
FROM resource_assignment ra
JOIN resource s ON s.resource_id = ra.resource_id
JOIN resource_type rt ON rt.type_id = s.type_id
JOIN deployment_resource dr ON dr.resource_id = ra.resource_id
     AND dr.reason = 'replacement'
     AND dr.added_at >= ra.assigned_from AND dr.added_at < ra.assigned_to
JOIN deployment d ON d.deployment_id = dr.deployment_id
     AND d.reservation_id = ra.reservation_id
WHERE ra.reason = 'failover'
GROUP BY rt.category
ORDER BY failovers DESC;

SELECT c.client_name,
       c.qualification_level AS tier,
       COUNT(*) AS sla_credits,
       -SUM(a.amount) AS credit_total
FROM adjustment a
JOIN deployment_owner o ON o.deployment_id = a.deployment_id
JOIN client c ON c.client_id = o.client_id
WHERE a.adjustment_type = 'sla_credit'
GROUP BY c.client_name, c.qualification_level
ORDER BY credit_total DESC;

SELECT c.client_name,
       COUNT(*) AS unpaid_invoices,
       SUM(i.total_amount - i.amount_paid) AS owed,
       SUM(CASE WHEN i.due_date < '2026-07-15' THEN i.total_amount - i.amount_paid ELSE 0 END) AS past_due,
       GREATEST(0, MAX(DATEDIFF('2026-07-15', i.due_date))) AS oldest_days_past_due
FROM invoice i
JOIN billing_account b ON b.billing_account_id = i.billing_account_id
JOIN client c ON c.client_id = b.client_id
WHERE i.status <> 'paid'
GROUP BY c.client_name
ORDER BY past_due DESC, owed DESC;

SELECT CASE WHEN u.period_start < '2026-04-01' THEN 'Q1' ELSE 'Q2' END AS quarter,
       ra.pricing_model,
       ROUND(SUM(u.quantity), 0) AS gpu_node_hours,
       ROUND(SUM(u.quantity * rt.gpu_count), 0) AS gpu_hours,
       ROUND(SUM(u.amount), 2) AS charges
FROM usage_record u
JOIN rate ra ON ra.rate_id = u.rate_id
JOIN resource_type rt ON rt.type_id = ra.type_id
WHERE rt.category = 'gpu' AND u.charge_status <> 'waived'
  AND u.period_start >= '2026-01-01' AND u.period_start < '2026-07-01'
GROUP BY quarter, ra.pricing_model
ORDER BY quarter, ra.pricing_model;

SELECT c.client_type,
       COUNT(*) AS reservations,
       SUM(r.status = 'cancelled') AS cancelled,
       SUM(EXISTS (SELECT 1 FROM reservation_change rc
                   WHERE rc.reservation_id = r.reservation_id AND rc.new_value LIKE '%no capacity%')) AS lost_to_capacity,
       ROUND(AVG(DATEDIFF(r.start_time, r.created_at)), 1) AS avg_lead_days,
       SUM(r.deposit_amount) AS deposits
FROM reservation r
JOIN project p ON p.project_id = r.project_id
JOIN team t ON t.team_id = p.team_id
JOIN client c ON c.client_id = t.client_id
GROUP BY c.client_type
ORDER BY reservations DESC;

SELECT b.billing_account_id,
       b.account_name,
       ROUND(SUM(u.amount * car.share_pct / 100.0), 2) AS q2_allocated_usage
FROM usage_record u
JOIN deployment_owner o ON o.deployment_id = u.deployment_id
JOIN cost_allocation_rule car ON car.project_id = o.project_id
     AND DATE(u.period_start) BETWEEN car.effective_from AND COALESCE(car.effective_to, '2999-12-31')
JOIN billing_account b ON b.billing_account_id = car.billing_account_id
WHERE u.period_start >= '2026-04-01' AND u.period_start < '2026-07-01'
  AND u.charge_status = 'billed'
GROUP BY b.billing_account_id, b.account_name
ORDER BY q2_allocated_usage DESC, b.billing_account_id;

SELECT DATE_FORMAT(period_start, '%Y-%m') AS month,
       COUNT(*) AS invoices,
       SUM(total_amount) AS invoiced,
       SUM(amount_paid) AS collected,
       ROUND(100.0 * SUM(amount_paid) / SUM(total_amount), 1) AS collected_pct
FROM invoice
WHERE period_start >= '2026-01-01' AND period_start < '2026-07-01'
GROUP BY month
ORDER BY month;

SELECT c.client_name,
       COUNT(*) AS actions,
       SUM(e.auth_method = 'password') AS password_actions,
       ROUND(100.0 * SUM(e.auth_method = 'password') / COUNT(*), 1) AS password_pct
FROM deployment_event e
JOIN deployment d ON d.deployment_id = e.deployment_id
JOIN client_user cu ON cu.user_id = e.user_id
JOIN team t ON t.team_id = cu.team_id
JOIN client c ON c.client_id = t.client_id
WHERE d.is_confidential = TRUE
  AND e.event_time >= '2026-01-01' AND e.event_time < '2026-07-01'
GROUP BY c.client_name
ORDER BY password_pct DESC, c.client_name;

SELECT CONCAT(s.first_name, ' ', s.last_name) AS staff_member,
       dc.dc_name AS home_dc,
       COUNT(*) AS incidents_handled
FROM resource_status_log l
JOIN staff s ON s.staff_id = l.staff_id
JOIN data_center dc ON dc.dc_id = s.home_dc_id
WHERE l.is_scheduled = FALSE
  AND l.start_time >= '2026-01-01' AND l.start_time < '2026-07-01'
GROUP BY s.staff_id, s.first_name, s.last_name, dc.dc_name
ORDER BY incidents_handled DESC, staff_member;
