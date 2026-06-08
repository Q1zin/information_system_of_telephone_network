CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TYPE pbx_type AS ENUM ('city', 'departmental', 'institutional');
CREATE TYPE line_type AS ENUM ('main', 'parallel', 'paired');
CREATE TYPE intercity_status AS ENUM ('none', 'open', 'closed');
CREATE TYPE number_status AS ENUM ('free', 'reserved', 'active', 'blocked');
CREATE TYPE gender AS ENUM ('male', 'female');
CREATE TYPE subscriber_category AS ENUM ('regular', 'privileged');
CREATE TYPE privilege_kind AS ENUM ('pensioner', 'disabled', 'veteran', 'other');
CREATE TYPE subscriber_status AS ENUM ('active', 'intercity_blocked', 'disconnected');
CREATE TYPE call_type AS ENUM ('local', 'internal', 'external', 'intercity');
CREATE TYPE invoice_kind AS ENUM ('subscription', 'intercity');
CREATE TYPE invoice_status AS ENUM ('pending', 'paid', 'overdue', 'cancelled');
CREATE TYPE notification_kind AS ENUM ('subscription_debt', 'intercity_debt');
CREATE TYPE queue_type AS ENUM ('regular', 'privileged');
CREATE TYPE queue_status AS ENUM ('waiting', 'feasible', 'installed', 'rejected');
CREATE TYPE public_phone_kind AS ENUM ('public', 'payphone');
