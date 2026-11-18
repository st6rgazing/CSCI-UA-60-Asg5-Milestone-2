# CloudNine Systems — Milestone 2: Query Results and Interpretation

Data covers **1 Jan – 30 Jun 2026** (two quarters). Open items are measured as of **15 Jul 2026**. The SQL is in `03_queries.sql` (MySQL 8); Q1–Q14 follow the order of that file.

## Definitions used in every financial query

- **Billed**: `usage_record.charge_status = 'billed'`. These are final, invoiced usage charges.
- **Estimated**: `is_estimate = TRUE` (status `pending`). These are provisional amounts for the last days of June, recorded on 30 Jun before those periods ended. They are not double-counted with billed rows.
- **Excluded everywhere**: `waived` charges. `disputed` charges are excluded from billed totals until they are resolved.
- **Complete months** are January to May. June totals that include estimates are **provisional**.
- **Usage periods** (`period_start`/`period_end`) are weekly or monthly reporting buckets, not exact metering intervals. Resource quantities represent hours. Service quantities use the service's billing unit.

## Invoice formula

For each billing account and month:

`total = ROUND( Σ share% × (billed usage + adjustments + approved change fees) × (1 − client discount ÷ 100), 2 )`

- Usage is assigned to a month by `period_start`, adjustments by `created_at` and approved change fees by `requested_at`.
- The allocation rule in force on that date sets `share%`.
- `amount` on each usage line is calculated from the stored three-decimal `quantity`: `ROUND(quantity × price_per_hour, 2)` for resource lines and `ROUND(quantity × unit_price, 2)` for service lines.
- If a month's credits are larger than its charges, no invoice is issued. The unused credit is carried into the next invoiced month as a `correction` adjustment named *Unused credit carried forward*. Example: Brightpath's $203.04 January credit balance reduces its June invoice to $788.13.

## Dataset size

| Table | Rows |
|---|---:|
| region | 5 |
| availability_zone | 12 |
| data_center | 14 |
| staff | 30 |
| resource_type | 12 |
| resource_group | 25 |
| resource | 369 |
| resource_status_log | 163 |
| client | 18 |
| team | 42 |
| client_user | 148 |
| billing_account | 31 |
| project | 91 |
| cost_allocation_rule | 143 |
| service | 10 |
| rate | 60 |
| reservation | 317 |
| reservation_change | 157 |
| deployment | 250 |
| deployment_resource | 503 |
| resource_assignment | 536 |
| deployment_event | 10,570 |
| usage_record | 7,390 |
| adjustment | 76 |
| invoice | 172 |
| **Total** | **21,144** |

## Queries

### Q1. Billed usage by region, Q1 vs Q2

**Interpretation:** Q1 is complete. Q2 billed covers all of April and May but only part of June, so Q2 estimated holds June's provisional amounts. Even billed charges alone are higher in Q2 than Q1 in every region. **US East** is the largest region: $175k billed in Q1 and $260k billed in Q2, plus $35k estimated. Asia Pacific grew from a very small base ($8.8k → $32.8k billed). *Use:* a starting point for capacity planning, read together with Q4.

| region_name | clients | q1_billed | q2_billed | q2_estimated |
|---|---|---|---|---|
| US East | 8 | 175,319.04 | 260,416.24 | 35,411.37 |
| Canada Central | 5 | 103,209.28 | 145,663.95 | 23,666.92 |
| EU Central | 4 | 100,753.3 | 135,442.93 | 17,946.33 |
| US West | 6 | 89,295.65 | 125,039.73 | 11,772.67 |
| Asia Pacific | 3 | 8,777.33 | 32,793.29 | 8,448.9 |

_5 rows_

### Q2. Monthly billed and estimated usage, with GPU share

**Interpretation:** January to May are complete months. Billed usage grew from $144k in January to $269k in May. June shows $214k billed plus $97k still estimated. That makes about $311k, but this is **provisional** and should not be used for a firm growth comparison until the estimates are billed. GPU's share of usage rose from about 11% in January to about 36% in May (40% in provisional June). *Use:* GPU is the fastest-growing product line.

