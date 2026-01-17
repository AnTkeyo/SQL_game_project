/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Казаков А.А.
 * Дата: 23.11.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь

SELECT COUNT(payer) AS all_players,
	SUM(payer) AS players_who_paid,
    AVG(payer)::numeric(7,5)*100 AS paying_players_percent
FROM fantasy.users


-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь

SELECT r.race,
	COUNT(payer) AS all_players,
	SUM(payer) AS players_who_paid,
    AVG(payer)::numeric(7,5)*100 AS paying_players_percent
FROM fantasy.users AS u
JOIN fantasy.race AS r USING(race_id)
GROUP BY r.race
ORDER BY paying_players_percent DESC --оценить наибольшкю долю платящих игроков;


-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь

SELECT 
    COUNT(*) AS count_of_transactions,
    SUM(amount) AS sum_of_transactions,
    MIN(amount) AS min_amount_of_transactions,
    MAX(amount) AS max_amount_of_transactions,
    ROUND(AVG(amount)::numeric, 2) AS avg_amount_of_transactions,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount_of_transactions, -- PERCENTILE_DISC с усётом если рассматриваем конктретное значение
    ROUND(STDDEV(amount)::numeric, 2) AS stand_dev_amount_of_transactions
FROM fantasy.events
WHERE amount > 0  -- Если amount = 0, то тогда покупка совершалась не во внутриигровой валюте «райские лепестки»
UNION ALL
SELECT 
    COUNT(*) AS count_of_transactions,
    SUM(amount) AS sum_of_transactions,
    MIN(amount) AS min_amount_of_transactions,
    MAX(amount) AS max_amount_of_transactions,
    ROUND(AVG(amount)::numeric, 2) AS avg_amount_of_transactions,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount_of_transactions, -- PERCENTILE_DISC с усётом если рассматриваем конктретное значение
    ROUND(STDDEV(amount)::numeric, 2) AS stand_dev_amount_of_transactions
FROM fantasy.events
-- Без фильтрации нулевых покупок для сравнения

-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь


SELECT
  COUNT(*) FILTER (WHERE amount = 0) AS count_of_null_transactions,
  COUNT(*) AS count_of_transactions,
  ROUND(COUNT(*) FILTER (WHERE amount = 0)::NUMERIC / COUNT(*) *100, 2) AS percent_of_null_transactions
FROM fantasy.events

-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь

WITH item_transactions AS (
    SELECT i.game_items,
        COUNT(e.transaction_id) AS trans,
        COUNT(DISTINCT e.id) AS unique_buyers
    FROM fantasy.events AS e
    JOIN fantasy.items AS i USING(item_code)
    WHERE e.amount > 0
    GROUP BY i.game_items
), -- информация по уникальным item и уникальным покупателям к ним
total_stats AS (
    SELECT 
        COUNT(transaction_id) AS total_trans,
        COUNT(DISTINCT id) AS total_unique_buyers
    FROM fantasy.events
    WHERE amount > 0
) -- информация для всех item и уникальных покупателях  к ним
SELECT 
    i.game_items,
    i.trans AS absolute_trans,
    ROUND(i.trans::NUMERIC / t.total_trans * 100, 3) AS percent_of_trans,
    ROUND(i.unique_buyers::NUMERIC / t.total_unique_buyers * 100, 3) AS percent_of_buyers
FROM item_transactions AS i
CROSS JOIN total_stats AS t
ORDER BY i.trans DESC
--Знаменатель для доли покупок можно посчитать через окно в том же запросе, где проводится группировка: SUM(COUNT(*)) OVER(). 
-- Я изначально так и пытался делать, но потом что-то запутался и решил попытаться сделать так. У меня получилось поэтому  иоставил)

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь

WITH gamers_per_race AS(
    SELECT 
        race_id,
        COUNT(id) AS kol_gamers_per_race
    FROM fantasy.users
    GROUP BY race_id
),
gamers_per_race_with_purchases AS(
    -- Статистика по покупателям и платящим игрокам
    SELECT 
        race_id,
        COUNT(id) AS kol_gamers_with_purchases,
        AVG(payer::numeric) * 100 AS percent_paying_among_buyers
    FROM fantasy.users
    WHERE id IN (SELECT id FROM fantasy.events WHERE amount > 0)
    GROUP BY race_id
),
inf_gamer AS (
    SELECT 
        u.race_id,
        COUNT(e.transaction_id) AS total_transactions,
        SUM(e.amount) AS sum_amount,
        COUNT(DISTINCT u.id) AS kol_unique_gamers
    FROM fantasy.users u
    JOIN fantasy.events e ON u.id = e.id
    WHERE e.amount > 0
    GROUP BY u.race_id
)
SELECT 
    r.race,
    gr.kol_gamers_per_race,
    gp.kol_gamers_with_purchases,
    ROUND((gp.kol_gamers_with_purchases::numeric / gr.kol_gamers_per_race * 100), 2) AS percent_gamers_with_purchases,
    ROUND(gp.percent_paying_among_buyers, 2) AS percent_paying_among_buyers,
    ROUND((inf.total_transactions::numeric / inf.kol_unique_gamers), 2) AS avg_transactions_per_buyer,
    ROUND((inf.sum_amount::numeric / inf.total_transactions), 2) AS avg_amount_per_transaction,
    ROUND((inf.sum_amount::numeric / inf.kol_unique_gamers), 3) AS avg_total_amount_per_buyer
FROM gamers_per_race gr
JOIN gamers_per_race_with_purchases AS gp USING(race_id)
JOIN inf_gamer AS inf USING(race_id)
JOIN fantasy.race AS r USING(race_id)
ORDER BY r.race