-- Each service account may connect only to its own database. The postgres
-- bootstrap superuser remains able to administer every database.
REVOKE CONNECT, TEMPORARY ON DATABASE keycloak_db FROM PUBLIC;
GRANT CONNECT ON DATABASE keycloak_db TO keycloak;

REVOKE CONNECT, TEMPORARY ON DATABASE catalogue_db FROM PUBLIC;
GRANT CONNECT ON DATABASE catalogue_db TO catalogue;

REVOKE CONNECT, TEMPORARY ON DATABASE inventory_db FROM PUBLIC;
GRANT CONNECT ON DATABASE inventory_db TO inventory;

REVOKE CONNECT, TEMPORARY ON DATABASE payments_db FROM PUBLIC;
GRANT CONNECT ON DATABASE payments_db TO payments;

REVOKE CONNECT, TEMPORARY ON DATABASE ticketing_db FROM PUBLIC;
GRANT CONNECT ON DATABASE ticketing_db TO ticketing;

REVOKE CONNECT, TEMPORARY ON DATABASE notifications_db FROM PUBLIC;
GRANT CONNECT ON DATABASE notifications_db TO notifications;