| month | billed | estimated | gpu | gpu_pct |
|---|---|---|---|---|
| 2026-01 | 143,839 | 0 | 15,639 | 10.9 |
| 2026-02 | 153,407 | 0 | 15,991 | 10.4 |
| 2026-03 | 180,108 | 0 | 53,748 | 29.8 |
| 2026-04 | 216,415 | 0 | 62,269 | 28.8 |
| 2026-05 | 269,290 | 0 | 97,051 | 36 |
| 2026-06 | 213,651 | 97,246 | 125,589 | 40.4 |

_6 rows_

### Q3. Clients ranked by net billed usage, January–May

**Interpretation:** Uses complete months only (billed charges, after the client discount; credits and fees not included). The top 3 clients (Bluefin, Meridian, Danube) account for about 48% of the total, so revenue is concentrated in a few accounts. Marcus Bell manages 5 accounts, including the largest. *Use:* retention priorities and account-manager workload.

| client_name | account_manager | discount_pct | net_billed_jan_may |
|---|---|---|---|
| Bluefin Capital Group | Marcus Bell | 14 | 163,568 |
| Meridian Health Network | Priya Raman | 15 | 153,549 |
| Danube Versicherung AG | Elena Vogel | 11 | 96,739 |
| Rheinwerk Logistik GmbH | Elena Vogel | 11 | 65,183 |
| Lakeshore Provincial Digital Services | Priya Raman | 12 | 62,661 |
| Pinecrest Credit Union | Priya Raman | 6 | 53,720 |
| Harborview Retail Co. | Daniel Okafor | 10 | 50,815 |
| Maplewood Health Clinics | Marcus Bell | 9 | 39,996 |
| Vireo Media Studios | Daniel Okafor | 8 | 35,906 |
| Northgate University | Marcus Bell | 18 | 33,434 |
| Cascadia Game Works | Daniel Okafor | 0 | 32,971 |
| Kestrel Energy Solutions | Marcus Bell | 9 | 16,379 |
| Solenne Biotech | Elena Vogel | 0 | 13,742 |
| Tanjong Fintech Pte Ltd | Mei Tan | 4 | 11,387 |
| Lumen Robotics | Mei Tan | 5 | 10,972 |
| Open Harbor Foundation | Priya Raman | 12 | 6,470 |
| Atlas Genomics | Daniel Okafor | 5 | 5,182 |
| Brightpath Learning | Marcus Bell | 0 | 782 |

_18 rows_

### Q4. Share of data center capacity reserved in Q2

**Interpretation:** Reserved hours ÷ (resources × 2,184 hours in Q2). The US East sites are the most reserved (53–63%), and the Singapore sites the least (16–27%). Low reservation does not prove surplus hardware on its own: spares, test machines and future bookings also need idle capacity. *Use:* flags sites to review before buying more hardware.

| dc_name | resources | reserved_pct |
|---|---|---|
| CN-ASH-01 | 29 | 63 |
| CN-NWK-01 | 22 | 59.1 |
| CN-RIC-01 | 24 | 53.5 |
| CN-ASH-02 | 25 | 52.8 |
| CN-HIL-01 | 39 | 49.5 |
| CN-TOR-01 | 34 | 47.6 |
| CN-MTL-01 | 43 | 44.3 |
| CN-MUC-01 | 15 | 43.8 |
| CN-FRA-01 | 26 | 43.4 |
| CN-FRA-02 | 21 | 39.6 |
| CN-RNO-01 | 35 | 33.3 |
| CN-BER-01 | 19 | 31.8 |
| CN-SIN-01 | 20 | 27.2 |
| CN-SIN-02 | 17 | 15.9 |

_14 rows_

### Q5. Outages by data center, January–June

