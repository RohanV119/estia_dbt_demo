-- ===========================================================================
-- Estia Health dbt demo - RAW layer setup
--
-- Run this ONCE in Snowsight (or via `snow sql -f`) before running dbt.
-- Creates ESTIA_DEMO.RAW and populates five source tables with dummy data.
--
-- All data below is fabricated for demonstration purposes. No real resident,
-- facility, or financial information is present.
--
-- Safe to re-run: every table uses CREATE OR REPLACE.
-- ===========================================================================

CREATE DATABASE IF NOT EXISTS ESTIA_DEMO;
CREATE SCHEMA   IF NOT EXISTS ESTIA_DEMO.RAW;
CREATE SCHEMA   IF NOT EXISTS ESTIA_DEMO.SILVER;
CREATE SCHEMA   IF NOT EXISTS ESTIA_DEMO.GOLD;

USE DATABASE ESTIA_DEMO;
USE SCHEMA   RAW;


-- ---------------------------------------------------------------------------
-- raw_facilities - 5 rows
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ESTIA_DEMO.RAW.raw_facilities (
  facility_id     VARCHAR,
  facility_name   VARCHAR,
  state           VARCHAR,
  capacity        INT,
  opened_date     DATE
);

INSERT INTO ESTIA_DEMO.RAW.raw_facilities VALUES
  ('FAC001', 'Estia Heidelberg', 'VIC',  80, '2010-03-01'),
  ('FAC002', 'Estia Bankstown',  'nsw', 120, '2008-07-15'),
  ('FAC003', 'Estia Southport',  'QLD',  95, '2013-11-20'),
  ('FAC004', 'Estia Norwood',    'sa',   60, '2016-02-10'),
  ('FAC005', 'Estia Kingsley',   'WA',   75, '2019-09-05');
-- Note: 'nsw' and 'sa' are deliberately lower-case. The silver layer
-- normalises them with UPPER() - a visible, explainable cleaning step.


-- ---------------------------------------------------------------------------
-- raw_residents - 30 rows
-- discharge_date is NULL while a resident is still admitted.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ESTIA_DEMO.RAW.raw_residents (
  resident_id     VARCHAR,
  facility_id     VARCHAR,
  first_name      VARCHAR,
  last_name       VARCHAR,
  date_of_birth   DATE,
  admission_date  DATE,
  discharge_date  DATE,
  status          VARCHAR
);

