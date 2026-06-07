-- dev_seed.sql
-- Demo/business data for development and for exercising the 13 variant queries.
-- Run once against a freshly migrated database:  psql -d gts -f backend/seeds/dev_seed.sql

DO $$
DECLARE
    -- cities
    c_spb BIGINT; c_msk BIGINT; c_nsk BIGINT; c_ekb BIGINT;
    -- pbx
    p_centr BIGINT; p_nev BIGINT; p_zavod BIGINT; p_univ BIGINT;
    -- addresses
    a1 BIGINT; a2 BIGINT; a3 BIGINT; a4 BIGINT; a5 BIGINT;
    a6 BIGINT; a8 BIGINT; a9 BIGINT; a10 BIGINT; a11 BIGINT;
    -- numbers
    n1 BIGINT; n2 BIGINT; n3 BIGINT; n4 BIGINT; n5 BIGINT;
    n6 BIGINT; n7 BIGINT; n8 BIGINT; n9 BIGINT; n10 BIGINT; n11 BIGINT;
    -- subscribers
    s1 BIGINT; s2 BIGINT; s3 BIGINT; s4 BIGINT; s5 BIGINT;
    s6 BIGINT; s7 BIGINT; s8 BIGINT; s9 BIGINT;
    inv_s1 BIGINT;