**Interpretation:** **CN-MTL-01 (Montreal)** had 11 outages, the most of any site. CN-ASH-01 and CN-SIN-01 had few outages but long average repair times (445 and 590 minutes). These counts identify sites to investigate. They don't show the cause or what the best fix is. *Use:* prioritise root-cause reviews.

| dc_name | outages | outage_hours | avg_repair_minutes |
|---|---|---|---|
| CN-MTL-01 | 11 | 33.8 | 185 |
| CN-NWK-01 | 6 | 22.1 | 221 |
| CN-ASH-02 | 5 | 18.9 | 227 |
| CN-RNO-01 | 5 | 22.7 | 272 |
| CN-HIL-01 | 4 | 18.7 | 280 |
| CN-ASH-01 | 3 | 22.3 | 445 |
| CN-FRA-02 | 3 | 13.8 | 277 |
| CN-TOR-01 | 3 | 6.6 | 132 |
| CN-RIC-01 | 2 | 14.3 | 428 |
| CN-SIN-01 | 2 | 19.7 | 590 |
| CN-FRA-01 | 1 | 1.6 | 95 |
| CN-MUC-01 | 1 | 2.9 | 175 |

_12 rows_

### Q6. Failover recovery time by resource type

**Interpretation:** Recovery = time from the failover assignment starting until the replacement resource joined the same reservation's deployment. 36 failovers recovered in about 45–59 minutes on average, and none took longer than 90 minutes. *Use:* a baseline for setting a recovery-time target.

| category | failovers | avg_recovery_minutes | worst_recovery_minutes |
|---|---|---|---|
| compute | 23 | 52 | 90 |
| storage | 5 | 45 | 85 |
| gpu | 5 | 59 | 90 |
| network | 3 | 52 | 70 |

_4 rows_

### Q7. SLA credits by client

**Interpretation:** Credit totals don't follow the number of credits. Meridian Health received 8 credits totalling $750, while Lumen Robotics received $2,281 for a single credit. This query shows the amounts only. Explaining them needs the outage length and resource price behind each credit. *Use:* the starting point for an SLA credit-policy review.

| client_name | tier | sla_credits | credit_total |
|---|---|---|---|
| Lumen Robotics | silver | 1 | 2,281.25 |
| Brightpath Learning | standard | 1 | 985.5 |
| Rheinwerk Logistik GmbH | gold | 2 | 940.24 |
| Meridian Health Network | platinum | 8 | 750.45 |
| Maplewood Health Clinics | gold | 4 | 518.3 |
| Cascadia Game Works | standard | 1 | 401.5 |
| Lakeshore Provincial Digital Services | gold | 4 | 356.24 |
| Pinecrest Credit Union | silver | 6 | 277.4 |
| Harborview Retail Co. | gold | 5 | 264.63 |
| Northgate University | silver | 1 | 175.2 |
| Vireo Media Studios | gold | 3 | 167.54 |
| Bluefin Capital Group | platinum | 4 | 127.02 |
| Kestrel Energy Solutions | gold | 3 | 83.22 |
| Open Harbor Foundation | standard | 1 | 15.33 |
| Tanjong Fintech Pte Ltd | silver | 1 | 13.87 |
| Danube Versicherung AG | gold | 1 | 6.94 |

_16 rows_

### Q8. Unpaid invoices by client (as of 15 Jul 2026)

**Interpretation:** Most of the money owed is June invoices not due until July 30 (shown as 0 days past due). **$24.4k is past due** from three clients. Cascadia Game Works owes $13.1k past due, and its oldest invoice is 107 days late. *Use:* a collections follow-up list.