INSERT INTO ESTIA_DEMO.RAW.raw_residents VALUES
  -- FAC001 Heidelberg
  ('RES001','FAC001','Margaret','Whitfield','1938-04-12','2021-06-01',NULL,        'Active'),
  ('RES002','FAC001','Alan',    'Petrakis', '1941-11-03','2022-01-17',NULL,        'Active'),
  ('RES003','FAC001','Joyce',   'Nkemelu',  '1935-02-28','2020-09-22','2024-03-14','Deceased'),
  ('RES004','FAC001','Terrence','Buckley',  '1944-07-19','2023-04-05',NULL,        'Active'),
  ('RES005','FAC001','Vera',    'Salvatore','1939-12-30','2019-11-11',NULL,        'Active'),
  ('RES006','FAC001','Douglas', 'Ferreira', '1947-03-08','2024-02-19','2025-08-30','Discharged'),
  ('RES007','FAC001','Beryl',   'Osmond',   '1933-08-25','2020-05-14',NULL,        'Active'),
  -- FAC002 Bankstown
  ('RES008','FAC002','Nikolai', 'Andreou',  '1942-01-15','2021-10-08',NULL,        'Active'),
  ('RES009','FAC002','Pauline', 'Vukovic',  '1936-06-21','2019-08-30','2023-12-02','Deceased'),
  ('RES010','FAC002','Raymond', 'Tolentino','1945-09-04','2022-07-25',NULL,        'Active'),
  ('RES011','FAC002','Edith',   'Marchetti','1940-05-17','2020-12-03',NULL,        'Active'),
  ('RES012','FAC002','Hamid',   'Rostami',  '1943-10-29','2023-09-12',NULL,        'Active'),
  ('RES013','FAC002','Lorraine','Beaumont', '1937-03-06','2021-02-28',NULL,        'Active'),
  ('RES014','FAC002','Stanley', 'Okonkwo',  '1946-12-11','2024-06-07',NULL,        'Active'),
  ('RES015','FAC002','Nadia',   'Christos', '1948-04-23','2025-01-20',NULL,        'Active'),
  -- FAC003 Southport
  ('RES016','FAC003','Colin',   'Radcliffe','1934-11-09','2019-04-16','2024-09-25','Deceased'),
  ('RES017','FAC003','Gwendolyn','Mbeki',   '1941-08-02','2022-03-30',NULL,        'Active'),
  ('RES018','FAC003','Frank',   'Zampatti', '1939-01-27','2020-10-19',NULL,        'Active'),
  ('RES019','FAC003','Shirley', 'Haddad',   '1944-06-14','2023-01-08',NULL,        'Active'),
  ('RES020','FAC003','Bruce',   'Kalinowski','1947-09-30','2024-08-22',NULL,       'Active'),
  ('RES021','FAC003','Iris',    'Devereaux','1932-05-05','2019-07-01','2025-04-11','Discharged'),
  ('RES022','FAC003','Mohan',   'Selvaraj', '1945-02-18','2022-11-14',NULL,        'Active'),
  -- FAC004 Norwood
  ('RES023','FAC004','Dorothy', 'Prendergast','1938-10-07','2021-05-26',NULL,      'Active'),
  ('RES024','FAC004','Keith',   'Amagula',  '1942-12-19','2023-06-13',NULL,        'Active'),
  ('RES025','FAC004','Sylvia',  'Bergmann', '1936-07-23','2020-02-04','2024-11-08','Deceased'),
  ('RES026','FAC004','Neville', 'Chukwu',   '1946-03-15','2024-10-01',NULL,        'Active'),
  -- FAC005 Kingsley
  ('RES027','FAC005','Patricia','Fanucci',  '1940-09-11','2021-12-09',NULL,        'Active'),
  ('RES028','FAC005','Gordon',  'Ivanovski','1943-04-26','2022-08-17',NULL,        'Active'),
  ('RES029','FAC005','Maureen', 'Delacroix','1937-11-30','2020-06-21',NULL,        'Active'),
  ('RES030','FAC005','Arthur',  'Nguyen',   '1949-01-08','2025-03-05',NULL,        'Active');


-- ---------------------------------------------------------------------------
-- raw_care_assessments - 60 rows (2 per resident)
-- score 0-100. Lower score = higher care need.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ESTIA_DEMO.RAW.raw_care_assessments (
  assessment_id   VARCHAR,
  resident_id     VARCHAR,
  assessed_date   DATE,
  assessment_type VARCHAR,
  score           INT
);

