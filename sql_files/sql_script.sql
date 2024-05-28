USE student_engagement;

SET @@global.sql_mode := REPLACE(@@global.sql_mode, 'ONLY_FULL_GROUP_BY', '');

-- Look at tables
SELECT *
FROM student_certificates;

SELECT *
FROM student_info;

SELECT *
FROM student_purchases;

SELECT *
FROM student_video_watched;


-- Retrieve purchase information:

-- To calculate the end date of a subscription (date_end), add one month, three months, or 12 months to the start date of a subscription for a Monthly (represented as 0 in the plan_id column), Quarterly (1), or an Annual (2) purchase, respectively.
-- The only exception is the lifetime subscription (denoted by 3), which has no end date. Refunds will be handled in the following task: II. Re-Calculating a Subscription’s End Date.
-- If an order was refunded—indicated by a non-NULL value in the date_refunded field—the student’s subscription terminates at the refund date.

WITH end_date AS(
    SELECT
		purchase_id,
		student_id,
		plan_id,
		date_purchased AS date_start,
		CASE 
			WHEN plan_id=0 THEN DATE_ADD(date_purchased, INTERVAL 1 MONTH)
			WHEN plan_id=1 THEN DATE_ADD(date_purchased, INTERVAL 3 MONTH)
			WHEN plan_id=2 THEN DATE_ADD(date_purchased, INTERVAL 12 MONTH)
			WHEN plan_id=3 THEN curdate()
		END AS date_end,
		date_refunded
	FROM student_purchases
)
SELECT
	purchase_id,
	student_id,
	plan_id,
	date_start,
	IF (date_refunded IS NULL, date_end, date_refunded) AS date_end
FROM end_date;

-- Retrieve whether a student had an active subscription during the respective year’s second quarter (April 1 to June 30, inclusive). 
-- A 0 in the column indicates a free-plan student in Q2, while a 1 represents an active subscription in that period.
-- Create a view for the combined purchase information

DROP VIEW IF EXISTS purchase_info;

CREATE VIEW purchase_info AS
SELECT
	*,
    -- flag if a subscription is active during Q2 2021
    CASE
		WHEN date_end < '2021-04-01' THEN 0
        WHEN date_start > '2021-06-30' THEN 0
        ELSE 1
	END AS paid_q2_2021,
    -- flag if a subscription is active during Q2 2022
    CASE 	
		WHEN date_end < '2022-04-01' THEN 0
        WHEN date_start > '2022-06-30' THEN 0
        ELSE 1
	END AS paid_q2_2022
FROM (
	WITH end_date AS(
    SELECT
		purchase_id,
		student_id,
		plan_id,
		date_purchased AS date_start,
		CASE 
			WHEN plan_id=0 THEN DATE_ADD(date_purchased, INTERVAL 1 MONTH)
			WHEN plan_id=1 THEN DATE_ADD(date_purchased, INTERVAL 3 MONTH)
			WHEN plan_id=2 THEN DATE_ADD(date_purchased, INTERVAL 12 MONTH)
			WHEN plan_id=3 THEN curdate()
		END AS date_end,
		date_refunded
	FROM student_purchases
)
SELECT
	purchase_id,
	student_id,
	plan_id,
	date_start,
	IF (date_refunded IS NULL, date_end, date_refunded) AS date_end
FROM end_date
) a;


-- Now, we’ll utilize the view purchases_info to classify students as free-plan and paying in Q2 2021 and Q2 2022.
-- Retrieve the students' minutes watched and paying status for the following four criterias:
	-- Students engaged in Q2 2021 who haven’t had a paid subscription in Q2 2021 
	-- Students engaged in Q2 2022 who haven’t had a paid subscription in Q2 2022 
	-- Students engaged in Q2 2021 who have been paid subscribers in Q2 2021 
	-- Students engaged in Q2 2022 who have been paid subscribers in Q2 2022 

WITH time_watched AS(
	SELECT 
		student_id,
        date_watched,
		ROUND(SUM(seconds_watched/60),2) AS minutes_watched
	FROM student_video_watched
	WHERE YEAR(date_watched) = 2022	  -- change to 2021 or 2022 depending on the year considered
	GROUP BY student_id
)
SELECT
	tw.student_id,
    tw.minutes_watched,
    IF (pi.date_start IS NULL, 0, MAX(pi.paid_q2_2022)) AS paid_in_q2	-- change to *_2021 or *_2022 depending on the year considered
FROM time_watched tw
LEFT JOIN purchase_info pi
ON tw.student_id = pi.student_id
GROUP BY tw.student_id
HAVING paid_in_q2 = 1;	-- change to 0 or 1 depending on the paying status 


-- Retrieve the total minutes the students have watched and the total number of certificates issued to them.
-- Consider only the students who've been issued a certificate.
WITH certificates AS(
	SELECT 
		student_id,
		COUNT(DISTINCT certificate_id) AS certificates_issued 
	FROM student_certificates
	GROUP BY student_id
)
SELECT
	c.student_id,
    IF(vw.seconds_watched IS NULL, 0, ROUND(SUM(vw.seconds_watched)/60, 2)) AS minutes_watched,
    c.certificates_issued
FROM certificates c
LEFT JOIN student_video_watched vw
ON c.student_id = vw.student_id
GROUP BY c.student_id;


-- Retreive the total number of students who watched a lecture; number of students who watched in Q2 2021 and Q2 2022; number of students who watched a lecture in both period, 
SELECT COUNT(DISTINCT student_id) AS number_of_students
FROM student_video_watched;

SELECT COUNT(DISTINCT student_id) AS number_of_students
FROM student_video_watched
WHERE YEAR(date_watched) = 2021;

SELECT COUNT(DISTINCT student_id) AS number_of_students
FROM student_video_watched
WHERE YEAR(date_watched) = 2022;

WITH number_students_2021 AS(
	SELECT DISTINCT student_id
    FROM student_video_watched
    WHERE YEAR(date_watched) = 2021
),
number_students_2022 AS(
	SELECT DISTINCT student_id
    FROM student_video_watched
    WHERE YEAR(date_watched) = 2022
)
SELECT COUNT(DISTINCT a.student_id) AS number_of_students
FROM number_students_2021 a
JOIN number_students_2022 b
ON a.student_id = b.student_id;