| client_name | unpaid_invoices | owed | past_due | oldest_days_past_due |
|---|---|---|---|---|
| Cascadia Game Works | 5 | 24,408.14 | 13,121.89 | 107 |
| Lakeshore Provincial Digital Services | 3 | 17,690.32 | 6,756.6 | 15 |
| Open Harbor Foundation | 2 | 7,152.91 | 4,543.21 | 15 |
| Bluefin Capital Group | 2 | 33,380.27 | 0 | 0 |
| Meridian Health Network | 2 | 22,129.36 | 0 | 0 |
| Northgate University | 1 | 20,399.32 | 0 | 0 |
| Vireo Media Studios | 2 | 15,449.44 | 0 | 0 |
| Rheinwerk Logistik GmbH | 2 | 14,484.28 | 0 | 0 |
| Danube Versicherung AG | 2 | 12,737.51 | 0 | 0 |
| Harborview Retail Co. | 2 | 9,198.85 | 0 | 0 |
| Tanjong Fintech Pte Ltd | 1 | 6,447.99 | 0 | 0 |
| Maplewood Health Clinics | 2 | 4,231.36 | 0 | 0 |
| Kestrel Energy Solutions | 1 | 2,421.34 | 0 | 0 |
| Pinecrest Credit Union | 2 | 1,838.31 | 0 | 0 |
| Brightpath Learning | 1 | 788.13 | 0 | 0 |
| Solenne Biotech | 1 | 262.63 | 0 | 0 |

_16 rows_

### Q9. GPU usage by pricing model, Q1 vs Q2

**Interpretation:** gpu_node_hours = hours a GPU server ran; gpu_hours = server hours × GPUs per server. Every GPU rate, including reserved, rose about 8% on 1 April. Among pay-as-you-go users, GPU-hours were split about evenly between peak and off-peak in Q1, and about 2 : 1 toward off-peak in Q2. The query shows this change in mix but can't prove the price change caused it, because the clients and hardware in use also changed. *Use:* evidence worth testing further when setting peak and off-peak prices.

| quarter | pricing_model | gpu_node_hours | gpu_hours | charges |
|---|---|---|---|---|
| Q1 | off_peak | 2,772 | 5,577 | 5,235.76 |
| Q1 | peak | 2,766 | 5,489 | 7,878.78 |
| Q1 | reserved | 23,015 | 81,292 | 72,841.43 |
| Q2 | off_peak | 2,745 | 13,577 | 16,515.82 |
| Q2 | peak | 1,415 | 7,035 | 13,129.75 |
| Q2 | reserved | 59,650 | 255,328 | 256,739.84 |

_6 rows_

### Q10. Reservations by client type

**Interpretation:** 65 reservations were cancelled, and 41 of them were lost because there was no capacity, mostly enterprise bookings. Startups had a 14.3% cancellation rate, while government clients had none in this sample. *Use:* shows how much demand is lost to capacity shortages.

| client_type | reservations | cancelled | lost_to_capacity | avg_lead_days | deposits |
|---|---|---|---|---|---|
| enterprise | 246 | 51 | 30 | 20 | 0 |
| startup | 35 | 5 | 4 | 22.3 | 22350 |
| government | 13 | 0 | 0 | 18.8 | 0 |
| academic | 12 | 4 | 2 | 18.5 | 0 |
| nonprofit | 11 | 5 | 5 | 20.9 | 3600 |

_5 rows_

### Q11. Q2 billed usage allocated to each billing account

**Interpretation:** Billed usage only, split by the cost-allocation rule in force on each usage date. It is **before** discounts, credits and change fees, so it is not the invoice amount (see the invoice formula above). For example, Bluefin's Corporate account carries $90k and its R&D account $44k. *Use:* internal chargeback reporting for clients.

| billing_account_id | account_name | q2_allocated_usage |
|---|---|---|
| 4 | Bluefin Corporate | 89,922.87 |
| 11 | Northgate Central IT | 59,596.19 |
| 3 | Meridian Operations | 50,796.18 |
| 20 | Rheinwerk R&D | 45,159.58 |
| 5 | Bluefin R&D | 43,608.76 |
| 2 | Meridian R&D | 43,271.71 |
| 1 | Meridian Corporate | 30,456.93 |
| 12 | Vireo Corporate | 29,754.23 |
| 10 | Lakeshore R&D | 29,303.22 |
| 26 | Danube Corporate | 29,272.11 |
| 27 | Danube R&D | 26,998.95 |
| 25 | Cascadia Corporate | 26,384.51 |
| 6 | Harborview Corporate | 19,496.02 |
| 9 | Lakeshore Corporate | 18,949.03 |
| 29 | Lumen Corporate | 16,637.05 |
| 19 | Rheinwerk Corporate | 16,522.54 |
| 16 | Pinecrest Corporate | 15,705.12 |
| 23 | Tanjong Corporate | 15,662.48 |
| 28 | Danube Operations | 14,860.64 |
| 7 | Harborview R&D | 14,657.24 |