BEGIN
    ------------------------------------------------------------------ cities
    INSERT INTO city(name, is_home) VALUES ('Санкт-Петербург', TRUE) RETURNING id INTO c_spb;
    INSERT INTO city(name) VALUES ('Москва')       RETURNING id INTO c_msk;
    INSERT INTO city(name) VALUES ('Новосибирск')  RETURNING id INTO c_nsk;
    INSERT INTO city(name) VALUES ('Екатеринбург') RETURNING id INTO c_ekb;

    --------------------------------------------------------------- addresses
    INSERT INTO address(postal_index,district,street,house,apartment) VALUES
        ('190000','Центральный','Невский пр.','10','5')  RETURNING id INTO a1;
    INSERT INTO address(postal_index,district,street,house,apartment) VALUES
        ('190000','Центральный','Невский пр.','10','7')  RETURNING id INTO a2;
    INSERT INTO address(postal_index,district,street,house,apartment) VALUES
        ('190000','Центральный','Невский пр.','10',NULL) RETURNING id INTO a3;
    INSERT INTO address(postal_index,district,street,house,apartment) VALUES
        ('190000','Центральный','Невский пр.','12','1')  RETURNING id INTO a4;
    INSERT INTO address(postal_index,district,street,house,apartment) VALUES
        ('190000','Центральный','Невский пр.','12','2')  RETURNING id INTO a5;
    INSERT INTO address(postal_index,district,street,house,apartment) VALUES
        ('191000','Невский','Садовая ул.','3','2')       RETURNING id INTO a6;
    INSERT INTO address(postal_index,district,street,house,apartment) VALUES
        ('197000','Приморский','Парковая ул.','8','10')  RETURNING id INTO a8;
    INSERT INTO address(postal_index,district,street,house,apartment) VALUES
        ('197000','Приморский','Парковая ул.','8',NULL)  RETURNING id INTO a9;
    INSERT INTO address(postal_index,district,street,house,apartment) VALUES
        ('190000','Центральный','Невский пр.','12',NULL) RETURNING id INTO a10;
    INSERT INTO address(postal_index,district,street,house,apartment) VALUES
        ('190000','Центральный','Невский пр.','12','3')  RETURNING id INTO a11;

    --------------------------------------------------------------------- pbx
    INSERT INTO pbx(name,code,pbx_type,district,address_id,capacity_numbers,total_channels,free_channels,has_free_cable)
        VALUES ('ГТС Центральная','210','city','Центральный',a3,100,50,40,TRUE) RETURNING id INTO p_centr;
    INSERT INTO pbx_city(pbx_id,intercity_enabled,region_code) VALUES (p_centr,TRUE,'812');

    INSERT INTO pbx(name,code,pbx_type,district,address_id,capacity_numbers,total_channels,free_channels,has_free_cable)
        VALUES ('ГТС Невская','320','city','Невский',a6,100,30,2,FALSE) RETURNING id INTO p_nev;
    INSERT INTO pbx_city(pbx_id,intercity_enabled,region_code) VALUES (p_nev,TRUE,'812');

    INSERT INTO pbx(name,code,pbx_type,district,address_id,capacity_numbers,total_channels,free_channels,has_free_cable)
        VALUES ('Завод Арсенал АТС','500','departmental','Приморский',a9,50,20,10,TRUE) RETURNING id INTO p_zavod;
    INSERT INTO pbx_department(pbx_id,department_name,closed_network) VALUES (p_zavod,'ОАО Арсенал',TRUE);

    INSERT INTO pbx(name,code,pbx_type,district,address_id,capacity_numbers,total_channels,free_channels,has_free_cable)
        VALUES ('СПбГУ АТС','600','institutional','Центральный',a10,40,15,8,TRUE) RETURNING id INTO p_univ;
    INSERT INTO pbx_institution(pbx_id,institution_name,parent_department,closed_network)
        VALUES (p_univ,'СПбГУ','Минобрнауки',TRUE);

    ----------------------------------------------------------- phone numbers
    -- city PBX numbers (intercity open/closed); status is synced by trigger.
    INSERT INTO phone_number(number,pbx_id,line_type,intercity,address_id) VALUES ('2100001',p_centr,'main','open',a1)   RETURNING id INTO n1;
    INSERT INTO phone_number(number,pbx_id,line_type,intercity,address_id) VALUES ('2100002',p_centr,'parallel','open',a3) RETURNING id INTO n2;
    INSERT INTO phone_number(number,pbx_id,line_type,intercity,address_id) VALUES ('2100003',p_centr,'paired','closed',a10) RETURNING id INTO n3;
    INSERT INTO phone_number(number,pbx_id,line_type,intercity,address_id) VALUES ('2100010',p_centr,'main','open',NULL)  RETURNING id INTO n4;  -- free
    INSERT INTO phone_number(number,pbx_id,line_type,intercity,address_id) VALUES ('2100011',p_centr,'main','closed',NULL) RETURNING id INTO n5; -- free
    INSERT INTO phone_number(number,pbx_id,line_type,intercity,address_id) VALUES ('3200001',p_nev,'main','open',a6)      RETURNING id INTO n6;
    INSERT INTO phone_number(number,pbx_id,line_type,intercity,address_id) VALUES ('3200002',p_nev,'main','closed',a8)    RETURNING id INTO n7;
    INSERT INTO phone_number(number,pbx_id,line_type,intercity,address_id) VALUES ('3200010',p_nev,'main','open',NULL)    RETURNING id INTO n8;  -- free
    -- closed-network PBX numbers (intercity 'none')
    INSERT INTO phone_number(number,pbx_id,line_type,intercity,address_id) VALUES ('5000001',p_zavod,'main','none',a9)    RETURNING id INTO n9;
    INSERT INTO phone_number(number,pbx_id,line_type,intercity,address_id) VALUES ('5000002',p_zavod,'main','none',NULL)  RETURNING id INTO n10; -- free
    INSERT INTO phone_number(number,pbx_id,line_type,intercity,address_id) VALUES ('6000001',p_univ,'main','none',a10)    RETURNING id INTO n11;

    ------------------------------------------------------------- subscribers
    INSERT INTO subscriber(last_name,first_name,middle_name,gender,birth_date,category,privilege,phone_number_id,address_id,connected_at)
        VALUES ('Иванов','Иван','Иванович','male','1980-03-15','regular',NULL,n1,a1,'2020-01-10') RETURNING id INTO s1;
    INSERT INTO subscriber(last_name,first_name,middle_name,gender,birth_date,category,privilege,phone_number_id,address_id,connected_at)
        VALUES ('Петров','Пётр','Петрович','male','1955-06-01','privileged','pensioner',n2,a1,'2019-05-01') RETURNING id INTO s2;
    INSERT INTO subscriber(last_name,first_name,middle_name,gender,birth_date,category,privilege,phone_number_id,address_id,connected_at)
        VALUES ('Петрова','Анна','Сергеевна','female','1990-11-20','regular',NULL,n2,a2,'2019-05-01') RETURNING id INTO s3;
    INSERT INTO subscriber(last_name,first_name,middle_name,gender,birth_date,category,privilege,phone_number_id,address_id,connected_at)
        VALUES ('Сидоров','Алексей','Николаевич','male','1975-02-14','regular',NULL,n3,a4,'2018-09-01') RETURNING id INTO s4;
    INSERT INTO subscriber(last_name,first_name,middle_name,gender,birth_date,category,privilege,phone_number_id,address_id,connected_at)
        VALUES ('Сидорова','Мария','Ивановна','female','1978-07-30','regular',NULL,n3,a5,'2018-09-01') RETURNING id INTO s5;
    INSERT INTO subscriber(last_name,first_name,middle_name,gender,birth_date,category,privilege,phone_number_id,address_id,connected_at)
        VALUES ('Кузнецов','Дмитрий','Олегович','male','1965-04-12','regular',NULL,n6,a6,'2017-03-15') RETURNING id INTO s6;
    INSERT INTO subscriber(last_name,first_name,middle_name,gender,birth_date,category,privilege,phone_number_id,address_id,connected_at)
        VALUES ('Васильева','Ольга','Петровна','female','1948-08-22','privileged','pensioner',n7,a8,'2016-01-20') RETURNING id INTO s7;
    INSERT INTO subscriber(last_name,first_name,middle_name,gender,birth_date,category,privilege,phone_number_id,address_id,connected_at)
        VALUES ('Смирнов','Сергей','Андреевич','male','1985-12-05','regular',NULL,n9,a8,'2021-06-01') RETURNING id INTO s8;
    INSERT INTO subscriber(last_name,first_name,middle_name,gender,birth_date,category,privilege,phone_number_id,address_id,connected_at)
        VALUES ('Николаев','Игорь','Васильевич','male','1992-10-18','regular',NULL,n11,a11,'2022-09-01') RETURNING id INTO s9;

    --------------------------------------------------------- intercity calls
    INSERT INTO call_record(from_number_id,call_type,dest_city_id,started_at,duration_sec,cost) VALUES
        (n1,'intercity',c_msk,'2026-05-02 10:00+00',120,30.00),
        (n1,'intercity',c_msk,'2026-05-05 11:00+00', 60,15.00),
        (n1,'intercity',c_msk,'2026-05-09 12:00+00',200,50.00),
        (n2,'intercity',c_msk,'2026-05-03 09:00+00', 90,22.00),
        (n2,'intercity',c_msk,'2026-05-10 09:00+00', 90,22.00),
        (n6,'intercity',c_msk,'2026-05-04 14:00+00',150,40.00),
        (n6,'intercity',c_nsk,'2026-05-06 15:00+00',150,60.00),
        (n6,'intercity',c_ekb,'2026-05-07 16:00+00',150,55.00);
    -- external/internal calls for closed-network analytics (query 12)
    INSERT INTO call_record(from_number_id,call_type,started_at,duration_sec,cost) VALUES
        (n9,'external','2026-05-10 10:00+00',300,0),
        (n9,'internal','2026-05-11 10:00+00',120,0),
        (n11,'internal','2026-05-12 10:00+00',100,0);

    -------------------------------------------------------- invoices/billing
    -- debtor: Кузнецов (regular) — overdue since April, subscription + intercity
    INSERT INTO invoice(subscriber_id,kind,period_year,period_month,amount,due_date,status) VALUES
        (s6,'subscription',2026,4,350.00,'2026-04-20','overdue'),
        (s6,'subscription',2026,5,350.00,'2026-05-20','overdue'),
        (s6,'intercity',    2026,5,500.00,'2026-05-20','overdue');
    -- debtor: Васильева (privileged) — overdue subscription only (~2 weeks)
    INSERT INTO invoice(subscriber_id,kind,period_year,period_month,amount,due_date,status) VALUES
        (s7,'subscription',2026,5,100.00,'2026-05-20','overdue');
    -- non-debtor: Иванов — paid May subscription
    INSERT INTO invoice(subscriber_id,kind,period_year,period_month,amount,due_date,status)
        VALUES (s1,'subscription',2026,5,350.00,'2026-05-20','paid') RETURNING id INTO inv_s1;
    INSERT INTO payment(subscriber_id,invoice_id,amount,paid_at) VALUES (s1,inv_s1,350.00,'2026-05-15 12:00+00');

    -- penalty + written notice for the worst debtor
    INSERT INTO penalty(subscriber_id,invoice_id,amount,reason,accrued_at)
        VALUES (s6,NULL,50.00,'Просрочка абонентской платы','2026-05-21');
    INSERT INTO notification(subscriber_id,kind,sent_at,deadline,resolved)
        VALUES (s6,'subscription_debt','2026-05-25','2026-05-27',FALSE);

    ------------------------------------------------ public phones / payphones
    INSERT INTO public_phone(kind,pbx_id,address_id) VALUES
        ('payphone',p_centr,a3),
        ('public',  p_nev,  a6),
        ('payphone',p_zavod,a9);

    -------------------------------------------------------- installation queue
    INSERT INTO installation_queue(applicant_last_name,applicant_first_name,queue_type,address_id,desired_pbx_id,status) VALUES
        ('Морозова','Елена','privileged',a8,p_nev,'waiting'),
        ('Орлов','Виктор','regular',a6,p_centr,'waiting');
END $$;