INSERT INTO ESTIA_DEMO.RAW.raw_care_assessments VALUES
  ('ASM001','RES001','2025-03-10','ACFI',    72),
  ('ASM002','RES001','2026-03-15','ACFI',    64),
  ('ASM003','RES002','2025-04-02','InterRAI',55),
  ('ASM004','RES002','2026-04-08','InterRAI',48),
  ('ASM005','RES003','2023-05-18','ACFI',    38),
  ('ASM006','RES003','2024-01-22','ACFI',    31),
  ('ASM007','RES004','2025-06-11','ACFI',    81),
  ('ASM008','RES004','2026-06-16','ACFI',    77),
  ('ASM009','RES005','2025-02-27','InterRAI',43),
  ('ASM010','RES005','2026-02-25','InterRAI',36),
  ('ASM011','RES006','2024-08-14','ACFI',    69),
  ('ASM012','RES006','2025-06-30','ACFI',    66),
  ('ASM013','RES007','2025-01-19','ACFI',    29),
  ('ASM014','RES007','2026-01-24','ACFI',    24),
  ('ASM015','RES008','2025-05-07','InterRAI',75),
  ('ASM016','RES008','2026-05-12','InterRAI',71),
  ('ASM017','RES009','2023-03-21','ACFI',    34),
  ('ASM018','RES009','2023-10-15','ACFI',    27),
  ('ASM019','RES010','2025-07-23','ACFI',    88),
  ('ASM020','RES010','2026-07-28','ACFI',    84),
  ('ASM021','RES011','2025-04-16','InterRAI',52),
  ('ASM022','RES011','2026-04-21','InterRAI',45),
  ('ASM023','RES012','2025-09-09','ACFI',    63),
  ('ASM024','RES012','2026-03-12','ACFI',    58),
  ('ASM025','RES013','2025-02-05','ACFI',    41),
  ('ASM026','RES013','2026-02-10','ACFI',    33),
  ('ASM027','RES014','2025-06-25','InterRAI',79),
  ('ASM028','RES014','2026-06-30','InterRAI',74),
  ('ASM029','RES015','2025-02-14','ACFI',    91),
  ('ASM030','RES015','2026-02-19','ACFI',    86),
  ('ASM031','RES016','2023-06-08','ACFI',    35),
  ('ASM032','RES016','2024-04-12','ACFI',    26),
  ('ASM033','RES017','2025-05-30','InterRAI',67),
  ('ASM034','RES017','2026-06-04','InterRAI',61),
  ('ASM035','RES018','2025-03-27','ACFI',    49),
  ('ASM036','RES018','2026-04-01','ACFI',    42),
  ('ASM037','RES019','2025-08-13','ACFI',    73),
  ('ASM038','RES019','2026-08-18','ACFI',    68),
  ('ASM039','RES020','2025-01-06','InterRAI',85),
  ('ASM040','RES020','2026-01-11','InterRAI',80),
  ('ASM041','RES021','2024-02-20','ACFI',    32),
  ('ASM042','RES021','2025-01-15','ACFI',    28),
  ('ASM043','RES022','2025-04-09','ACFI',    57),
  ('ASM044','RES022','2026-04-14','ACFI',    51),
  ('ASM045','RES023','2025-07-16','InterRAI',46),
  ('ASM046','RES023','2026-07-21','InterRAI',39),
  ('ASM047','RES024','2025-06-03','ACFI',    70),
  ('ASM048','RES024','2026-06-08','ACFI',    65),
  ('ASM049','RES025','2024-03-11','ACFI',    30),
  ('ASM050','RES025','2024-09-16','ACFI',    22),
  ('ASM051','RES026','2025-05-21','InterRAI',83),
  ('ASM052','RES026','2026-05-26','InterRAI',78),
  ('ASM053','RES027','2025-03-04','ACFI',    59),
  ('ASM054','RES027','2026-03-09','ACFI',    53),
  ('ASM055','RES028','2025-08-27','ACFI',    76),
  ('ASM056','RES028','2026-09-01','ACFI',    72),
  ('ASM057','RES029','2025-01-30','InterRAI',37),
  ('ASM058','RES029','2026-02-04','InterRAI',25),
  ('ASM059','RES030','2025-04-22','ACFI',    94),
  ('ASM060','RES030','2026-04-27','ACFI',    89);


-- ---------------------------------------------------------------------------
-- raw_incidents - 40 rows
-- Not every resident has an incident. That is intentional - the gold mart
-- must LEFT JOIN and coalesce, which is worth pointing out in the demo.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ESTIA_DEMO.RAW.raw_incidents (
  incident_id     VARCHAR,
  resident_id     VARCHAR,
  incident_date   DATE,
  incident_type   VARCHAR,
  severity        VARCHAR
);

