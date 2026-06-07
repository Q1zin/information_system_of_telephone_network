-- 0001_init.sql
-- Extensions and enum types for the City Telephone Network (ГТС) schema.

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- АТС types: city / departmental / institutional
CREATE TYPE pbx_type AS ENUM ('city', 'departmental', 'institutional');

-- Phone line types: основной / параллельный / спаренный
CREATE TYPE line_type AS ENUM ('main', 'parallel', 'paired');

-- Long-distance (межгород) access state of a number.
-- 'none' = not applicable (closed-network PBX); 'open'/'closed' only for city PBX.
CREATE TYPE intercity_status AS ENUM ('none', 'open', 'closed');

-- Lifecycle of a phone number.
CREATE TYPE number_status AS ENUM ('free', 'reserved', 'active', 'blocked');

CREATE TYPE gender AS ENUM ('male', 'female');

-- Простой / льготный абонент.
CREATE TYPE subscriber_category AS ENUM ('regular', 'privileged');
CREATE TYPE privilege_kind AS ENUM ('pensioner', 'disabled', 'veteran', 'other');

-- active / выход на межгород отключён / абонент отключён
CREATE TYPE subscriber_status AS ENUM ('active', 'intercity_blocked', 'disconnected');

CREATE TYPE call_type AS ENUM ('local', 'internal', 'external', 'intercity');

CREATE TYPE invoice_kind AS ENUM ('subscription', 'intercity');
CREATE TYPE invoice_status AS ENUM ('pending', 'paid', 'overdue', 'cancelled');

CREATE TYPE notification_kind AS ENUM ('subscription_debt', 'intercity_debt');

-- Очередь на установку: льготная / обычная
CREATE TYPE queue_type AS ENUM ('regular', 'privileged');
CREATE TYPE queue_status AS ENUM ('waiting', 'feasible', 'installed', 'rejected');

-- Общественный телефон / таксофон
CREATE TYPE public_phone_kind AS ENUM ('public', 'payphone');