_30 rows, first 20 shown_

### Q12. Invoiced vs collected by month

**Interpretation:** January to April invoices are 97–100% paid, and May is at 93% because of late payers. June's 12% is expected, since those invoices aren't due until July 30. *Use:* tracks how quickly clients pay.

| month | invoices | invoiced | collected | collected_pct |
|---|---|---|---|---|
| 2026-01 | 28 | 130,250.58 | 130,250.58 | 100 |
| 2026-02 | 27 | 136,888.66 | 132,769.77 | 97 |
| 2026-03 | 29 | 158,524.92 | 157,962.92 | 99.6 |
| 2026-04 | 29 | 196,222.98 | 193,672.28 | 98.7 |
| 2026-05 | 29 | 241,677.3 | 224,487.19 | 92.9 |
| 2026-06 | 30 | 190,894.08 | 22,295.62 | 11.7 |

_6 rows_

### Q13. Password-only actions on confidential deployments

**Interpretation:** Password-only actions occurred on confidential deployments, about 4–6% of actions for most clients with recorded activity. Atlas Genomics is at 10%, but from only 10 actions. *Use:* supports requiring MFA on confidential deployments.

| client_name | actions | password_actions | password_pct |
|---|---|---|---|
| Atlas Genomics | 10 | 1 | 10 |
| Harborview Retail Co. | 48 | 3 | 6.3 |
| Pinecrest Credit Union | 514 | 32 | 6.2 |
| Danube Versicherung AG | 746 | 44 | 5.9 |
| Lakeshore Provincial Digital Services | 510 | 30 | 5.9 |
| Bluefin Capital Group | 844 | 44 | 5.2 |
| Meridian Health Network | 1456 | 74 | 5.1 |
| Maplewood Health Clinics | 360 | 18 | 5 |
| Kestrel Energy Solutions | 61 | 3 | 4.9 |
| Tanjong Fintech Pte Ltd | 206 | 10 | 4.9 |
| Solenne Biotech | 79 | 3 | 3.8 |

_11 rows_

### Q14. Unscheduled incidents logged per staff member

**Interpretation:** Chloe Tremblay (Montreal) logged the most incidents (12), which matches Montreal's outage count in Q5. Singapore staff logged very few. *Use:* shows where incident workload falls. It doesn't by itself show that more staff are needed.

| staff_member | home_dc | incidents_handled |
|---|---|---|
| Chloe Tremblay | CN-MTL-01 | 12 |
| Ethan Ross | CN-RNO-01 | 9 |
| Julien Gagnon | CN-TOR-01 | 7 |
| Noah Becker | CN-NWK-01 | 7 |
| Fatima Haddad | CN-HIL-01 | 5 |
| Jenna Park | CN-ASH-02 | 5 |
| Anna Schmidt | CN-FRA-01 | 3 |
| Carlos Mendes | CN-ASH-01 | 3 |
| Felix Wagner | CN-FRA-02 | 3 |
| Hamza Qureshi | CN-RIC-01 | 3 |
| Owen Fitzgerald | CN-RIC-01 | 3 |
| Lukas Brandt | CN-FRA-01 | 2 |
| Wei Lim | CN-SIN-01 | 2 |
| Aisha Bello | CN-MTL-01 | 1 |
| Arjun Nair | CN-SIN-02 | 1 |
| Grace Liu | CN-HIL-01 | 1 |
| Leon Richter | CN-MUC-01 | 1 |

_17 rows_