INSERT INTO ESTIA_DEMO.RAW.raw_incidents VALUES
  ('INC001','RES001','2025-08-14','Fall',            'Medium'),
  ('INC002','RES001','2026-02-03','Fall',            'Low'),
  ('INC003','RES002','2025-11-27','Medication Error','Low'),
  ('INC004','RES003','2023-09-05','Fall',            'High'),
  ('INC005','RES003','2024-01-18','Wound',           'High'),
  ('INC006','RES005','2025-05-22','Behaviour',       'Medium'),
  ('INC007','RES005','2026-01-09','Fall',            'High'),
  ('INC008','RES005','2026-06-15','Wound',           'Low'),
  ('INC009','RES007','2025-04-11','Fall',            'High'),
  ('INC010','RES007','2025-10-30','Fall',            'Medium'),
  ('INC011','RES007','2026-05-19','Medication Error','Medium'),
  ('INC012','RES008','2025-12-08','Wound',           'Low'),
  ('INC013','RES009','2023-07-14','Fall',            'High'),
  ('INC014','RES009','2023-11-21','Behaviour',       'Medium'),
  ('INC015','RES011','2025-06-26','Fall',            'Medium'),
  ('INC016','RES011','2026-03-17','Wound',           'Low'),
  ('INC017','RES012','2026-01-28','Medication Error','Low'),
  ('INC018','RES013','2025-09-13','Fall',            'High'),
  ('INC019','RES013','2026-04-05','Behaviour',       'High'),
  ('INC020','RES014','2025-11-02','Fall',            'Low'),
  ('INC021','RES016','2024-02-16','Fall',            'High'),
  ('INC022','RES016','2024-07-23','Wound',           'High'),
  ('INC023','RES017','2025-08-09','Behaviour',       'Medium'),
  ('INC024','RES018','2025-03-19','Fall',            'Medium'),
  ('INC025','RES018','2026-02-27','Medication Error','Low'),
  ('INC026','RES019','2026-05-07','Fall',            'Low'),
  ('INC027','RES021','2024-06-12','Fall',            'High'),
  ('INC028','RES021','2025-02-24','Wound',           'Medium'),
  ('INC029','RES022','2025-10-16','Behaviour',       'Low'),
  ('INC030','RES023','2025-07-29','Fall',            'High'),
  ('INC031','RES023','2026-03-31','Fall',            'Medium'),
  ('INC032','RES024','2026-01-14','Medication Error','Low'),
  ('INC033','RES025','2024-05-20','Fall',            'High'),
  ('INC034','RES025','2024-10-04','Wound',           'High'),
  ('INC035','RES027','2025-12-18','Behaviour',       'Medium'),
  ('INC036','RES028','2026-06-22','Fall',            'Low'),
  ('INC037','RES029','2025-04-30','Fall',            'High'),
  ('INC038','RES029','2025-11-11','Wound',           'Medium'),
  ('INC039','RES029','2026-07-06','Fall',            'High'),
  ('INC040','RES030','2026-08-13','Medication Error','Low');


-- ---------------------------------------------------------------------------
-- raw_invoices - 80 rows
-- paid_date is NULL when is_paid = FALSE. Some unpaid invoices are older than
-- 30 days so the silver layer's is_overdue flag returns a mix of TRUE/FALSE.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ESTIA_DEMO.RAW.raw_invoices (
  invoice_id      VARCHAR,
  resident_id     VARCHAR,
  invoice_date    DATE,
  amount_aud      DECIMAL(10,2),
  payer_type      VARCHAR,
  is_paid         BOOLEAN,
  paid_date       DATE
);

INSERT INTO ESTIA_DEMO.RAW.raw_invoices VALUES
  ('INV001','RES001','2026-05-01', 4820.00,'Government',TRUE, '2026-05-19'),
  ('INV002','RES001','2026-06-01', 4820.00,'Government',TRUE, '2026-06-17'),
  ('INV003','RES001','2026-07-01', 4950.00,'Private',   FALSE, NULL),
  ('INV004','RES002','2026-05-01', 5310.00,'Government',TRUE, '2026-05-22'),
  ('INV005','RES002','2026-06-01', 5310.00,'Government',FALSE, NULL),
  ('INV006','RES002','2026-08-01', 5410.00,'Private',   TRUE, '2026-08-20'),
  ('INV007','RES003','2024-01-01', 6120.00,'Government',TRUE, '2024-01-18'),
  ('INV008','RES003','2024-02-01', 6120.00,'Government',TRUE, '2024-02-15'),
  ('INV009','RES004','2026-06-01', 3980.00,'NDIS',      TRUE, '2026-06-25'),
  ('INV010','RES004','2026-07-01', 3980.00,'NDIS',      TRUE, '2026-07-23'),
  ('INV011','RES004','2026-08-01', 4050.00,'NDIS',      FALSE, NULL),
  ('INV012','RES005','2026-05-01', 5760.00,'Government',TRUE, '2026-05-16'),
  ('INV013','RES005','2026-06-01', 5760.00,'Government',TRUE, '2026-06-14'),
  ('INV014','RES005','2026-07-01', 5880.00,'Government',FALSE, NULL),
  ('INV015','RES006','2025-07-01', 4430.00,'Private',   TRUE, '2025-07-28'),
  ('INV016','RES006','2025-08-01', 4430.00,'Private',   TRUE, '2025-08-26'),
  ('INV017','RES007','2026-06-01', 6540.00,'Government',TRUE, '2026-06-19'),
  ('INV018','RES007','2026-07-01', 6540.00,'Government',FALSE, NULL),
  ('INV019','RES007','2026-08-01', 6680.00,'Government',FALSE, NULL),
  ('INV020','RES008','2026-05-01', 4210.00,'NDIS',      TRUE, '2026-05-27'),
  ('INV021','RES008','2026-06-01', 4210.00,'NDIS',      TRUE, '2026-06-24'),
  ('INV022','RES008','2026-08-01', 4290.00,'NDIS',      TRUE, '2026-08-21'),
  ('INV023','RES009','2023-11-01', 5920.00,'Government',TRUE, '2023-11-20'),
  ('INV024','RES009','2023-12-01', 5920.00,'Government',TRUE, '2023-12-18'),
  ('INV025','RES010','2026-06-01', 3640.00,'Private',   TRUE, '2026-06-29'),
  ('INV026','RES010','2026-07-01', 3640.00,'Private',   FALSE, NULL),
  ('INV027','RES010','2026-08-01', 3710.00,'Private',   FALSE, NULL),
  ('INV028','RES011','2026-05-01', 5480.00,'Government',TRUE, '2026-05-21'),
  ('INV029','RES011','2026-06-01', 5480.00,'Government',TRUE, '2026-06-18'),
  ('INV030','RES011','2026-07-01', 5590.00,'Government',FALSE, NULL),
  ('INV031','RES012','2026-06-01', 4870.00,'NDIS',      TRUE, '2026-06-26'),
  ('INV032','RES012','2026-07-01', 4870.00,'NDIS',      TRUE, '2026-07-24'),
  ('INV033','RES013','2026-05-01', 6230.00,'Government',TRUE, '2026-05-15'),
  ('INV034','RES013','2026-06-01', 6230.00,'Government',FALSE, NULL),
  ('INV035','RES013','2026-08-01', 6350.00,'Government',FALSE, NULL),
  ('INV036','RES014','2026-06-01', 3820.00,'Private',   TRUE, '2026-06-27'),
  ('INV037','RES014','2026-07-01', 3820.00,'Private',   TRUE, '2026-07-25'),
  ('INV038','RES015','2026-07-01', 3450.00,'NDIS',      TRUE, '2026-07-30'),
  ('INV039','RES015','2026-08-01', 3450.00,'NDIS',      FALSE, NULL),
  ('INV040','RES016','2024-08-01', 6410.00,'Government',TRUE, '2024-08-19'),
  ('INV041','RES016','2024-09-01', 6410.00,'Government',TRUE, '2024-09-17'),
  ('INV042','RES017','2026-05-01', 4690.00,'Government',TRUE, '2026-05-23'),
  ('INV043','RES017','2026-06-01', 4690.00,'Government',TRUE, '2026-06-21'),
  ('INV044','RES017','2026-08-01', 4780.00,'Government',FALSE, NULL),
  ('INV045','RES018','2026-06-01', 5140.00,'Private',   TRUE, '2026-06-16'),
  ('INV046','RES018','2026-07-01', 5140.00,'Private',   FALSE, NULL),
  ('INV047','RES019','2026-05-01', 4360.00,'NDIS',      TRUE, '2026-05-28'),
  ('INV048','RES019','2026-06-01', 4360.00,'NDIS',      TRUE, '2026-06-26'),
  ('INV049','RES019','2026-08-01', 4440.00,'NDIS',      TRUE, '2026-08-24'),
  ('INV050','RES020','2026-07-01', 3290.00,'Private',   TRUE, '2026-07-27'),
  ('INV051','RES020','2026-08-01', 3290.00,'Private',   FALSE, NULL),
  ('INV052','RES021','2025-03-01', 6070.00,'Government',TRUE, '2025-03-19'),
  ('INV053','RES021','2025-04-01', 6070.00,'Government',TRUE, '2025-04-16'),
  ('INV054','RES022','2026-06-01', 5020.00,'Government',TRUE, '2026-06-20'),
  ('INV055','RES022','2026-07-01', 5020.00,'Government',TRUE, '2026-07-18'),
  ('INV056','RES022','2026-08-01', 5130.00,'Government',FALSE, NULL),
  ('INV057','RES023','2026-05-01', 5670.00,'Government',TRUE, '2026-05-17'),
  ('INV058','RES023','2026-06-01', 5670.00,'Government',FALSE, NULL),
  ('INV059','RES023','2026-07-01', 5790.00,'Government',FALSE, NULL),
  ('INV060','RES024','2026-06-01', 4180.00,'NDIS',      TRUE, '2026-06-28'),
  ('INV061','RES024','2026-07-01', 4180.00,'NDIS',      TRUE, '2026-07-26'),
  ('INV062','RES025','2024-10-01', 6290.00,'Government',TRUE, '2024-10-21'),
  ('INV063','RES025','2024-11-01', 6290.00,'Government',TRUE, '2024-11-19'),
  ('INV064','RES026','2026-07-01', 3560.00,'Private',   TRUE, '2026-07-29'),
  ('INV065','RES026','2026-08-01', 3560.00,'Private',   FALSE, NULL),
  ('INV066','RES027','2026-05-01', 4930.00,'Government',TRUE, '2026-05-24'),
  ('INV067','RES027','2026-06-01', 4930.00,'Government',TRUE, '2026-06-22'),
  ('INV068','RES027','2026-08-01', 5040.00,'Government',FALSE, NULL),
  ('INV069','RES028','2026-06-01', 4270.00,'NDIS',      TRUE, '2026-06-30'),
  ('INV070','RES028','2026-07-01', 4270.00,'NDIS',      TRUE, '2026-07-28'),
  ('INV071','RES029','2026-05-01', 6480.00,'Government',TRUE, '2026-05-18'),
  ('INV072','RES029','2026-06-01', 6480.00,'Government',TRUE, '2026-06-15'),
  ('INV073','RES029','2026-07-01', 6600.00,'Government',FALSE, NULL),
  ('INV074','RES029','2026-08-01', 6600.00,'Government',FALSE, NULL),
  ('INV075','RES030','2026-06-01', 3180.00,'Private',   TRUE, '2026-06-23'),
  ('INV076','RES030','2026-07-01', 3180.00,'Private',   TRUE, '2026-07-21'),
  ('INV077','RES030','2026-08-01', 3250.00,'Private',   FALSE, NULL),
  ('INV078','RES012','2026-08-01', 4970.00,'NDIS',      FALSE, NULL),
  ('INV079','RES015','2026-06-01', 3450.00,'NDIS',      TRUE, '2026-06-27'),
  ('INV080','RES020','2026-06-01', 3290.00,'Private',   TRUE, '2026-06-25');


-- ---------------------------------------------------------------------------
-- Sanity check - row counts should be 5 / 30 / 60 / 40 / 80
-- ---------------------------------------------------------------------------
SELECT 'raw_facilities'       AS table_name, COUNT(*) AS row_count FROM ESTIA_DEMO.RAW.raw_facilities
UNION ALL SELECT 'raw_residents',        COUNT(*) FROM ESTIA_DEMO.RAW.raw_residents
UNION ALL SELECT 'raw_care_assessments', COUNT(*) FROM ESTIA_DEMO.RAW.raw_care_assessments
UNION ALL SELECT 'raw_incidents',        COUNT(*) FROM ESTIA_DEMO.RAW.raw_incidents
UNION ALL SELECT 'raw_invoices',         COUNT(*) FROM ESTIA_DEMO.RAW.raw_invoices
ORDER BY table_name;
