--
-- PostgreSQL database dump
--

-- Dumped from database version 16.1 (Debian 16.1-1.pgdg120+1)
-- Dumped by pg_dump version 16.1 (Debian 16.1-1.pgdg120+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: mdm_app_version_comparison_index(text); Type: FUNCTION; Schema: public; Owner: hmdm
--

CREATE FUNCTION public.mdm_app_version_comparison_index(version_text text) RETURNS text
    LANGUAGE plpgsql
    AS $$

            DECLARE parts TEXT[];
            DECLARE i INT;
            DECLARE result TEXT;
            DECLARE part TEXT;
            BEGIN
            IF version_text IS NULL THEN
            return -1000000;
            END IF;

            IF LENGTH(TRIM(version_text)) = 0 THEN
            return -1000000;
            END IF;

            result = '';

            parts = STRING_TO_ARRAY(version_text, '.');

            FOR i IN 1 .. ARRAY_UPPER(parts, 1) LOOP
            part = REGEXP_REPLACE(parts[i], '[^0-9]+', '', 'g');

            IF LENGTH(TRIM(part)) = 0 THEN
            part = '0';
            END IF;

            result = result || LPAD(part, 10, '0');
            END LOOP;

            RETURN result;
            END;
            $$;


ALTER FUNCTION public.mdm_app_version_comparison_index(version_text text) OWNER TO hmdm;

--
-- Name: mdm_config_app_upgrade(bigint, bigint); Type: FUNCTION; Schema: public; Owner: hmdm
--

CREATE FUNCTION public.mdm_config_app_upgrade(configid bigint, appid bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$

            BEGIN
            -- Deleting existing record for latest version of app for configuration
            DELETE
            FROM configurationApplications
            WHERE configurationId = configId
            AND applicationId = appId
            AND applicationVersionId = (SELECT latestVersion FROM applications WHERE applications.id = appId);

            -- Change the current record for installed version of application to refer to latest version
            UPDATE configurationApplications
            SET applicationVersionId = (SELECT latestVersion FROM applications WHERE applications.id = appId)
            WHERE configurationId = configId
            AND applicationId = appId
            AND action = 1;


            -- Upgrade reference to main application if necessary
            UPDATE configurations
            SET mainAppId = (SELECT latestVersion FROM applications WHERE applications.id = appId)
            WHERE configurations.id = configId
            AND NOT configurations.mainAppId IS NULL
            AND EXISTS(SELECT 1
            FROM applicationVersions
            WHERE applicationVersions.id = configurations.mainAppId
            AND applicationVersions.applicationId = appId);

            -- Upgrade reference to content application if necessary
            UPDATE configurations
            SET contentAppId = (SELECT latestVersion FROM applications WHERE applications.id = appId)
            WHERE configurations.id = configId
            AND NOT configurations.contentAppId IS NULL
            AND EXISTS(SELECT 1
            FROM applicationVersions
            WHERE applicationVersions.id = configurations.contentAppId
            AND applicationVersions.applicationId = appId);

            RETURN 0;
            END;
            $$;


ALTER FUNCTION public.mdm_config_app_upgrade(configid bigint, appid bigint) OWNER TO hmdm;

--
-- Name: mdm_device_launcher_version(text, text); Type: FUNCTION; Schema: public; Owner: hmdm
--

CREATE FUNCTION public.mdm_device_launcher_version(launcherapppkg text, device_info text) RETURNS text
    LANGUAGE plpgsql
    AS $$
            DECLARE
            deviceApps    json;
            DECLARE i      INT;
            DECLARE count  INT;
            DECLARE app json;
            BEGIN
            IF launcherAppPkg IS NULL THEN
            RETURN NULL;
            END IF;

            IF device_info IS NULL THEN
            RETURN NULL;
            END IF;

            deviceApps = device_info::json -> 'applications';
            count = json_array_length(deviceApps);

            FOR i IN 1 .. count
            LOOP
            app = deviceApps ->> (i - 1);
            IF (app ->> 'pkg') = launcherAppPkg THEN
            RETURN app ->> 'version';
            END IF;
            END LOOP;

            RETURN NULL;
            END
            $$;


ALTER FUNCTION public.mdm_device_launcher_version(launcherapppkg text, device_info text) OWNER TO hmdm;

--
-- Name: mdm_device_permissions_index(text); Type: FUNCTION; Schema: public; Owner: hmdm
--

CREATE FUNCTION public.mdm_device_permissions_index(device_info text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
            DECLARE
            permissions    json;
            DECLARE i      INT;
            DECLARE count  INT;
            DECLARE result INT;
            BEGIN
            IF device_info IS NULL THEN
            return -1;
            END IF;

            IF LENGTH(TRIM(device_info)) = 0 THEN
            return -1;
            END IF;

            permissions = device_info::json -> 'permissions';

            count = json_array_length(permissions::json);

            result = 0;

            FOR i IN 1 .. count
            LOOP
            result = result + (permissions::json ->> (i - 1))::int;
            END LOOP;


            RETURN result;
            END ;
            $$;


ALTER FUNCTION public.mdm_device_permissions_index(device_info text) OWNER TO hmdm;

--
-- Name: mdm_resolve_device_property(text, text); Type: FUNCTION; Schema: public; Owner: hmdm
--

CREATE FUNCTION public.mdm_resolve_device_property(server_data text, device_data text) RETURNS text
    LANGUAGE plpgsql
    AS $$
            BEGIN
            server_data = COALESCE(server_data, '');
            device_data = COALESCE(device_data, '');

            IF (server_data = device_data) THEN
            RETURN server_data;
            END IF;

            IF LENGTH(device_data) > 0 THEN
            RETURN device_data;
            END IF;

            RETURN server_data;
            END
            $$;


ALTER FUNCTION public.mdm_resolve_device_property(server_data text, device_data text) OWNER TO hmdm;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: applicationfilestocopytemp; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.applicationfilestocopytemp (
    url character varying(500),
    "?column?" text,
    newurl character varying(500)
);


ALTER TABLE public.applicationfilestocopytemp OWNER TO hmdm;

--
-- Name: applications; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.applications (
    id integer NOT NULL,
    pkg character varying(100) NOT NULL,
    name character varying(500) NOT NULL,
    showicon boolean DEFAULT false NOT NULL,
    customerid bigint,
    system boolean DEFAULT false NOT NULL,
    latestversion integer,
    runafterinstall boolean DEFAULT false NOT NULL,
    type character varying(10) DEFAULT 'app'::character varying NOT NULL,
    icontext character varying(256),
    iconid integer,
    runatboot boolean DEFAULT false NOT NULL,
    usekiosk boolean DEFAULT false NOT NULL,
    intent text
);


ALTER TABLE public.applications OWNER TO hmdm;

--
-- Name: applications_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.applications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.applications_id_seq OWNER TO hmdm;

--
-- Name: applications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.applications_id_seq OWNED BY public.applications.id;


--
-- Name: applicationversions; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.applicationversions (
    id integer NOT NULL,
    applicationid integer NOT NULL,
    version character varying(50) NOT NULL,
    url character varying(500),
    apkhash character varying(100),
    split boolean DEFAULT false NOT NULL,
    urlarmeabi text,
    urlarm64 text,
    versioncode integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.applicationversions OWNER TO hmdm;

--
-- Name: applicationversions_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.applicationversions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.applicationversions_id_seq OWNER TO hmdm;

--
-- Name: applicationversions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.applicationversions_id_seq OWNED BY public.applicationversions.id;


--
-- Name: applicationversionstemp; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.applicationversionstemp (
    to_be_deleted boolean,
    to_be_replaced boolean,
    id integer,
    newapplicationid integer,
    newapplicationversionid integer,
    newurl character varying(500),
    name character varying(500),
    pkg character varying(100),
    version character varying(100),
    url character varying(500),
    customerid bigint,
    ismastercustomer boolean,
    masterappexists boolean,
    masterversionexists boolean
);


ALTER TABLE public.applicationversionstemp OWNER TO hmdm;

--
-- Name: configurationapplicationparameters; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.configurationapplicationparameters (
    id integer NOT NULL,
    configurationid integer NOT NULL,
    applicationid integer NOT NULL,
    skipversioncheck boolean DEFAULT false NOT NULL
);


ALTER TABLE public.configurationapplicationparameters OWNER TO hmdm;

--
-- Name: configurationapplicationparameters_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.configurationapplicationparameters_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.configurationapplicationparameters_id_seq OWNER TO hmdm;

--
-- Name: configurationapplicationparameters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.configurationapplicationparameters_id_seq OWNED BY public.configurationapplicationparameters.id;


--
-- Name: configurationapplications; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.configurationapplications (
    id integer NOT NULL,
    configurationid integer NOT NULL,
    applicationid integer NOT NULL,
    remove boolean DEFAULT false NOT NULL,
    showicon boolean DEFAULT false NOT NULL,
    applicationversionid integer,
    action integer DEFAULT 1 NOT NULL,
    screenorder integer,
    keycode integer,
    bottom boolean DEFAULT false NOT NULL,
    longtap boolean DEFAULT false NOT NULL
);


ALTER TABLE public.configurationapplications OWNER TO hmdm;

--
-- Name: configurationapplications_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.configurationapplications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.configurationapplications_id_seq OWNER TO hmdm;

--
-- Name: configurationapplications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.configurationapplications_id_seq OWNED BY public.configurationapplications.id;


--
-- Name: configurationapplicationsettings; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.configurationapplicationsettings (
    id integer NOT NULL,
    applicationid integer NOT NULL,
    name character varying(200) NOT NULL,
    type character varying(20) NOT NULL,
    value text,
    comment text,
    readonly boolean DEFAULT false NOT NULL,
    extrefid integer NOT NULL,
    lastupdate bigint NOT NULL
);


ALTER TABLE public.configurationapplicationsettings OWNER TO hmdm;

--
-- Name: configurationapplicationsettings_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.configurationapplicationsettings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.configurationapplicationsettings_id_seq OWNER TO hmdm;

--
-- Name: configurationapplicationsettings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.configurationapplicationsettings_id_seq OWNED BY public.configurationapplicationsettings.id;


--
-- Name: configurationfiles; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.configurationfiles (
    id integer NOT NULL,
    configurationid integer NOT NULL,
    description text,
    devicepath text NOT NULL,
    externalurl text,
    filepath text,
    checksum text,
    remove boolean DEFAULT false NOT NULL,
    lastupdate bigint DEFAULT (EXTRACT(epoch FROM now()) * (1000)::numeric) NOT NULL,
    fileid integer,
    replacevariables boolean DEFAULT false NOT NULL
);


ALTER TABLE public.configurationfiles OWNER TO hmdm;

--
-- Name: configurationfiles_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.configurationfiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.configurationfiles_id_seq OWNER TO hmdm;

--
-- Name: configurationfiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.configurationfiles_id_seq OWNED BY public.configurationfiles.id;


--
-- Name: configurations; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.configurations (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    type integer DEFAULT 0 NOT NULL,
    password character varying(100),
    backgroundcolor character varying(20),
    textcolor character varying(20),
    backgroundimageurl character varying(500),
    iconsize text DEFAULT 'SMALL'::text NOT NULL,
    desktopheader text DEFAULT 'NO_HEADER'::text NOT NULL,
    usedefaultdesignsettings boolean DEFAULT true NOT NULL,
    customerid bigint,
    gps boolean,
    bluetooth boolean,
    wifi boolean,
    mobiledata boolean,
    mainappid integer,
    eventreceivingcomponent character varying(512),
    kioskmode boolean DEFAULT false NOT NULL,
    qrcodekey text DEFAULT md5((random())::text) NOT NULL,
    contentappid integer,
    autoupdate boolean DEFAULT false NOT NULL,
    blockstatusbar boolean DEFAULT false NOT NULL,
    systemupdatetype integer DEFAULT 0 NOT NULL,
    systemupdatefrom character varying(10),
    systemupdateto character varying(10),
    usbstorage boolean,
    requestupdates character varying(20) DEFAULT 'DONOTTRACK'::character varying NOT NULL,
    pushoptions character varying(20) DEFAULT 'mqttWorker'::character varying NOT NULL,
    autobrightness boolean,
    brightness integer DEFAULT 180,
    managetimeout boolean DEFAULT false,
    timeout integer DEFAULT 60,
    lockvolume boolean DEFAULT false,
    wifissid character varying(256),
    wifipassword character varying(256),
    wifisecuritytype character varying(16),
    passwordmode character varying(50),
    kioskhome boolean,
    kioskrecents boolean,
    kiosknotifications boolean,
    kiosksysteminfo boolean,
    kioskkeyguard boolean,
    orientation integer,
    rundefaultlauncher boolean,
    timezone character varying(200),
    allowedclasses text,
    newserverurl text,
    locksafesettings boolean,
    disablescreenshots boolean,
    restrictions text,
    defaultfilepath text DEFAULT '/'::text NOT NULL,
    keepalivetime integer,
    managevolume boolean,
    volume integer,
    showwifi boolean,
    mobileenrollment boolean DEFAULT false NOT NULL,
    desktopheadertemplate text,
    kiosklockbuttons boolean,
    scheduleappupdate boolean,
    appupdatefrom character varying(10),
    appupdateto character varying(10),
    disablelocation boolean DEFAULT false NOT NULL,
    apppermissions character varying(20) DEFAULT 'GRANTALL'::character varying NOT NULL,
    permissive boolean,
    kioskexit boolean DEFAULT true,
    qrparameters text,
    autostartforeground boolean,
    displaystatus boolean DEFAULT false NOT NULL,
    encryptdevice boolean DEFAULT false NOT NULL,
    downloadupdates character varying(20) DEFAULT 'UNLIMITED'::character varying NOT NULL
);


ALTER TABLE public.configurations OWNER TO hmdm;

--
-- Name: configurations_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.configurations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.configurations_id_seq OWNER TO hmdm;

--
-- Name: configurations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.configurations_id_seq OWNED BY public.configurations.id;


--
-- Name: customers; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.customers (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text,
    filesdir text NOT NULL,
    master boolean DEFAULT false NOT NULL,
    prefix character varying(100) NOT NULL,
    registrationtime bigint,
    lastlogintime bigint,
    accounttype integer DEFAULT 0 NOT NULL,
    expirytime bigint,
    devicelimit integer DEFAULT 3 NOT NULL,
    customerstatus character varying(100),
    email character varying(50),
    firstname character varying(100),
    lastname character varying(100),
    language character varying(100),
    inactivestate integer DEFAULT 0 NOT NULL,
    pausestate integer DEFAULT 0 NOT NULL,
    abandonstate integer DEFAULT 0 NOT NULL,
    sizelimit integer DEFAULT 100 NOT NULL,
    signupstatus character varying(100) DEFAULT 'active'::character varying,
    signuptoken character varying(100)
);


ALTER TABLE public.customers OWNER TO hmdm;

--
-- Name: customers_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.customers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customers_id_seq OWNER TO hmdm;

--
-- Name: customers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.customers_id_seq OWNED BY public.customers.id;


--
-- Name: databasechangelog; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.databasechangelog (
    id character varying(255) NOT NULL,
    author character varying(255) NOT NULL,
    filename character varying(255) NOT NULL,
    dateexecuted timestamp without time zone NOT NULL,
    orderexecuted integer NOT NULL,
    exectype character varying(10) NOT NULL,
    md5sum character varying(35),
    description character varying(255),
    comments character varying(255),
    tag character varying(255),
    liquibase character varying(20),
    contexts character varying(255),
    labels character varying(255),
    deployment_id character varying(10)
);


ALTER TABLE public.databasechangelog OWNER TO hmdm;

--
-- Name: databasechangeloglock; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.databasechangeloglock (
    id integer NOT NULL,
    locked boolean NOT NULL,
    lockgranted timestamp without time zone,
    lockedby character varying(255)
);


ALTER TABLE public.databasechangeloglock OWNER TO hmdm;

--
-- Name: deviceapplicationsettings; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.deviceapplicationsettings (
    id integer NOT NULL,
    applicationid integer NOT NULL,
    name character varying(200) NOT NULL,
    type character varying(20) NOT NULL,
    value text,
    comment text,
    readonly boolean DEFAULT false NOT NULL,
    extrefid integer NOT NULL,
    lastupdate bigint NOT NULL
);


ALTER TABLE public.deviceapplicationsettings OWNER TO hmdm;

--
-- Name: deviceapplicationsettings_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.deviceapplicationsettings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.deviceapplicationsettings_id_seq OWNER TO hmdm;

--
-- Name: deviceapplicationsettings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.deviceapplicationsettings_id_seq OWNED BY public.deviceapplicationsettings.id;


--
-- Name: devicegroups; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.devicegroups (
    id integer NOT NULL,
    deviceid integer NOT NULL,
    groupid integer NOT NULL
);


ALTER TABLE public.devicegroups OWNER TO hmdm;

--
-- Name: devicegroups_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.devicegroups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.devicegroups_id_seq OWNER TO hmdm;

--
-- Name: devicegroups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.devicegroups_id_seq OWNED BY public.devicegroups.id;


--
-- Name: devices; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.devices (
    id integer NOT NULL,
    number character varying(100) NOT NULL,
    description text,
    lastupdate bigint DEFAULT 0 NOT NULL,
    configurationid integer NOT NULL,
    oldconfigurationid integer,
    info text,
    imei character varying(50),
    phone character varying(20),
    customerid bigint,
    imeiupdatets bigint,
    custom1 text,
    custom2 text,
    custom3 text,
    oldnumber character varying(100),
    fastsearch character varying(100),
    enrolltime bigint,
    infojson jsonb,
    publicip character varying(100)
);


ALTER TABLE public.devices OWNER TO hmdm;

--
-- Name: devices_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.devices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.devices_id_seq OWNER TO hmdm;

--
-- Name: devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.devices_id_seq OWNED BY public.devices.id;


--
-- Name: devicestatuses; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.devicestatuses (
    deviceid integer NOT NULL,
    configfilesstatus character varying(100),
    applicationsstatus character varying(100)
);


ALTER TABLE public.devicestatuses OWNER TO hmdm;

--
-- Name: groups; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.groups (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    customerid bigint
);


ALTER TABLE public.groups OWNER TO hmdm;

--
-- Name: groups_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.groups_id_seq OWNER TO hmdm;

--
-- Name: groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.groups_id_seq OWNED BY public.groups.id;


--
-- Name: icons; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.icons (
    id integer NOT NULL,
    customerid integer NOT NULL,
    name character varying(64) NOT NULL,
    fileid integer NOT NULL
);


ALTER TABLE public.icons OWNER TO hmdm;

--
-- Name: icons_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.icons_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.icons_id_seq OWNER TO hmdm;

--
-- Name: icons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.icons_id_seq OWNED BY public.icons.id;


--
-- Name: pendingpushes; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.pendingpushes (
    id integer NOT NULL,
    messageid integer NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    createtime bigint NOT NULL,
    sendtime bigint
);


ALTER TABLE public.pendingpushes OWNER TO hmdm;

--
-- Name: pendingpushes_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.pendingpushes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pendingpushes_id_seq OWNER TO hmdm;

--
-- Name: pendingpushes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.pendingpushes_id_seq OWNED BY public.pendingpushes.id;


--
-- Name: pendingsignup; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.pendingsignup (
    id integer NOT NULL,
    email character varying(50) NOT NULL,
    signuptime bigint,
    language character varying(50),
    token character varying(50)
);


ALTER TABLE public.pendingsignup OWNER TO hmdm;

--
-- Name: pendingsignup_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.pendingsignup_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pendingsignup_id_seq OWNER TO hmdm;

--
-- Name: pendingsignup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.pendingsignup_id_seq OWNED BY public.pendingsignup.id;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.permissions (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text,
    superadmin boolean DEFAULT false NOT NULL
);


ALTER TABLE public.permissions OWNER TO hmdm;

--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.permissions_id_seq OWNER TO hmdm;

--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- Name: plugin_audit_log; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugin_audit_log (
    id integer NOT NULL,
    createtime bigint DEFAULT (EXTRACT(epoch FROM now()) * (1000)::numeric) NOT NULL,
    customerid integer,
    userid integer,
    login character varying(100),
    action character varying(100),
    payload text,
    ipaddress character varying(500),
    errorcode integer DEFAULT 0
);


ALTER TABLE public.plugin_audit_log OWNER TO hmdm;

--
-- Name: plugin_audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.plugin_audit_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plugin_audit_log_id_seq OWNER TO hmdm;

--
-- Name: plugin_audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.plugin_audit_log_id_seq OWNED BY public.plugin_audit_log.id;


--
-- Name: plugin_deviceinfo_deviceparams; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugin_deviceinfo_deviceparams (
    id integer NOT NULL,
    deviceid integer NOT NULL,
    customerid integer NOT NULL,
    ts bigint NOT NULL
);


ALTER TABLE public.plugin_deviceinfo_deviceparams OWNER TO hmdm;

--
-- Name: plugin_deviceinfo_deviceparams_device; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugin_deviceinfo_deviceparams_device (
    id integer NOT NULL,
    recordid integer NOT NULL,
    batterylevel integer,
    batterycharging character varying(20),
    ip character varying(50),
    keyguard boolean,
    ringvolume integer,
    wifi boolean,
    mobiledata boolean,
    gps boolean,
    bluetooth boolean,
    usbstorage boolean,
    memorytotal integer,
    memoryavailable integer
);


ALTER TABLE public.plugin_deviceinfo_deviceparams_device OWNER TO hmdm;

--
-- Name: plugin_deviceinfo_deviceparams_device_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.plugin_deviceinfo_deviceparams_device_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plugin_deviceinfo_deviceparams_device_id_seq OWNER TO hmdm;

--
-- Name: plugin_deviceinfo_deviceparams_device_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.plugin_deviceinfo_deviceparams_device_id_seq OWNED BY public.plugin_deviceinfo_deviceparams_device.id;


--
-- Name: plugin_deviceinfo_deviceparams_gps; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugin_deviceinfo_deviceparams_gps (
    id integer NOT NULL,
    recordid integer NOT NULL,
    state character varying(20),
    lat double precision,
    lon double precision,
    alt double precision,
    speed double precision,
    course double precision
);


ALTER TABLE public.plugin_deviceinfo_deviceparams_gps OWNER TO hmdm;

--
-- Name: plugin_deviceinfo_deviceparams_gps_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.plugin_deviceinfo_deviceparams_gps_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plugin_deviceinfo_deviceparams_gps_id_seq OWNER TO hmdm;

--
-- Name: plugin_deviceinfo_deviceparams_gps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.plugin_deviceinfo_deviceparams_gps_id_seq OWNED BY public.plugin_deviceinfo_deviceparams_gps.id;


--
-- Name: plugin_deviceinfo_deviceparams_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.plugin_deviceinfo_deviceparams_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plugin_deviceinfo_deviceparams_id_seq OWNER TO hmdm;

--
-- Name: plugin_deviceinfo_deviceparams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.plugin_deviceinfo_deviceparams_id_seq OWNED BY public.plugin_deviceinfo_deviceparams.id;


--
-- Name: plugin_deviceinfo_deviceparams_mobile; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugin_deviceinfo_deviceparams_mobile (
    id integer NOT NULL,
    recordid integer NOT NULL,
    rssi integer,
    carrier character varying(50),
    data boolean,
    ip character varying(50),
    state character varying(20),
    simstate character varying(20),
    tx bigint,
    rx bigint
);


ALTER TABLE public.plugin_deviceinfo_deviceparams_mobile OWNER TO hmdm;

--
-- Name: plugin_deviceinfo_deviceparams_mobile2; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugin_deviceinfo_deviceparams_mobile2 (
    id integer NOT NULL,
    recordid integer NOT NULL,
    rssi integer,
    carrier character varying(50),
    data boolean,
    ip character varying(50),
    state character varying(20),
    simstate character varying(20),
    tx bigint,
    rx bigint
);


ALTER TABLE public.plugin_deviceinfo_deviceparams_mobile2 OWNER TO hmdm;

--
-- Name: plugin_deviceinfo_deviceparams_mobile2_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.plugin_deviceinfo_deviceparams_mobile2_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plugin_deviceinfo_deviceparams_mobile2_id_seq OWNER TO hmdm;

--
-- Name: plugin_deviceinfo_deviceparams_mobile2_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.plugin_deviceinfo_deviceparams_mobile2_id_seq OWNED BY public.plugin_deviceinfo_deviceparams_mobile2.id;


--
-- Name: plugin_deviceinfo_deviceparams_mobile_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.plugin_deviceinfo_deviceparams_mobile_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plugin_deviceinfo_deviceparams_mobile_id_seq OWNER TO hmdm;

--
-- Name: plugin_deviceinfo_deviceparams_mobile_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.plugin_deviceinfo_deviceparams_mobile_id_seq OWNED BY public.plugin_deviceinfo_deviceparams_mobile.id;


--
-- Name: plugin_deviceinfo_deviceparams_wifi; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugin_deviceinfo_deviceparams_wifi (
    id integer NOT NULL,
    recordid integer NOT NULL,
    rssi integer,
    ssid character varying(500),
    security character varying(500),
    state character varying(20),
    ip character varying(50),
    tx bigint,
    rx bigint
);


ALTER TABLE public.plugin_deviceinfo_deviceparams_wifi OWNER TO hmdm;

--
-- Name: plugin_deviceinfo_deviceparams_wifi_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.plugin_deviceinfo_deviceparams_wifi_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plugin_deviceinfo_deviceparams_wifi_id_seq OWNER TO hmdm;

--
-- Name: plugin_deviceinfo_deviceparams_wifi_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.plugin_deviceinfo_deviceparams_wifi_id_seq OWNED BY public.plugin_deviceinfo_deviceparams_wifi.id;


--
-- Name: plugin_deviceinfo_settings; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugin_deviceinfo_settings (
    id integer NOT NULL,
    customerid integer NOT NULL,
    datapreserveperiod integer DEFAULT 30 NOT NULL,
    senddata boolean DEFAULT false NOT NULL,
    intervalmins integer DEFAULT 15 NOT NULL
);


ALTER TABLE public.plugin_deviceinfo_settings OWNER TO hmdm;

--
-- Name: plugin_deviceinfo_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.plugin_deviceinfo_settings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plugin_deviceinfo_settings_id_seq OWNER TO hmdm;

--
-- Name: plugin_deviceinfo_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.plugin_deviceinfo_settings_id_seq OWNED BY public.plugin_deviceinfo_settings.id;


--
-- Name: plugin_devicelog_log; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugin_devicelog_log (
    id integer NOT NULL,
    createtime bigint,
    customerid integer NOT NULL,
    deviceid integer NOT NULL,
    applicationid integer NOT NULL,
    ipaddress character varying(512),
    severity text,
    severityorder integer,
    message text
);


ALTER TABLE public.plugin_devicelog_log OWNER TO hmdm;

--
-- Name: plugin_devicelog_log_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.plugin_devicelog_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plugin_devicelog_log_id_seq OWNER TO hmdm;

--
-- Name: plugin_devicelog_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.plugin_devicelog_log_id_seq OWNED BY public.plugin_devicelog_log.id;


--
-- Name: plugin_devicelog_setting_rule_devices; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugin_devicelog_setting_rule_devices (
    ruleid integer NOT NULL,
    deviceid integer NOT NULL
);


ALTER TABLE public.plugin_devicelog_setting_rule_devices OWNER TO hmdm;

--
-- Name: plugin_devicelog_settings; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugin_devicelog_settings (
    id integer NOT NULL,
    customerid integer NOT NULL,
    logspreserveperiod integer DEFAULT 30 NOT NULL
);


ALTER TABLE public.plugin_devicelog_settings OWNER TO hmdm;

--
-- Name: plugin_devicelog_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.plugin_devicelog_settings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plugin_devicelog_settings_id_seq OWNER TO hmdm;

--
-- Name: plugin_devicelog_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.plugin_devicelog_settings_id_seq OWNED BY public.plugin_devicelog_settings.id;


--
-- Name: plugin_devicelog_settings_rules; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugin_devicelog_settings_rules (
    id integer NOT NULL,
    settingid integer NOT NULL,
    name character varying(120) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    applicationid integer NOT NULL,
    severity text NOT NULL,
    filter text,
    groupid integer,
    configurationid integer
);


ALTER TABLE public.plugin_devicelog_settings_rules OWNER TO hmdm;

--
-- Name: plugin_devicelog_settings_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.plugin_devicelog_settings_rules_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plugin_devicelog_settings_rules_id_seq OWNER TO hmdm;

--
-- Name: plugin_devicelog_settings_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.plugin_devicelog_settings_rules_id_seq OWNED BY public.plugin_devicelog_settings_rules.id;


--
-- Name: plugin_messaging_messages; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugin_messaging_messages (
    id integer NOT NULL,
    customerid integer NOT NULL,
    deviceid integer NOT NULL,
    ts bigint NOT NULL,
    message character varying(5000),
    status integer NOT NULL
);


ALTER TABLE public.plugin_messaging_messages OWNER TO hmdm;

--
-- Name: plugin_messaging_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.plugin_messaging_messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plugin_messaging_messages_id_seq OWNER TO hmdm;

--
-- Name: plugin_messaging_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.plugin_messaging_messages_id_seq OWNED BY public.plugin_messaging_messages.id;


--
-- Name: plugin_push_messages; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugin_push_messages (
    id integer NOT NULL,
    customerid integer NOT NULL,
    deviceid integer NOT NULL,
    ts bigint NOT NULL,
    messagetype character varying(255),
    payload text
);


ALTER TABLE public.plugin_push_messages OWNER TO hmdm;

--
-- Name: plugin_push_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.plugin_push_messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plugin_push_messages_id_seq OWNER TO hmdm;

--
-- Name: plugin_push_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.plugin_push_messages_id_seq OWNED BY public.plugin_push_messages.id;


--
-- Name: plugin_push_schedule; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugin_push_schedule (
    id integer NOT NULL,
    customerid integer NOT NULL,
    deviceid integer DEFAULT 0 NOT NULL,
    groupid integer DEFAULT 0 NOT NULL,
    configurationid integer DEFAULT 0 NOT NULL,
    scope character varying(255),
    messagetype character varying(255),
    payload text,
    comment text,
    min character varying(1024),
    minbit bit(60),
    hour character varying(1024),
    hourbit bit(24),
    day character varying(1024),
    daybit bit(31),
    weekday character varying(1024),
    weekdaybit bit(7),
    month character varying(1024),
    monthbit bit(12)
);


ALTER TABLE public.plugin_push_schedule OWNER TO hmdm;

--
-- Name: plugin_push_schedule_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.plugin_push_schedule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plugin_push_schedule_id_seq OWNER TO hmdm;

--
-- Name: plugin_push_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.plugin_push_schedule_id_seq OWNED BY public.plugin_push_schedule.id;


--
-- Name: plugins; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.plugins (
    id integer NOT NULL,
    identifier character varying(50) NOT NULL,
    name text NOT NULL,
    description text,
    createtime timestamp without time zone DEFAULT now() NOT NULL,
    disabled boolean DEFAULT false NOT NULL,
    javascriptmodulefile character varying(200),
    functionsviewtemplate character varying(200),
    settingsviewtemplate character varying(200),
    namelocalizationkey character varying(200) DEFAULT 'plugin.name.not.specified'::character varying NOT NULL,
    settingspermission character varying(200),
    functionspermission character varying(200),
    devicefunctionspermission character varying(200),
    enabledfordevice boolean DEFAULT false NOT NULL
);


ALTER TABLE public.plugins OWNER TO hmdm;

--
-- Name: plugins_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.plugins_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plugins_id_seq OWNER TO hmdm;

--
-- Name: plugins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.plugins_id_seq OWNED BY public.plugins.id;


--
-- Name: pluginsdisabled; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.pluginsdisabled (
    pluginid integer NOT NULL,
    customerid integer NOT NULL
);


ALTER TABLE public.pluginsdisabled OWNER TO hmdm;

--
-- Name: pushmessages; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.pushmessages (
    id integer NOT NULL,
    messagetype character varying(50) NOT NULL,
    deviceid integer NOT NULL,
    payload text
);


ALTER TABLE public.pushmessages OWNER TO hmdm;

--
-- Name: pushmessages_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.pushmessages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pushmessages_id_seq OWNER TO hmdm;

--
-- Name: pushmessages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.pushmessages_id_seq OWNED BY public.pushmessages.id;


--
-- Name: settings; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.settings (
    id integer NOT NULL,
    backgroundcolor character varying(20),
    textcolor character varying(20),
    backgroundimageurl character varying(500),
    iconsize text DEFAULT 'SMALL'::text NOT NULL,
    desktopheader text DEFAULT 'NO_HEADER'::text NOT NULL,
    customerid bigint,
    usedefaultlanguage boolean DEFAULT true NOT NULL,
    language character varying(20),
    createnewdevices boolean DEFAULT false NOT NULL,
    newdevicegroupid integer,
    newdeviceconfigurationid integer,
    phonenumberformat character varying(50) DEFAULT '+9 (999) 999-99-99'::character varying,
    custompropertyname1 character varying(200),
    custompropertyname2 character varying(200),
    custompropertyname3 character varying(200),
    custommultiline1 boolean DEFAULT false NOT NULL,
    custommultiline2 boolean DEFAULT false NOT NULL,
    custommultiline3 boolean DEFAULT false NOT NULL,
    customsend1 boolean DEFAULT false NOT NULL,
    customsend2 boolean DEFAULT false NOT NULL,
    customsend3 boolean DEFAULT false NOT NULL,
    desktopheadertemplate text,
    senddescription boolean DEFAULT false NOT NULL,
    passwordreset boolean DEFAULT false NOT NULL,
    passwordlength integer DEFAULT 0 NOT NULL,
    passwordstrength integer DEFAULT 0 NOT NULL,
    twofactor boolean DEFAULT false NOT NULL,
    idlelogout integer
);


ALTER TABLE public.settings OWNER TO hmdm;

--
-- Name: settings_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.settings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.settings_id_seq OWNER TO hmdm;

--
-- Name: settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.settings_id_seq OWNED BY public.settings.id;


--
-- Name: trialkey; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.trialkey (
    id integer NOT NULL,
    keycode character varying(50) NOT NULL,
    created timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.trialkey OWNER TO hmdm;

--
-- Name: trialkey_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.trialkey_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.trialkey_id_seq OWNER TO hmdm;

--
-- Name: trialkey_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.trialkey_id_seq OWNED BY public.trialkey.id;


--
-- Name: uploadedfiles; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.uploadedfiles (
    id integer NOT NULL,
    customerid integer NOT NULL,
    filepath text NOT NULL,
    uploadtime bigint DEFAULT (EXTRACT(epoch FROM now()) * (1000)::numeric) NOT NULL
);


ALTER TABLE public.uploadedfiles OWNER TO hmdm;

--
-- Name: uploadedfiles_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.uploadedfiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.uploadedfiles_id_seq OWNER TO hmdm;

--
-- Name: uploadedfiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.uploadedfiles_id_seq OWNED BY public.uploadedfiles.id;


--
-- Name: usagestats; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.usagestats (
    id integer NOT NULL,
    ts date DEFAULT CURRENT_DATE NOT NULL,
    instanceid character varying(255),
    webversion character varying(255),
    community boolean DEFAULT true NOT NULL,
    devicestotal integer DEFAULT 0 NOT NULL,
    devicesonline integer DEFAULT 0 NOT NULL,
    cputotal integer DEFAULT 0 NOT NULL,
    cpuused integer DEFAULT 0 NOT NULL,
    ramtotal integer DEFAULT 0 NOT NULL,
    ramused integer DEFAULT 0 NOT NULL,
    scheme character varying(255),
    arch character varying(255),
    os character varying(255)
);


ALTER TABLE public.usagestats OWNER TO hmdm;

--
-- Name: usagestats_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.usagestats_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.usagestats_id_seq OWNER TO hmdm;

--
-- Name: usagestats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.usagestats_id_seq OWNED BY public.usagestats.id;


--
-- Name: userconfigurationaccess; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.userconfigurationaccess (
    id integer NOT NULL,
    userid integer NOT NULL,
    configurationid integer NOT NULL
);


ALTER TABLE public.userconfigurationaccess OWNER TO hmdm;

--
-- Name: userconfigurationaccess_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.userconfigurationaccess_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.userconfigurationaccess_id_seq OWNER TO hmdm;

--
-- Name: userconfigurationaccess_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.userconfigurationaccess_id_seq OWNED BY public.userconfigurationaccess.id;


--
-- Name: userdevicegroupsaccess; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.userdevicegroupsaccess (
    id integer NOT NULL,
    userid integer NOT NULL,
    groupid integer NOT NULL
);


ALTER TABLE public.userdevicegroupsaccess OWNER TO hmdm;

--
-- Name: userdevicegroupsaccess_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.userdevicegroupsaccess_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.userdevicegroupsaccess_id_seq OWNER TO hmdm;

--
-- Name: userdevicegroupsaccess_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.userdevicegroupsaccess_id_seq OWNED BY public.userdevicegroupsaccess.id;


--
-- Name: userhints; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.userhints (
    id integer NOT NULL,
    userid integer NOT NULL,
    hintkey character varying(100) NOT NULL,
    created timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.userhints OWNER TO hmdm;

--
-- Name: userhints_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.userhints_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.userhints_id_seq OWNER TO hmdm;

--
-- Name: userhints_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.userhints_id_seq OWNED BY public.userhints.id;


--
-- Name: userhinttypes; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.userhinttypes (
    hintkey character varying(100) NOT NULL
);


ALTER TABLE public.userhinttypes OWNER TO hmdm;

--
-- Name: userrolepermissions; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.userrolepermissions (
    roleid integer NOT NULL,
    permissionid integer NOT NULL
);


ALTER TABLE public.userrolepermissions OWNER TO hmdm;

--
-- Name: userroles; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.userroles (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text,
    superadmin boolean DEFAULT false NOT NULL
);


ALTER TABLE public.userroles OWNER TO hmdm;

--
-- Name: userroles_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.userroles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.userroles_id_seq OWNER TO hmdm;

--
-- Name: userroles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.userroles_id_seq OWNED BY public.userroles.id;


--
-- Name: userrolesettings; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.userrolesettings (
    id integer NOT NULL,
    roleid integer NOT NULL,
    customerid integer NOT NULL,
    columndisplayeddevicestatus boolean,
    columndisplayeddevicedate boolean,
    columndisplayeddevicenumber boolean,
    columndisplayeddevicemodel boolean,
    columndisplayeddevicepermissionsstatus boolean,
    columndisplayeddeviceappinstallstatus boolean,
    columndisplayeddeviceconfiguration boolean,
    columndisplayeddeviceimei boolean,
    columndisplayeddevicephone boolean,
    columndisplayeddevicedesc boolean,
    columndisplayeddevicegroup boolean,
    columndisplayedlauncherversion boolean,
    columndisplayedbatterylevel boolean,
    columndisplayeddevicefilesstatus boolean,
    columndisplayeddefaultlauncher boolean,
    columndisplayedcustom1 boolean,
    columndisplayedcustom2 boolean,
    columndisplayedcustom3 boolean,
    columndisplayedmdmmode boolean,
    columndisplayedkioskmode boolean,
    columndisplayedandroidversion boolean,
    columndisplayedenrollmentdate boolean,
    columndisplayedserial boolean,
    columndisplayedpublicip boolean
);


ALTER TABLE public.userrolesettings OWNER TO hmdm;

--
-- Name: userrolesettings_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.userrolesettings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.userrolesettings_id_seq OWNER TO hmdm;

--
-- Name: userrolesettings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.userrolesettings_id_seq OWNED BY public.userrolesettings.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: hmdm
--

CREATE TABLE public.users (
    id integer NOT NULL,
    login character varying(30) NOT NULL,
    email character varying(50),
    name character varying(50),
    password character varying(40) NOT NULL,
    customerid bigint,
    userroleid integer,
    alldevicesavailable boolean DEFAULT true NOT NULL,
    allconfigavailable boolean DEFAULT true NOT NULL,
    passwordreset boolean DEFAULT false NOT NULL,
    authtoken character varying(40),
    passwordresettoken character varying(40),
    authdata text,
    twofactorsecret text,
    twofactoraccepted boolean DEFAULT false NOT NULL,
    lastloginfail bigint DEFAULT 0 NOT NULL
);


ALTER TABLE public.users OWNER TO hmdm;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: hmdm
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO hmdm;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hmdm
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: applications id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.applications ALTER COLUMN id SET DEFAULT nextval('public.applications_id_seq'::regclass);


--
-- Name: applicationversions id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.applicationversions ALTER COLUMN id SET DEFAULT nextval('public.applicationversions_id_seq'::regclass);


--
-- Name: configurationapplicationparameters id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationapplicationparameters ALTER COLUMN id SET DEFAULT nextval('public.configurationapplicationparameters_id_seq'::regclass);


--
-- Name: configurationapplications id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationapplications ALTER COLUMN id SET DEFAULT nextval('public.configurationapplications_id_seq'::regclass);


--
-- Name: configurationapplicationsettings id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationapplicationsettings ALTER COLUMN id SET DEFAULT nextval('public.configurationapplicationsettings_id_seq'::regclass);


--
-- Name: configurationfiles id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationfiles ALTER COLUMN id SET DEFAULT nextval('public.configurationfiles_id_seq'::regclass);


--
-- Name: configurations id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurations ALTER COLUMN id SET DEFAULT nextval('public.configurations_id_seq'::regclass);


--
-- Name: customers id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.customers ALTER COLUMN id SET DEFAULT nextval('public.customers_id_seq'::regclass);


--
-- Name: deviceapplicationsettings id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.deviceapplicationsettings ALTER COLUMN id SET DEFAULT nextval('public.deviceapplicationsettings_id_seq'::regclass);


--
-- Name: devicegroups id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.devicegroups ALTER COLUMN id SET DEFAULT nextval('public.devicegroups_id_seq'::regclass);


--
-- Name: devices id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.devices ALTER COLUMN id SET DEFAULT nextval('public.devices_id_seq'::regclass);


--
-- Name: groups id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.groups ALTER COLUMN id SET DEFAULT nextval('public.groups_id_seq'::regclass);


--
-- Name: icons id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.icons ALTER COLUMN id SET DEFAULT nextval('public.icons_id_seq'::regclass);


--
-- Name: pendingpushes id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.pendingpushes ALTER COLUMN id SET DEFAULT nextval('public.pendingpushes_id_seq'::regclass);


--
-- Name: pendingsignup id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.pendingsignup ALTER COLUMN id SET DEFAULT nextval('public.pendingsignup_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- Name: plugin_audit_log id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_audit_log ALTER COLUMN id SET DEFAULT nextval('public.plugin_audit_log_id_seq'::regclass);


--
-- Name: plugin_deviceinfo_deviceparams id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams ALTER COLUMN id SET DEFAULT nextval('public.plugin_deviceinfo_deviceparams_id_seq'::regclass);


--
-- Name: plugin_deviceinfo_deviceparams_device id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_device ALTER COLUMN id SET DEFAULT nextval('public.plugin_deviceinfo_deviceparams_device_id_seq'::regclass);


--
-- Name: plugin_deviceinfo_deviceparams_gps id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_gps ALTER COLUMN id SET DEFAULT nextval('public.plugin_deviceinfo_deviceparams_gps_id_seq'::regclass);


--
-- Name: plugin_deviceinfo_deviceparams_mobile id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_mobile ALTER COLUMN id SET DEFAULT nextval('public.plugin_deviceinfo_deviceparams_mobile_id_seq'::regclass);


--
-- Name: plugin_deviceinfo_deviceparams_mobile2 id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_mobile2 ALTER COLUMN id SET DEFAULT nextval('public.plugin_deviceinfo_deviceparams_mobile2_id_seq'::regclass);


--
-- Name: plugin_deviceinfo_deviceparams_wifi id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_wifi ALTER COLUMN id SET DEFAULT nextval('public.plugin_deviceinfo_deviceparams_wifi_id_seq'::regclass);


--
-- Name: plugin_deviceinfo_settings id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_settings ALTER COLUMN id SET DEFAULT nextval('public.plugin_deviceinfo_settings_id_seq'::regclass);


--
-- Name: plugin_devicelog_log id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_log ALTER COLUMN id SET DEFAULT nextval('public.plugin_devicelog_log_id_seq'::regclass);


--
-- Name: plugin_devicelog_settings id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_settings ALTER COLUMN id SET DEFAULT nextval('public.plugin_devicelog_settings_id_seq'::regclass);


--
-- Name: plugin_devicelog_settings_rules id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_settings_rules ALTER COLUMN id SET DEFAULT nextval('public.plugin_devicelog_settings_rules_id_seq'::regclass);


--
-- Name: plugin_messaging_messages id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_messaging_messages ALTER COLUMN id SET DEFAULT nextval('public.plugin_messaging_messages_id_seq'::regclass);


--
-- Name: plugin_push_messages id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_push_messages ALTER COLUMN id SET DEFAULT nextval('public.plugin_push_messages_id_seq'::regclass);


--
-- Name: plugin_push_schedule id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_push_schedule ALTER COLUMN id SET DEFAULT nextval('public.plugin_push_schedule_id_seq'::regclass);


--
-- Name: plugins id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugins ALTER COLUMN id SET DEFAULT nextval('public.plugins_id_seq'::regclass);


--
-- Name: pushmessages id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.pushmessages ALTER COLUMN id SET DEFAULT nextval('public.pushmessages_id_seq'::regclass);


--
-- Name: settings id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.settings ALTER COLUMN id SET DEFAULT nextval('public.settings_id_seq'::regclass);


--
-- Name: trialkey id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.trialkey ALTER COLUMN id SET DEFAULT nextval('public.trialkey_id_seq'::regclass);


--
-- Name: uploadedfiles id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.uploadedfiles ALTER COLUMN id SET DEFAULT nextval('public.uploadedfiles_id_seq'::regclass);


--
-- Name: usagestats id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.usagestats ALTER COLUMN id SET DEFAULT nextval('public.usagestats_id_seq'::regclass);


--
-- Name: userconfigurationaccess id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userconfigurationaccess ALTER COLUMN id SET DEFAULT nextval('public.userconfigurationaccess_id_seq'::regclass);


--
-- Name: userdevicegroupsaccess id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userdevicegroupsaccess ALTER COLUMN id SET DEFAULT nextval('public.userdevicegroupsaccess_id_seq'::regclass);


--
-- Name: userhints id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userhints ALTER COLUMN id SET DEFAULT nextval('public.userhints_id_seq'::regclass);


--
-- Name: userroles id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userroles ALTER COLUMN id SET DEFAULT nextval('public.userroles_id_seq'::regclass);


--
-- Name: userrolesettings id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userrolesettings ALTER COLUMN id SET DEFAULT nextval('public.userrolesettings_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: applicationfilestocopytemp; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.applicationfilestocopytemp (url, "?column?", newurl) FROM stdin;
\.


--
-- Data for Name: applications; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.applications (id, pkg, name, showicon, customerid, system, latestversion, runafterinstall, type, icontext, iconid, runatboot, usekiosk, intent) FROM stdin;
\.


--
-- Data for Name: applicationversions; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.applicationversions (id, applicationid, version, url, apkhash, split, urlarmeabi, urlarm64, versioncode) FROM stdin;
\.


--
-- Data for Name: applicationversionstemp; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.applicationversionstemp (to_be_deleted, to_be_replaced, id, newapplicationid, newapplicationversionid, newurl, name, pkg, version, url, customerid, ismastercustomer, masterappexists, masterversionexists) FROM stdin;
\.


--
-- Data for Name: configurationapplicationparameters; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.configurationapplicationparameters (id, configurationid, applicationid, skipversioncheck) FROM stdin;
\.


--
-- Data for Name: configurationapplications; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.configurationapplications (id, configurationid, applicationid, remove, showicon, applicationversionid, action, screenorder, keycode, bottom, longtap) FROM stdin;
\.


--
-- Data for Name: configurationapplicationsettings; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.configurationapplicationsettings (id, applicationid, name, type, value, comment, readonly, extrefid, lastupdate) FROM stdin;
\.


--
-- Data for Name: configurationfiles; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.configurationfiles (id, configurationid, description, devicepath, externalurl, filepath, checksum, remove, lastupdate, fileid, replacevariables) FROM stdin;
\.


--
-- Data for Name: configurations; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.configurations (id, name, description, type, password, backgroundcolor, textcolor, backgroundimageurl, iconsize, desktopheader, usedefaultdesignsettings, customerid, gps, bluetooth, wifi, mobiledata, mainappid, eventreceivingcomponent, kioskmode, qrcodekey, contentappid, autoupdate, blockstatusbar, systemupdatetype, systemupdatefrom, systemupdateto, usbstorage, requestupdates, pushoptions, autobrightness, brightness, managetimeout, timeout, lockvolume, wifissid, wifipassword, wifisecuritytype, passwordmode, kioskhome, kioskrecents, kiosknotifications, kiosksysteminfo, kioskkeyguard, orientation, rundefaultlauncher, timezone, allowedclasses, newserverurl, locksafesettings, disablescreenshots, restrictions, defaultfilepath, keepalivetime, managevolume, volume, showwifi, mobileenrollment, desktopheadertemplate, kiosklockbuttons, scheduleappupdate, appupdatefrom, appupdateto, disablelocation, apppermissions, permissive, kioskexit, qrparameters, autostartforeground, displaystatus, encryptdevice, downloadupdates) FROM stdin;
1	По умолчанию	Базовая конфигурация для всех устройств	0	\N	\N	\N	\N	SMALL	NO_HEADER	t	1	\N	\N	\N	\N	\N	\N	f	7fe26928dfdd088d2fc9f5fc52aebe48	\N	f	f	0	\N	\N	\N	DONOTTRACK	mqttWorker	\N	180	f	60	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	/	\N	\N	\N	\N	f	\N	\N	\N	\N	\N	f	GRANTALL	\N	t	\N	\N	f	f	UNLIMITED
\.


--
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.customers (id, name, description, filesdir, master, prefix, registrationtime, lastlogintime, accounttype, expirytime, devicelimit, customerstatus, email, firstname, lastname, language, inactivestate, pausestate, abandonstate, sizelimit, signupstatus, signuptoken) FROM stdin;
1	DEFAULT	Default customer account used for managing the application data in PRIVATE usage scenario		f	e1-	\N	1744388472466	0	\N	3	\N	\N	\N	\N	\N	0	0	0	100	active	\N
\.


--
-- Data for Name: databasechangelog; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.databasechangelog (id, author, filename, dateexecuted, orderexecuted, exectype, md5sum, description, comments, tag, liquibase, contexts, labels, deployment_id) FROM stdin;
18.02.18-20:15	serfeo	db.changelog.xml	2025-04-11 10:14:20.447867	1	EXECUTED	8:0bc81d8e365c3692f780f89f02324ba9	sql	Create user table	\N	3.6.3	common	\N	4384460414
18.02.18-20:20	serfeo	db.changelog.xml	2025-04-11 10:14:20.456752	2	EXECUTED	8:7617e3688402459d3cc7969e2286bf67	sql	Insert default admin user	\N	3.6.3	\N	\N	4384460414
19.02.18-20:00	serfeo	db.changelog.xml	2025-04-11 10:14:20.470654	3	EXECUTED	8:aeba73460b6fcb66600723b40cf117e5	sql	Create configurations table	\N	3.6.3	common	\N	4384460414
19.02.18-20:05	serfeo	db.changelog.xml	2025-04-11 10:14:20.481783	4	EXECUTED	8:e1c2fc3f92238602c607fa2d02f184c0	sql	Create applications table	\N	3.6.3	common	\N	4384460414
19.02.18-20:10	serfeo	db.changelog.xml	2025-04-11 10:14:20.492821	5	EXECUTED	8:8078c7d3b5fdb0e5c7203665c4f6ce11	sql	Create configurations table	\N	3.6.3	common	\N	4384460414
19.02.18-20:15	serfeo	db.changelog.xml	2025-04-11 10:14:20.499649	6	EXECUTED	8:8452b3a72ed86ae6c84a364216889752	sql	Insert default configuration record to configurations table	\N	3.6.3	\N	\N	4384460414
19.02.18-20:20	serfeo	db.changelog.xml	2025-04-11 10:14:20.506793	7	EXECUTED	8:11aaa8eee1e525cbf8cfc4fbf7da0ec3	sql	Create groups table	\N	3.6.3	common	\N	4384460414
19.02.18-20:25	serfeo	db.changelog.xml	2025-04-11 10:14:20.511814	8	EXECUTED	8:063e64e33e733ba5c8bbb4ea09c66c25	sql	Insert default group	\N	3.6.3	common	\N	4384460414
19.02.18-20:30	serfeo	db.changelog.xml	2025-04-11 10:14:20.522957	9	EXECUTED	8:23c8eeb7f30db659b03cc15ad45daed7	sql	Create devices table	\N	3.6.3	common	\N	4384460414
19.02.18-20:35	serfeo	db.changelog.xml	2025-04-11 10:14:20.534334	10	EXECUTED	8:12e3e848326f3650d07bc0de52ac1a08	sql	Create settings table	\N	3.6.3	common	\N	4384460414
26.02.18-18:40	serfeo	db.changelog.xml	2025-04-11 10:14:20.539015	11	EXECUTED	8:4c3de3fe424edf4aad31194ed46583e7	sql	Add password column to configurations table	\N	3.6.3	common	\N	4384460414
16.03.18-18:40	serfeo	db.changelog.xml	2025-04-11 10:14:20.543762	12	EXECUTED	8:10115d29670697df5877da2bd42ae178	sql	Add info column to devices table	\N	3.6.3	common	\N	4384460414
19.11.18-09:30	serfeo	db.changelog.xml	2025-04-11 10:14:20.550741	13	EXECUTED	8:e3a2ddf51ca928873a7843eed84cbbdc	sql	Update column lengths, add icon visibility flag to applications	\N	3.6.3	common	\N	4384460414
19.11.18-10:10	serfeo	db.changelog.xml	2025-04-11 10:14:20.555851	14	EXECUTED	8:74f71d121c07e055d1e6452f5b8dd04e	sql	Update icon visibility flag type	\N	3.6.3	common	\N	4384460414
24.12.18-13:52	isv	db.changelog.xml	2025-04-11 10:14:20.566565	15	EXECUTED	8:f6af332f581f2aa0dba41e23b3c63720	sql	Add settings for device columns displayed	\N	3.6.3	common	\N	4384460414
24.12.18-16:07	isv	db.changelog.xml	2025-04-11 10:14:20.572583	16	EXECUTED	8:ee1732842dd8814e504fac9db06f744f	sql	Add settings for icon size and desktop header	\N	3.6.3	common	\N	4384460414
24.12.18-19:00	isv	db.changelog.xml	2025-04-11 10:14:20.578222	17	EXECUTED	8:b7b82013efe72544c038a1bd85af115f	sql	Add IMEI, phone number attributes to device	\N	3.6.3	common	\N	4384460414
24.12.18-19:18	isv	db.changelog.xml	2025-04-11 10:14:20.583085	18	EXECUTED	8:64a5cab3317cc5da163d3b9d3c64e5fc	sql	Add settings for device IMEI, Phone Number columns displayed	\N	3.6.3	common	\N	4384460414
26.12.18-10:30	isv	db.changelog.xml	2025-04-11 10:14:20.591792	19	EXECUTED	8:49f05ca1741e7adf0a33d5a0ee8dfe75	sql	Add design settings to configurations	\N	3.6.3	common	\N	4384460414
26.12.18-16:00	isv	db.changelog.xml	2025-04-11 10:14:20.596865	20	EXECUTED	8:0f4e102a08cccaf5366de7f731ab5919	sql	Add useDefaultDesignSettings to configurations	\N	3.6.3	common	\N	4384460414
27.12.18-14:20	isv	db.changelog.xml	2025-04-11 10:14:20.602993	21	EXECUTED	8:8378d679231a9d13aabee262f9dd8426	sql	Add settings for Description, Group columns displayed	\N	3.6.3	common	\N	4384460414
16.01.19-14:20	isv	db.changelog.xml	2025-04-11 10:14:20.627114	22	EXECUTED	8:670f4b704b2fc8e10b31fa580f48f78a	sql	Create customers table	\N	3.6.3	common	\N	4384460414
16.01.19-15:20	isv	db.changelog.xml	2025-04-11 10:14:20.636987	23	EXECUTED	8:a158ff804b0607d679b5fa71f90af2b7	sql	Link all tables to customers	\N	3.6.3	common	\N	4384460414
16.01.19-16:11	isv	db.changelog.xml	2025-04-11 10:14:20.643866	24	EXECUTED	8:c45a03e31dbd2ef0149740e495f783e4	sql	Create default customer account for PRIVATE usage scenario and link existing admin account to default\n        customer account	\N	3.6.3	private	\N	4384460414
16.01.19-17:11	isv	db.changelog.xml	2025-04-11 10:14:20.652745	25	EXECUTED	8:612d783c7f55265441f0ee5d6c806e75	sql	Link existing data to default customer account	\N	3.6.3	common	\N	4384460414
16.01.19-17:41	isv	db.changelog.xml	2025-04-11 10:14:20.666782	26	EXECUTED	8:0d7099b93c07e8fdd4594de4a4e07e67	sql	Add FK constraint to link data tables to customers table with cascade deletion	\N	3.6.3	common	\N	4384460414
20.01.19-15:20	isv	db.changelog.xml	2025-04-11 10:14:20.676916	27	EXECUTED	8:faadea314617bf303d455fef1f78f307	sql	Add userrole to users	\N	3.6.3	common	\N	4384460414
22.01.19-12:47	isv	db.changelog.xml	2025-04-11 10:14:20.683366	28	EXECUTED	8:769f695ef6ca0de989650daf6121f803	sql	Making device.number unique	\N	3.6.3	common	\N	4384460414
01.02.19-08:00	isv	db.changelog.xml	2025-04-11 10:14:20.688744	29	EXECUTED	8:54797d78927d15744c294ccc9246147a	sql	Removing default values for devices columns	\N	3.6.3	common	\N	4384460414
01.02.19-11:34	isv	db.changelog.xml	2025-04-11 10:14:20.708811	30	EXECUTED	8:f7a5a110a614af0949a229890d214857	sql	User role and permissions tables	\N	3.6.3	common	\N	4384460414
01.02.19-14:25	isv	db.changelog.xml	2025-04-11 10:14:20.737835	31	EXECUTED	8:3312c9a9e3d6895a6c4773507093d1b7	sql	Initial set of roles and permissions	\N	3.6.3	common	\N	4384460414
04.02.19-10:25	isv	db.changelog.xml	2025-04-11 10:14:20.749197	32	EXECUTED	8:78b3ca98237f1349a28b0d9322181361	sql	Add userRoleId to users	\N	3.6.3	common	\N	4384460414
04.02.19-10:42	isv	db.changelog.xml	2025-04-11 10:14:20.769796	33	EXECUTED	8:5d871bf1ed2d2bb82c17fc420ba1828f	sql	Drop userRole from users	\N	3.6.3	common	\N	4384460414
13.02.19-12:51	isv	db.changelog.xml	2025-04-11 10:14:20.776521	34	EXECUTED	8:106f1c340e425a9f3b4a2de55a01e396	sql	New switch-like properties for configurations	\N	3.6.3	common	\N	4384460414
01.03.19-17:42	isv	db.changelog.xml	2025-04-11 10:14:20.780918	35	EXECUTED	8:14930f9fccd70b5b48095260f21f8c4c	sql	Add remove to configurationapplications	\N	3.6.3	common	\N	4384460414
04.03.19-13:42	isv	db.changelog.xml	2025-04-11 10:14:20.788697	36	EXECUTED	8:7afd19cf338ea61f7664cc161f427e39	sql	Add MDM settings columns to configurations	\N	3.6.3	common	\N	4384460414
04.03.19-15:57	isv	db.changelog.xml	2025-04-11 10:14:20.803883	37	EXECUTED	8:4c2b64f91ceeb49ec5934b2a27105124	sql	Add qrCodeKey columns to configurations	\N	3.6.3	common	\N	4384460414
04.03.19-20:32	isv	db.changelog.xml	2025-04-11 10:14:20.809428	38	EXECUTED	8:2d26bbe8fd5755dc1be57f902d5b1da5	sql	Observer role	\N	3.6.3	common	\N	4384460414
15.03.19-15:15	isv	db.changelog.xml	2025-04-11 10:14:20.817659	39	EXECUTED	8:202cd833ff458b727f7d659ebdf25b08	sql	Add new MDM settings and fix ref constraint for mainappid columns to configurations	\N	3.6.3	common	\N	4384460414
20.03.19-13:49	isv	db.changelog.xml	2025-04-11 10:14:20.82506	40	EXECUTED	8:ec72f221885ca83b528b09d0e769ad0f	sql	Dropping not-null constraint for applications.groupId	\N	3.6.3	common	\N	4384460414
12.04.19-13:23	isv	db.changelog.xml	2025-04-11 10:14:20.835233	41	EXECUTED	8:e23c904f9648120dac18870a495e4772	sql	Create devcieGroups table	\N	3.6.3	common	\N	4384460414
12.04.19-13:37	isv	db.changelog.xml	2025-04-11 10:14:20.842175	42	EXECUTED	8:10497ebd4e7f0ac1c068b2769e6ee569	sql	Move current device group relations from devices to deviceGroups table	\N	3.6.3	common	\N	4384460414
12.04.19-13:41	isv	db.changelog.xml	2025-04-11 10:14:20.847097	43	EXECUTED	8:dacefe5dc4e7029e570c85e13683cb66	sql	Drop groupId column from device	\N	3.6.3	common	\N	4384460414
15.04.19-15:52	isv	db.changelog.xml	2025-04-11 10:14:20.857027	44	EXECUTED	8:ffa22befe4e3d00d89239b0be06b8faa	sql	Create userDeviceGroupsAccess table	\N	3.6.3	common	\N	4384460414
30.05.19-14:24	isv	db.changelog.xml	2025-04-11 10:14:20.863291	45	EXECUTED	8:2f7a8e86f2c767fe977f07a9f5fdb402	sql	Adding language, useDefaultLanguage column to settings table	\N	3.6.3	common	\N	4384460414
05.06.19-10:21	isv	db.changelog.xml	2025-04-11 10:14:20.869047	46	EXECUTED	8:3a04ae353e11bff9767e8c5de1f0e957	sql	Adding system column to applications table	\N	3.6.3	common	\N	4384460414
05.06.19-13:25	isv	db.changelog.xml	2025-04-11 10:14:20.87324	47	EXECUTED	8:4a416f39a68b5edc38ce2a7c9d18466d	sql	Add showIcon to configurationapplications	\N	3.6.3	common	\N	4384460414
10.06.19-09:14	isv	db.changelog.xml	2025-04-11 10:14:20.878046	48	EXECUTED	8:4c7eb989d911c7a53231441d030298ab	sql	Adding autoUpdate column to configurations table	\N	3.6.3	common	\N	4384460414
10.06.19-09:23	isv	db.changelog.xml	2025-04-11 10:14:20.891996	49	EXECUTED	8:856593afa3bd569140fdd6e49fe4ad4a	sql	Create applicationVersions table	\N	3.6.3	common	\N	4384460414
10.06.19-09:33	isv	db.changelog.xml	2025-04-11 10:14:20.920884	50	EXECUTED	8:3f5c32d113c34bb562e74b0a87cf84cc	createProcedure	Create mdm_app_version_comparison_index function	\N	3.6.3	common	\N	4384460414
10.06.19-15:33	isv	db.changelog.xml	2025-04-11 10:14:20.926073	51	EXECUTED	8:196fb013de011dd699358f93cb71bdaf	sql	Link applications to most recent application version	\N	3.6.3	common	\N	4384460414
10.06.19-16:33	isv	db.changelog.xml	2025-04-11 10:14:20.930702	52	EXECUTED	8:9badfeacd1cb1097fdb0b8eed7c19634	sql	Add applicationVersionId to configurationapplications	\N	3.6.3	common	\N	4384460414
11.06.19-10:05	isv	db.changelog.xml	2025-04-11 10:14:20.981965	53	EXECUTED	8:37473782bcb579026b0c0c700aeee612	sql	Migrate application versions data	\N	3.6.3	common	\N	4384460414
18.06.19-11:30	isv	db.changelog.xml	2025-04-11 10:14:20.987964	54	EXECUTED	8:5a0ee83d23d43c1d3478e1141d7e5e4a	sql	Adding blockStatusBar column to configurations table	\N	3.6.3	common	\N	4384460414
18.06.19-12:17	isv	db.changelog.xml	2025-04-11 10:14:20.993485	55	EXECUTED	8:8f8d68b402702f7d7e018486ce95010f	sql	Adding systemUpdateType column to configurations table	\N	3.6.3	common	\N	4384460414
18.06.19-13:11	isv	db.changelog.xml	2025-04-11 10:14:20.999251	56	EXECUTED	8:203a7e9e77685b2c65495e4322bd84ec	sql	Adding systemUpdateFrom, systemUpdateTo columns to configurations table	\N	3.6.3	common	\N	4384460414
04.07.19-18:50	isv	db.changelog.xml	2025-04-11 10:14:21.00561	57	EXECUTED	8:309a6584f3573c73a731ad463283814d	sql	Update showIcon in configurationapplications to NOT NULL	\N	3.6.3	common	\N	4384460414
09.07.19-09:50	isv	db.changelog.xml	2025-04-11 10:14:21.015059	58	EXECUTED	8:02988f1a3e19a213bd0f7105bf2e5d84	sql	Adding action column to configurationApplications	\N	3.6.3	common	\N	4384460414
15.07.19-11:57	isv	db.changelog.xml	2025-04-11 10:14:21.021842	59	EXECUTED	8:5a076e0afa0445fed77933c905a04a7e	sql	Adding runAfterInstall column to configurationApplications	\N	3.6.3	common	\N	4384460414
15.07.19-11:59	isv	db.changelog.xml	2025-04-11 10:14:21.026698	60	EXECUTED	8:431a6a0d5ac9dd2e75df724562ba7b45	sql	Cleanup configurationApplications for action = 3	\N	3.6.3	common	\N	4384460414
17.07.19-10:30	isv	db.changelog.xml	2025-04-11 10:14:21.051108	61	EXECUTED	8:fea205a1fee1d6ecc8772ee3389a18ee	sql	Create tables for application settings	\N	3.6.3	common	\N	4384460414
29.07.19-10:12	isv	db.changelog.xml	2025-04-11 10:14:21.05616	62	EXECUTED	8:ba0fe91ab0cc10ea2f6febd1f1ca6b80	sql	Add settings for Launcher Version columns displayed	\N	3.6.3	common	\N	4384460414
05.08.19-11:26	isv	db.changelog.xml	2025-04-11 10:14:21.068821	63	EXECUTED	8:d1636a46169d773a8a9249fbe3afdfe8	sql	Create configurationApplicationParameters table	\N	3.6.3	common	\N	4384460414
05.08.19-13:18	isv	db.changelog.xml	2025-04-11 10:14:21.076306	64	EXECUTED	8:22f3d0aaca1acee512b80ce29b5bfe61	createProcedure	Create mdm_config_app_upgrade function	\N	3.6.3	common	\N	4384460414
06.09.19-12:27	isv	db.changelog.xml	2025-04-11 10:14:21.083253	65	EXECUTED	8:f0864962874c992c4bb440e01c9fd526	sql	Constraint,new: settings_customer_unique	\N	3.6.3	common	\N	4384460414
19.09.19-12:48	isv	db.changelog.xml	2025-04-11 10:14:21.098517	66	EXECUTED	8:a8df3fa1ed254ea8f68bb8eb4adc1bb2	sql	Table,new: userHints	\N	3.6.3	common	\N	4384460414
19.09.19-18:48	isv	db.changelog.xml	2025-04-11 10:14:21.115842	67	EXECUTED	8:6311e43b1e98e20056841bdf3737df12	sql	Table,new: userHintTypes	\N	3.6.3	common	\N	4384460414
20.09.19-12:24	isv	db.changelog.xml	2025-04-11 10:14:21.127773	68	EXECUTED	8:2f8f615786d522125174e4446b917625	sql	Column,new: customers#prefix	\N	3.6.3	common	\N	4384460414
20.09.19-16:48	isv	db.changelog.xml	2025-04-11 10:14:21.132842	69	EXECUTED	8:c313b6242c24cd0c539a8ca30fffc228	sql	Column,new: customers#registrationTime	\N	3.6.3	common	\N	4384460414
20.09.19-16:49	isv	db.changelog.xml	2025-04-11 10:14:21.137863	70	EXECUTED	8:03ab76f11fe626390d3c131a63de413c	sql	Column,new: customers#lastLoginTime	\N	3.6.3	common	\N	4384460414
24.09.19-14:14	isv	db.changelog.xml	2025-04-11 10:14:21.150771	71	EXECUTED	8:0b77024259af59123c18f7967373928e	sql	Indexes,new: configurations#mainAppId, contentAppId, customerId	\N	3.6.3	common	\N	4384460414
24.09.19-14:15	isv	db.changelog.xml	2025-04-11 10:14:21.161077	72	EXECUTED	8:8dcf8559d95ec7faaef6e339569077b3	sql	Indexes,new: devices#configurationId, groupId, customerId	\N	3.6.3	common	\N	4384460414
24.09.19-14:16	isv	db.changelog.xml	2025-04-11 10:14:21.173801	73	EXECUTED	8:1354e7435304523d578570d3686a3fd1	sql	Indexes,new: applications#pkg, customerId	\N	3.6.3	common	\N	4384460414
24.09.19-14:17	isv	db.changelog.xml	2025-04-11 10:14:21.180877	74	EXECUTED	8:3245ffbd28de69251c02365315948aa0	sql	Indexes,new: applicationVersions#applicationId	\N	3.6.3	common	\N	4384460414
24.09.19-14:18	isv	db.changelog.xml	2025-04-11 10:14:21.19092	75	EXECUTED	8:ba4bec71a27538bb39201bcd68e82d78	sql	Indexes,new: deviceGroups#deviceId, groupId	\N	3.6.3	common	\N	4384460414
03.10.19-14:38	isv	db.changelog.xml	2025-04-11 10:14:21.196112	76	EXECUTED	8:ad9d40f26c9110fada679398aecf309f	sql	Column,new: applicationVersions#apkHash	\N	3.6.3	common	\N	4384460414
04.10.19-10:14	isv	db.changelog.xml	2025-04-11 10:14:21.20189	77	EXECUTED	8:0da42be8c84a8ad7a4b5fb48a8796cf1	sql	Permission,new: edit_device_desc	\N	3.6.3	common	\N	4384460414
04.10.19-12:00	isv	db.changelog.xml	2025-04-11 10:14:21.214946	78	EXECUTED	8:f5c3cf0139d69ad9f1c7936054ba9a85	sql	Table,new: userRoleSettings	\N	3.6.3	common	\N	4384460414
04.10.19-13:50	isv	db.changelog.xml	2025-04-11 10:14:21.222799	79	EXECUTED	8:e33fa532df5f5b33aedd86579d041d94	sql	Data,initial: userRoleSettings	\N	3.6.3	common	\N	4384460414
04.10.19-14:30	isv	db.changelog.xml	2025-04-11 10:14:21.24567	80	EXECUTED	8:c6f8867f67abcbf167a4cc5860a0e9d7	sql	Column,delete: settings#columnDisplayed*	\N	3.6.3	common	\N	4384460414
18.10.2019-17:21	isv	db.changelog.xml	2025-04-11 10:14:21.251304	81	EXECUTED	8:fa1ce410f6732882b8e1e841ae862a2f	sql	Permission,new: edit_device_app_settings	\N	3.6.3	common	\N	4384460414
22.10.19-12:34	isv	db.changelog.xml	2025-04-11 10:14:21.255995	82	EXECUTED	8:d59729c706b0cfdea759c615136bbf30	sql	Column,new: userRoleSettings#columnDisplayedBatteryLevel	\N	3.6.3	common	\N	4384460414
06.11.19-18:10	isv	db.changelog.xml	2025-04-11 10:14:21.260671	83	EXECUTED	8:f6d3e642f0aa09063c37c9ec40de4cc7	sql	Column,new: configurations#usbStorage	\N	3.6.3	common	\N	4384460414
07.11.19-10:43	isv	db.changelog.xml	2025-04-11 10:14:21.265832	84	EXECUTED	8:019712280eef6b17a8effd9f2925ee7f	sql	Column,new: configurations#requestUpdates	\N	3.6.3	common	\N	4384460414
15.11.19-11:31	isv	db.changelog.xml	2025-04-11 10:14:21.27051	85	EXECUTED	8:d3f2afb60e17022fb7dc38ac63a42b6c	sql	Data,update: configurations#autoUpdate: reset for all to FALSE	\N	3.6.3	common	\N	4384460414
18.11.19-11:40	isv	db.changelog.xml	2025-04-11 10:14:21.283743	86	EXECUTED	8:cc177e292b31c0e98e271e70eff4c4c1	sql	Table,new: uploadedFiles	\N	3.6.3	common	\N	4384460414
18.11.19-11:46	isv	db.changelog.xml	2025-04-11 10:14:21.296288	87	EXECUTED	8:760f4c2d73b820f2168edc58afa4e935	sql	Table,new: icons	\N	3.6.3	common	\N	4384460414
18.11.19-11:55	isv	db.changelog.xml	2025-04-11 10:14:21.304044	88	EXECUTED	8:e34968731e1c4d1c73938cb1a22b9ab2	sql	Columns,new: applications#type,iconText,iconId	\N	3.6.3	common	\N	4384460414
09.01.20-11:10	seva	db.changelog.xml	2025-04-11 10:14:21.309131	89	EXECUTED	8:708b60539a2e05308615f92198ef10b2	sql	Column,new: configurations#pushOptions	\N	3.6.3	common	\N	4384460414
06.11.19-18:10	seva	db.changelog.xml	2025-04-11 10:14:21.319539	90	EXECUTED	8:05ce945ca25b4e3c3d3b3bbb3180e2bc	sql	Column,new: configurations#manageBrightness, #brightness, #manageTimeout, #timeout, #lockVolume	\N	3.6.3	common	\N	4384460414
25.02.20-14:56	seva	db.changelog.xml	2025-04-11 10:14:21.325075	91	EXECUTED	8:c1a1b46d8dc894c96591e15d9ae81423	sql	Add MDM wifi settings columns to configurations	\N	3.6.3	common	\N	4384460414
25.02.20-16:26	seva	db.changelog.xml	2025-04-11 10:14:21.329585	92	EXECUTED	8:eaf90e1247a8ea81c420c7c990631bc5	sql	Add MDM wifi security type columns to configurations	\N	3.6.3	common	\N	4384460414
29.02.20-15:24	isv	db.changelog.xml	2025-04-11 10:14:21.343034	93	EXECUTED	8:0649486b2cb6262eda438278e9cb4621	sql	Table, new: configurationFiles	\N	3.6.3	common	\N	4384460414
03.03.20-22:59	isv	db.changelog.xml	2025-04-11 10:14:21.347637	94	EXECUTED	8:d80cae8cc67f381285f8f3b3c76760f0	sql	Dropping not-null constraint for configurationFiles.description	\N	3.6.3	common	\N	4384460414
03.03.20-23:00	isv	db.changelog.xml	2025-04-11 10:14:21.354473	95	EXECUTED	8:9ab82a4c920f5b5274532044c27bab3c	sql	Column,delete: configurationFiles#name	\N	3.6.3	common	\N	4384460414
04.03.20-18:18	isv	db.changelog.xml	2025-04-11 10:14:21.358695	96	EXECUTED	8:5a106c405fbdb82d29b4e04bb5d07e9f	sql	Dropping not-null constraint for configurationFiles.checksum	\N	3.6.3	common	\N	4384460414
15.03.20-04:40	isv	db.changelog.xml	2025-04-11 10:14:21.36391	97	EXECUTED	8:abe77aa54260931a73d3cad16c200fd2	createProcedure	Function,new: mdm_device_permissions_index function	\N	3.6.3	common	\N	4384460414
15.03.20-15:42	isv	db.changelog.xml	2025-04-11 10:14:21.368974	98	EXECUTED	8:10aafe43d56caeef6d126520936274b9	createProcedure	Function,new: mdm_resolve_device_property function	\N	3.6.3	common	\N	4384460414
15.03.20-16:06	isv	db.changelog.xml	2025-04-11 10:14:21.374477	99	EXECUTED	8:0c5b34a1699cf303446b31f83de74419	createProcedure	Function,new: mdm_device_launcher_version function	\N	3.6.3	common	\N	4384460414
29.02.20-17:37	isv	db.changelog.xml	2025-04-11 10:14:21.381751	100	EXECUTED	8:b6fc11926128f95d49b1f9be837a6065	sql	Table, new: deviceStatuses	\N	3.6.3	common	\N	4384460414
21.03.20-17:10	seva	db.changelog.xml	2025-04-11 10:14:21.386217	101	EXECUTED	8:66153a349562eacd5545d013bcf06f07	sql	Column,new: configurations#passwordMode	\N	3.6.3	common	\N	4384460414
23.03.20-19:10	seva	db.changelog.xml	2025-04-11 10:14:21.392508	102	EXECUTED	8:08bbcbece24c5f7ef9fa9db7e173e909	sql	Column,new: settings#createNewDevices, #newDeviceGroupId, #newDeviceConfigurationId	\N	3.6.3	common	\N	4384460414
31.03.20-09:50	seva	db.changelog.xml	2025-04-11 10:14:21.401042	103	EXECUTED	8:3509eaa9b99fab1e66eb41ae4ed81e24	sql	Table,new: trialkey	\N	3.6.3	common	\N	4384460414
14.04.20-17:45	seva	db.changelog.xml	2025-04-11 10:14:21.405893	104	EXECUTED	8:2ecc45d2b23732ed8c4e2538878f2f57	sql	Column,new: settings#phoneNumberFormat	\N	3.6.3	common	\N	4384460414
19.04.20-16:56	seva	db.changelog.xml	2025-04-11 10:14:21.410941	105	EXECUTED	8:699e43d4b551d618631f40bc9bd0c479	sql	Add settings for device file status column displayed	\N	3.6.3	common	\N	4384460414
28.04.20-17:25	seva	db.changelog.xml	2025-04-11 10:14:21.415406	106	EXECUTED	8:7082505a7fa677b694b9d89717bac661	sql	Adding runAtBoot column to configurationApplications	\N	3.6.3	common	\N	4384460414
04.07.20-10:50	seva	db.changelog.xml	2025-04-11 10:14:21.419201	107	EXECUTED	8:a3c418c7a09b4bced90e2264f7f4569d	sql	Adding imeiUpdateTs column to devices table	\N	3.6.3	common	\N	4384460414
04.07.20-13:20	seva	db.changelog.xml	2025-04-11 10:14:21.427799	108	EXECUTED	8:f4c6153b663d6182b3fba6e9800e23e2	sql	Adding kiosk mode options columns to configurations table	\N	3.6.3	common	\N	4384460414
04.07.20-14:10	seva	db.changelog.xml	2025-04-11 10:14:21.431987	109	EXECUTED	8:ca7d72baae60e7810a8fd22aa7e294f8	sql	Adding orientation column to configurations table	\N	3.6.3	common	\N	4384460414
04.07.20-15:20	seva	db.changelog.xml	2025-04-11 10:14:21.436913	110	EXECUTED	8:5272e3d41ee67f711b23290d06fdcdae	sql	Adding order column to configurationapplications table	\N	3.6.3	common	\N	4384460414
13.07.20-16:21	seva	db.changelog.xml	2025-04-11 10:14:21.442627	111	EXECUTED	8:b181f0a345113b7b712edf4648040149	sql	Adding runDefaultLauncher column to configurations table	\N	3.6.3	common	\N	4384460414
1707.20-18:44	seva	db.changelog.xml	2025-04-11 10:14:21.449183	112	EXECUTED	8:e97b4f8ef70cdeba589a5acd3fb34e25	sql	Column,new: userRoleSettings#columnDisplayedDefaultLauncher	\N	3.6.3	common	\N	4384460414
29.07.20-18:37	seva	db.changelog.xml	2025-04-11 10:14:21.457902	113	EXECUTED	8:a88e58191e136cbc574305df0e0c9fd9	sql	Adding timeZone and allowedClasses column to configurations table	\N	3.6.3	common	\N	4384460414
17.08.20-14:35	seva	db.changelog.xml	2025-04-11 10:14:21.462293	114	EXECUTED	8:71faee4c63d8c29285c010676c9204dd	sql	Adding newServerUrl column to configurations table	\N	3.6.3	common	\N	4384460414
30.08.20-11:40	seva	db.changelog.xml	2025-04-11 10:14:21.467205	115	EXECUTED	8:3806304780c472e102a6de2f40dcab79	sql	Adding keycode column to configurationapplications table	\N	3.6.3	common	\N	4384460414
01.09.20-23:28	seva	db.changelog.xml	2025-04-11 10:14:21.471853	116	EXECUTED	8:19738e8fc31e911f14aeda732ba64e5f	sql	Adding lockSafeSettings column to configurations table	\N	3.6.3	common	\N	4384460414
18.09.20-16:59	seva	db.changelog.xml	2025-04-11 10:14:21.487269	117	EXECUTED	8:5b9a127a19d7717519692465ac7eda8b	sql	Column,new: settings#customPropertyName	\N	3.6.3	common	\N	4384460414
28.09.19-14:41	seva	db.changelog.xml	2025-04-11 10:14:21.497427	118	EXECUTED	8:ae7efd3d3719eb53bf071cbf1df3005f	sql	Column,new: customers#accountType	\N	3.6.3	common	\N	4384460414
15.10.20-11:06	seva	db.changelog.xml	2025-04-11 10:14:21.502852	119	EXECUTED	8:faf687ead0b8e3240aa6b570534786ac	sql	Adding disableScreenshots column to configurations table	\N	3.6.3	common	\N	4384460414
20.10.20-16:41	seva	db.changelog.xml	2025-04-11 10:14:21.508201	120	EXECUTED	8:bd23a23bf3b00bb1b44e2bce8838b549	sql	Column,new: customers#customerStatus	\N	3.6.3	common	\N	4384460414
03.12.20-20:22	seva	db.changelog.xml	2025-04-11 10:14:21.513348	121	EXECUTED	8:ede4d04b9756ce14612711aecf8e5a1e	sql	Column,new: applications#useKiosk	\N	3.6.3	common	\N	4384460414
20.01.21-13:18	seva	db.changelog.xml	2025-04-11 10:14:21.519295	122	EXECUTED	8:cea8f93c8703ca8949256cf4bde6cc24	sql	Column,new: devices#oldNumber, configurations#restrictions	\N	3.6.3	common	\N	4384460414
19.02.21-14:25	seva	db.changelog.xml	2025-04-11 10:14:21.524032	123	EXECUTED	8:0101d6da3fa07c7f2ebcb45aae89c501	sql	Adding bottom column to configurationapplications	\N	3.6.3	common	\N	4384460414
07.04.21-11:44	seva	db.changelog.xml	2025-04-11 10:14:21.528367	124	EXECUTED	8:e285e3289ba93bbd49771c6e2179d768	sql	Add defaultFilePath to configurations	\N	3.6.3	common	\N	4384460414
12.04.21-11:43	seva	db.changelog.xml	2025-04-11 10:14:21.572781	125	EXECUTED	8:0cad2af6c9222603a846d2d1cd929028	sql	Create userConfigurationAccess table	\N	3.6.3	common	\N	4384460414
21.04.21-17:48	seva	db.changelog.xml	2025-04-11 10:14:21.585156	126	EXECUTED	8:ae442b89b088967c26cfb3462f5622a5	sql	Column,new: configurations#keepaliveTime	\N	3.6.3	common	\N	4384460414
02.05.21-09:27	seva	db.changelog.xml	2025-04-11 10:14:21.597428	127	EXECUTED	8:a3d352b63fe5063cc6a759caaf5baeb3	sql	Column,new: settings#customMultiline	\N	3.6.3	common	\N	4384460414
08.05.21-11:35	seva	db.changelog.xml	2025-04-11 10:14:21.601719	128	EXECUTED	8:c10f01ffe60ec84dc420f3920698fe35	sql	Column,new: configurations#manageVolume, #volume	\N	3.6.3	common	\N	4384460414
31.05.21-19:02	seva	db.changelog.xml	2025-04-11 10:14:21.606874	129	EXECUTED	8:4dfdc84f430e550a6670d647404cd583	sql	Column,new: applicationVersions#split, #urlArmeabi, #urlArm64	\N	3.6.3	common	\N	4384460414
04.06.21-14:05	seva	db.changelog.xml	2025-04-11 10:14:21.610315	130	EXECUTED	8:325bed82d216ed8b60e12a80d7876089	sql	Column,new: configurations#showWifi	\N	3.6.3	common	\N	4384460414
02.08.21-14:31	seva	db.changelog.xml	2025-04-11 10:14:21.613726	131	EXECUTED	8:36fd8838409e9d4ce765ed2a90989bb1	sql	Add mobile entrollment column to configurations	\N	3.6.3	common	\N	4384460414
05.09.21-13:44	seva	db.changelog.xml	2025-04-11 10:14:21.619639	132	EXECUTED	8:1b6bc2e1cf579a6eb3c632ebad009b67	sql	Add permission to send Push via API	\N	3.6.3	common	\N	4384460414
17.11.21-07:32	seva	db.changelog.xml	2025-04-11 10:14:21.627707	133	EXECUTED	8:aa85fb33a3710af838a673096a2bcc5d	sql	Add desktop header template and description to settings and configurations	\N	3.6.3	common	\N	4384460414
29.11.21-10:44	seva	db.changelog.xml	2025-04-11 10:14:21.635477	134	EXECUTED	8:6d1c5cf10732e3d027a4712c2b69cb3b	sql	Column,new: settings#passwordStrength	\N	3.6.3	common	\N	4384460414
05.12.21-18:57	seva	db.changelog.xml	2025-04-11 10:14:21.639674	135	EXECUTED	8:a8c94d8cc79fdae357a99cecfc598859	sql	Column,new: users#token	\N	3.6.3	common	\N	4384460414
14.01.2-16:24	seva	db.changelog.xml	2025-04-11 10:14:21.64874	136	EXECUTED	8:bae75784b7fd0b19fc61a61065b31768	sql	Column,new: devices#fastSearch Indexes,new: devices#number, fastSearch	\N	3.6.3	common	\N	4384460414
25.06.22-16:36	seva	db.changelog.xml	2025-04-11 10:14:21.656619	137	EXECUTED	8:7ec3a1f34577f497a7ec8c3d7c987820	sql	Column,new: userRoleSettings#columnDisplayedMdmMode,columnDisplayedKioskMode,columnDisplayedAndroidVersion,columnDisplayedEnrollmentDate,columnDisplayedSerial,device#enrollTime	\N	3.6.3	common	\N	4384460414
19.07.22-09:06	seva	db.changelog.xml	2025-04-11 10:14:21.660396	138	EXECUTED	8:722b88fcd9f99698c208cb2bf8e09e05	sql	Column,new: applicationVersions#versionCode	\N	3.6.3	common	\N	4384460414
23.08.22-15:57	seva	db.changelog.xml	2025-04-11 10:14:21.664704	139	EXECUTED	8:8502066ac77a084df322eec81af814c6	sql	Column,new: configurations#disableLocation, #appPermissions	\N	3.6.3	common	\N	4384460414
24.12.22-11:43	seva	db.changelog.xml	2025-04-11 10:14:21.669283	140	EXECUTED	8:135591506b4aeb45f265607bc1aaa3ab	sql	Column,new: configurations#permissive, #kioskExit	\N	3.6.3	common	\N	4384460414
22.01.23-15:40	seva	db.changelog.xml	2025-04-11 10:14:21.674167	141	EXECUTED	8:91285a13f57653119ddec510dc6e0977	sql	Column,new: devices#infojson	\N	3.6.3	common	\N	4384460414
23.01.23-09:31	seva	db.changelog.xml	2025-04-11 10:14:21.6788	142	EXECUTED	8:9e0c988238771b0ea5db68a8f9c86ae0	sql	Column,new: devices#publicIp	\N	3.6.3	common	\N	4384460414
05.03.23-13:33	seva	db.changelog.xml	2025-04-11 10:14:21.683717	143	EXECUTED	8:79fe1809e5a8630e4becc4b02fedf699	sql	Permission,new: get_updates	\N	3.6.3	common	\N	4384460414
07.03.23-11:23	seva	db.changelog.xml	2025-04-11 10:14:21.695091	144	EXECUTED	8:3ce87c22fbe41c9a7df444030528bf95	sql	Table,new: usageStats	\N	3.6.3	common	\N	4384460414
22.03.23-12:56	seva	db.changelog.xml	2025-04-11 10:14:21.705155	145	EXECUTED	8:49fc90fd2d2d83d675f8aa1dba44ba0f	sql	Column,new: customers#firstName, lastName, language, inactiveState, pauseState, abandonState	\N	3.6.3	common	\N	4384460414
27.03.23-10:55	seva	db.changelog.xml	2025-04-11 10:14:21.711244	146	EXECUTED	8:ca780f4a6fb25b0333c317cfd342aea1	sql	Column,new: customers#sizeLimit	\N	3.6.3	common	\N	4384460414
15.04.23-17:20	seva	db.changelog.xml	2025-04-11 10:14:21.716092	147	EXECUTED	8:885170541eccde1a0a21993dab504c98	sql	Column,new: configurationApplications#longTap, configurations#qrParameters, configurations#autostartForeground	\N	3.6.3	common	\N	4384460414
22.04.23-10:55	seva	db.changelog.xml	2025-04-11 10:14:21.723604	148	EXECUTED	8:36290690ddef861327a9513f9796ff43	sql	Table,new: pendingSignup	\N	3.6.3	common	\N	4384460414
01.05.23-16:58	seva	db.changelog.xml	2025-04-11 10:14:21.733814	149	EXECUTED	8:880b653b6f2a761dc12db10be250598a	sql	Column,new: users#authData	\N	3.6.3	common	\N	4384460414
25.06.23-10:33	seva	db.changelog.xml	2025-04-11 10:14:21.755972	150	EXECUTED	8:c5b3fa2a657bda327807a9e6cc7ea7a8	sql	More granular permissions for limited users	\N	3.6.3	common	\N	4384460414
10.09.23-10:57	seva	db.changelog.xml	2025-04-11 10:14:21.761843	151	EXECUTED	8:bfd22638f08b1332e0a9deb9e5d65fb7	sql	Two-factor authentication: Column,new: customers#twoFactor, users#twoFactorSecret	\N	3.6.3	common	\N	4384460414
17.10.23-10:02	seva	db.changelog.xml	2025-04-11 10:14:21.766012	152	EXECUTED	8:da6777133f548cdc28cd22b6c0c59fe4	sql	Columns,new: applications#intent	\N	3.6.3	common	\N	4384460414
19.11.23-16:19	seva	db.changelog.xml	2025-04-11 10:14:21.769497	153	EXECUTED	8:15d293141a666aa762a413e4a64ad662	sql	Column,new: settings#idleLogout	\N	3.6.3	common	\N	4384460414
25.04.24-15:58	seva	db.changelog.xml	2025-04-11 10:14:21.774103	154	EXECUTED	8:0b0d0283cc2eda5ba379465a92260f00	sql	Column,new: users#lastLoginFail, configurations#displayStatus	\N	3.6.3	common	\N	4384460414
21.09.24-14:21	seva	db.changelog.xml	2025-04-11 10:14:21.778394	155	EXECUTED	8:b00e495ea5d5f5498e6869b2b3b70b82	sql	Add MDM device encryption column to configurations	\N	3.6.3	common	\N	4384460414
25.09.24-11:49	seva	db.changelog.xml	2025-04-11 10:14:21.782032	156	EXECUTED	8:63e169ac9ac90f542316c38c9be56248	sql	Column,new: configurations#downloadUpdates	\N	3.6.3	common	\N	4384460414
notification-07.06.2019-11:13	isv	notification.changelog.xml	2025-04-11 10:14:21.929959	157	EXECUTED	8:8cbadde4bc297953a70b665948922b58	sql	Create pushMessages table	\N	3.6.3	common	\N	4384461917
notification-07.06.2019-11:45	isv	notification.changelog.xml	2025-04-11 10:14:21.941372	158	EXECUTED	8:51f79de3cf4cb6e0e7c39628007da6d5	sql	Create pendingPushes table	\N	3.6.3	common	\N	4384461917
plugin-platform-07.02.2019-14:16	isv	db.changelog.xml	2025-04-11 10:14:22.012195	159	EXECUTED	8:7d8bd9596bb9e97224112c736d68c3c7	sql	Create plugins table	\N	3.6.3	common	\N	4384461999
plugin-platform-30.05.2019-12:09	isv	db.changelog.xml	2025-04-11 10:14:22.017642	160	EXECUTED	8:2718138941250625c84cf6b027d98984	sql	Add nameLocalizationKey to plugins	\N	3.6.3	common	\N	4384461999
plugin-platform-15.07.2019-01:48	isv	db.changelog.xml	2025-04-11 10:14:22.023794	161	EXECUTED	8:37a81c80230483adcaab91a28106f1ec	sql	Add settingsPermission, functionsPermission, deviceFunctionsPermission to plugins	\N	3.6.3	common	\N	4384461999
plugin-platform-11.09.2019-18:36	isv	db.changelog.xml	2025-04-11 10:14:22.028014	162	EXECUTED	8:63713b73183bfbff1e8ad11fe2e6e916	sql	Column,new: plugins.enabledForDevice	\N	3.6.3	common	\N	4384461999
plugin-platform-29.10.2019-17:55	isv	db.changelog.xml	2025-04-11 10:14:22.03308	163	EXECUTED	8:413f2867f08080aa11406970fead8bbc	sql	Permission,new: plugins_customer_access_management	\N	3.6.3	common	\N	4384461999
plugin-platform-16.06.2020-16:08	seva	db.changelog.xml	2025-04-11 10:14:22.037454	164	EXECUTED	8:66a0f0aa054adf9842b9ebbfb89daf43	sql	Update name column type	\N	3.6.3	common	\N	4384461999
plugin-platform-05.05.21-11:48	seva	db.changelog.xml	2025-04-11 10:14:22.042991	165	EXECUTED	8:63fedb2df95d22428d16635ac19fbf1e	sql	Drop legacy licensing data	\N	3.6.3	common	\N	4384461999
plugin-audit-04.10.2019-16:38	isv	audit.changelog.xml	2025-04-11 10:14:22.103074	166	EXECUTED	8:442d1ca4547c484c76d1aff23e3d5d70	sql	Register audit plugin	\N	3.6.3	common	\N	4384462097
plugin-audit-04.10.2019-16:40	isv	audit.changelog.xml	2025-04-11 10:14:22.111165	167	EXECUTED	8:6c28eab71ee6b783584ba54c79578f6e	sql	Permissions for audit plugin access	\N	3.6.3	common	\N	4384462097
plugin-audit-04.10.2019-16:42	isv	audit.changelog.xml	2025-04-11 10:14:22.122677	168	EXECUTED	8:60bcd63dab63aa5550d1153f203a336f	sql	Table,new: plugin_audit_log	\N	3.6.3	common	\N	4384462097
plugin-audit-23.02.2020-16:42	seva	audit.changelog.xml	2025-04-11 10:14:22.127625	169	EXECUTED	8:3fe8a99bf3507b1d44f3a8ca88f250b4	sql	Column,new: errorCode	\N	3.6.3	common	\N	4384462097
plugin-audit-22.05.2020-12:47	seva	audit.changelog.xml	2025-04-11 10:14:22.135561	170	EXECUTED	8:bdbe28dcbeee7da6b6cfa83cb41d3d90	sql	Fix user role permissions assuming admin and super-admin have fixed ids	\N	3.6.3	common	\N	4384462097
plugin-deviceinfo-22.10.2019-13:34	isv	deviceinfo.changelog.xml	2025-04-11 10:14:22.197885	171	EXECUTED	8:c669eedc6acd20e78f4afa0d1410ddcf	sql	Plugin,new: deviceinfo	\N	3.6.3	common	\N	4384462193
plugin-deviceinfo-22.10.2019-13:36	isv	deviceinfo.changelog.xml	2025-04-11 10:14:22.205977	172	EXECUTED	8:09be67d6ee00774484fff372f3a1a2a7	sql	Permission,new: plugin_deviceinfo_access	\N	3.6.3	common	\N	4384462193
plugin-deviceinfo-22.10.2019-13:38	isv	deviceinfo.changelog.xml	2025-04-11 10:14:22.21842	173	EXECUTED	8:6c8d1dbccfa9c21fb5f34d80708c41bc	sql	Table,new: plugin_deviceinfo_settings	\N	3.6.3	common	\N	4384462193
plugin-deviceinfo-22.10.2019-15:28	isv	deviceinfo.changelog.xml	2025-04-11 10:14:22.227303	174	EXECUTED	8:3ebce08f26d424050ba49f741ab79e3a	sql	Table,new: plugin_deviceinfo_deviceParams	\N	3.6.3	common	\N	4384462193
plugin-deviceinfo-22.10.2019-15:31	isv	deviceinfo.changelog.xml	2025-04-11 10:14:22.241468	175	EXECUTED	8:76d10eae565213626c5db4d3e74632d1	sql	Table,new: plugin_deviceinfo_deviceParams_device	\N	3.6.3	common	\N	4384462193
plugin-deviceinfo-22.10.2019-16:02	isv	deviceinfo.changelog.xml	2025-04-11 10:14:22.257586	176	EXECUTED	8:749d6ebe8b2748334c99334af4371534	sql	Table,new: plugin_deviceinfo_deviceParams_wifi	\N	3.6.3	common	\N	4384462193
plugin-deviceinfo-22.10.2019-16:29	isv	deviceinfo.changelog.xml	2025-04-11 10:14:22.269684	177	EXECUTED	8:8cf960deac394e5b29229d892bc7929f	sql	Table,new: plugin_deviceinfo_deviceParams_gps	\N	3.6.3	common	\N	4384462193
plugin-deviceinfo-22.10.2019-16:48	isv	deviceinfo.changelog.xml	2025-04-11 10:14:22.281146	178	EXECUTED	8:a544a20082d13e1e992ad83fe8434e7e	sql	Table,new: plugin_deviceinfo_deviceParams_mobile	\N	3.6.3	common	\N	4384462193
plugin-deviceinfo-22.10.2019-16:49	isv	deviceinfo.changelog.xml	2025-04-11 10:14:22.295151	179	EXECUTED	8:ca20385273858e28fa7ec33dd1c7ecaa	sql	Table,new: plugin_deviceinfo_deviceParams_mobile2	\N	3.6.3	common	\N	4384462193
plugin-deviceinfo-29.10.2019-14:03	isv	deviceinfo.changelog.xml	2025-04-11 10:14:22.300342	180	EXECUTED	8:e711195832c54179b4d1518bebdddc57	sql	Columns,new: plugin_deviceinfo_settings#sendData,intervalMins	\N	3.6.3	common	\N	4384462193
plugin-deviceinfo-26.01.2021-13:23	seva	deviceinfo.changelog.xml	2025-04-11 10:14:22.307215	181	EXECUTED	8:1de02d3197b9b6300a5bd7aa56e21ce2	sql	Columns,new: plugin_deviceinfo_deviceparams_device#usbStorage,memoryTotal,memoryAvailable	\N	3.6.3	common	\N	4384462193
plugin-devicelog-10.07.2019-14:45	isv	db.changelog.xml	2025-04-11 10:14:22.377778	182	EXECUTED	8:794673c30dfba1dc70df09c4823d27cd	sql	Register devicelog plugin	\N	3.6.3	common	\N	4384462372
plugin-devicelog-10.07.2019-15:01	isv	db.changelog.xml	2025-04-11 10:14:22.386192	183	EXECUTED	8:ff440606c26b760a842f5292986a3b6e	sql	Permissions for devicelog plugin access	\N	3.6.3	common	\N	4384462372
plugin-devicelog-11.09.19-18:38	isv	db.changelog.xml	2025-04-11 10:14:22.391806	184	EXECUTED	8:00813f6512bf16ba5240bf8269419df4	sql	Set: plugins.enabledForDevice	\N	3.6.3	common	\N	4384462372
plugin-devicelog-22.05.2020-12:47	seva	db.changelog.xml	2025-04-11 10:14:22.399619	185	EXECUTED	8:da8146058de1b7a448ad51014fa7fdc3	sql	Fix user role permissions assuming admin and super-admin have fixed ids	\N	3.6.3	common	\N	4384462372
plugin-devicelog-10.07.2019-17:34	isv	db.changelog.xml	2025-04-11 10:14:22.457606	186	EXECUTED	8:4d088c94af4f9fb7b4240f202e1173bf	sql	Create plugin_devicelog_log	\N	3.6.3	common	\N	4384462448
plugin-devicelog-12.07.2019-12:52	isv	db.changelog.xml	2025-04-11 10:14:22.467009	187	EXECUTED	8:f2c90eb1f6bb30221d65f533cca83397	sql	Create plugin_devicelog_settings	\N	3.6.3	common	\N	4384462448
plugin-devicelog-12.07.2019-12:55	isv	db.changelog.xml	2025-04-11 10:14:22.471877	188	EXECUTED	8:be1fa67a9f3e477f8910910feed4e95f	sql	Insert plugin_devicelog_settings	\N	3.6.3	common	\N	4384462448
plugin-devicelog-12.07.2019-13:32	isv	db.changelog.xml	2025-04-11 10:14:22.483546	189	EXECUTED	8:8e7137910539d80686733d4cf6522209	sql	Create plugin_devicelog_setting_rules	\N	3.6.3	common	\N	4384462448
plugin-devicelog-12.07.2019-13:50	isv	db.changelog.xml	2025-04-11 10:14:22.491562	190	EXECUTED	8:ad1bc2cb97600b3af16b46269a9d816f	sql	Create plugin_devicelog_setting_rule_devices	\N	3.6.3	common	\N	4384462448
plugin-messaging-28.12.2019-10:51	seva	messaging.changelog.xml	2025-04-11 10:14:22.552994	191	EXECUTED	8:1dcb0bc4da3f9ceb3fa66ab224dac9ad	sql	Plugin,new: messaging	\N	3.6.3	common	\N	4384462548
plugin-messaging-28.12.2019-10:52	seva	messaging.changelog.xml	2025-04-11 10:14:22.562985	192	EXECUTED	8:076fcd3afd7f3134985bc8371b0190d7	sql	Permission,new: plugin_messaging_send, plugin_messaging_delete	\N	3.6.3	common	\N	4384462548
plugin-messaging-28.12.2019-10:53	seva	messaging.changelog.xml	2025-04-11 10:14:22.574805	193	EXECUTED	8:647bc02c741d762d061c12d3e9145869	sql	Table,new: plugin_messaging_messages	\N	3.6.3	common	\N	4384462548
plugin-push-14.05.2022-15:11	seva	push.changelog.xml	2025-04-11 10:14:22.644737	194	EXECUTED	8:0aad3ebf3b31134c1bbfd4ead914b97d	sql	Plugin,new: push	\N	3.6.3	common	\N	4384462627
plugin-push-02.05.2024-16:06	seva	push.changelog.xml	2025-04-11 10:14:22.657435	195	EXECUTED	8:c5567b919d1a19d720b0bc1dbdea3783	sql	Table, new: plugin_push_schedule	\N	3.6.3	common	\N	4384462627
plugin-xtra-13.05.2023-16:02	seva	xtra.changelog.xml	2025-04-11 10:14:22.720498	196	EXECUTED	8:1f092297249d02db8e246cb6f5f19cf0	sql	Plugin,new: xtra	\N	3.6.3	common	\N	4384462717
plugin-xtra-13.05.2023-16:04	seva	xtra.changelog.xml	2025-04-11 10:14:22.729583	197	EXECUTED	8:b4dead93cc53d324870481947827f045	sql	Permission,new: plugin_xtra_access	\N	3.6.3	common	\N	4384462717
\.


--
-- Data for Name: databasechangeloglock; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.databasechangeloglock (id, locked, lockgranted, lockedby) FROM stdin;
1	f	\N	\N
\.


--
-- Data for Name: deviceapplicationsettings; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.deviceapplicationsettings (id, applicationid, name, type, value, comment, readonly, extrefid, lastupdate) FROM stdin;
\.


--
-- Data for Name: devicegroups; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.devicegroups (id, deviceid, groupid) FROM stdin;
\.


--
-- Data for Name: devices; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.devices (id, number, description, lastupdate, configurationid, oldconfigurationid, info, imei, phone, customerid, imeiupdatets, custom1, custom2, custom3, oldnumber, fastsearch, enrolltime, infojson, publicip) FROM stdin;
\.


--
-- Data for Name: devicestatuses; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.devicestatuses (deviceid, configfilesstatus, applicationsstatus) FROM stdin;
\.


--
-- Data for Name: groups; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.groups (id, name, customerid) FROM stdin;
1	Общая	1
\.


--
-- Data for Name: icons; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.icons (id, customerid, name, fileid) FROM stdin;
\.


--
-- Data for Name: pendingpushes; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.pendingpushes (id, messageid, status, createtime, sendtime) FROM stdin;
\.


--
-- Data for Name: pendingsignup; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.pendingsignup (id, email, signuptime, language, token) FROM stdin;
\.


--
-- Data for Name: permissions; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.permissions (id, name, description, superadmin) FROM stdin;
1	superadmin	Функции супер-администратора всего приложения	t
2	settings	Имеет доступ к настройкам и видит их в меню	f
3	configurations	Имеет доступ к конфигурациям, приложениям и файлам и видит их в меню	f
4	edit_devices	Имеет доступ к редактированию и добавлению устройств	f
100	edit_device_desc	Иммет доступ к редактированию описания устройства	f
101	edit_device_app_settings	Имеет доступ к редактированию и добавлению настроек приложения для устройства	f
5	add_config	Add new empty configurations	f
6	copy_config	Duplicate/copy configurations	f
102	push_api	Send Push messages to devices via REST API	f
103	get_updates	Can update apps automatically	f
104	applications	View the applications tab	f
105	edit_applications	Add and edit applications	f
106	edit_application_versions	Add and edit versions of existing applications	f
107	files	View the files tab	f
108	edit_files	Add and edit files	f
109	plugins_customer_access_management	Имеет доступ к управлению списком используемых плагинов на уровне учетной записи своей организации	f
110	plugin_audit_access	Имеет доступ к аудиту действий пользователей	f
111	plugin_deviceinfo_access	Имеет доступ к детальной и динамической информации об устройствах	f
112	plugin_devicelog_access	Имеет доступ к журналам устройств	f
113	plugin_messaging_send	Can send messages to devices	f
114	plugin_messaging_delete	Can delete and update message history	f
115	plugin_push_send	Can send push messages to devices	f
116	plugin_push_delete	Can delete and update Push message history	f
117	plugin_xtra_access	Access to Premium version request plugin	f
\.


--
-- Data for Name: plugin_audit_log; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugin_audit_log (id, createtime, customerid, userid, login, action, payload, ipaddress, errorcode) FROM stdin;
1	1744384488842	1	1	admin	plugin.audit.action.user.login	Method: POST\nURI: /hmdm/rest/public/auth/login\nBody: {"password":"******","login":"admin"}\nUser-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36	0:0:0:0:0:0:0:1	0
2	1744388472505	1	1	admin	plugin.audit.action.user.login	Method: POST\nURI: /hmdm/rest/public/auth/login\nBody: {"password":"******","login":"admin"}\nUser-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36	0:0:0:0:0:0:0:1	0
\.


--
-- Data for Name: plugin_deviceinfo_deviceparams; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugin_deviceinfo_deviceparams (id, deviceid, customerid, ts) FROM stdin;
\.


--
-- Data for Name: plugin_deviceinfo_deviceparams_device; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugin_deviceinfo_deviceparams_device (id, recordid, batterylevel, batterycharging, ip, keyguard, ringvolume, wifi, mobiledata, gps, bluetooth, usbstorage, memorytotal, memoryavailable) FROM stdin;
\.


--
-- Data for Name: plugin_deviceinfo_deviceparams_gps; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugin_deviceinfo_deviceparams_gps (id, recordid, state, lat, lon, alt, speed, course) FROM stdin;
\.


--
-- Data for Name: plugin_deviceinfo_deviceparams_mobile; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugin_deviceinfo_deviceparams_mobile (id, recordid, rssi, carrier, data, ip, state, simstate, tx, rx) FROM stdin;
\.


--
-- Data for Name: plugin_deviceinfo_deviceparams_mobile2; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugin_deviceinfo_deviceparams_mobile2 (id, recordid, rssi, carrier, data, ip, state, simstate, tx, rx) FROM stdin;
\.


--
-- Data for Name: plugin_deviceinfo_deviceparams_wifi; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugin_deviceinfo_deviceparams_wifi (id, recordid, rssi, ssid, security, state, ip, tx, rx) FROM stdin;
\.


--
-- Data for Name: plugin_deviceinfo_settings; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugin_deviceinfo_settings (id, customerid, datapreserveperiod, senddata, intervalmins) FROM stdin;
\.


--
-- Data for Name: plugin_devicelog_log; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugin_devicelog_log (id, createtime, customerid, deviceid, applicationid, ipaddress, severity, severityorder, message) FROM stdin;
\.


--
-- Data for Name: plugin_devicelog_setting_rule_devices; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugin_devicelog_setting_rule_devices (ruleid, deviceid) FROM stdin;
\.


--
-- Data for Name: plugin_devicelog_settings; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugin_devicelog_settings (id, customerid, logspreserveperiod) FROM stdin;
1	1	30
\.


--
-- Data for Name: plugin_devicelog_settings_rules; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugin_devicelog_settings_rules (id, settingid, name, active, applicationid, severity, filter, groupid, configurationid) FROM stdin;
\.


--
-- Data for Name: plugin_messaging_messages; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugin_messaging_messages (id, customerid, deviceid, ts, message, status) FROM stdin;
\.


--
-- Data for Name: plugin_push_messages; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugin_push_messages (id, customerid, deviceid, ts, messagetype, payload) FROM stdin;
\.


--
-- Data for Name: plugin_push_schedule; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugin_push_schedule (id, customerid, deviceid, groupid, configurationid, scope, messagetype, payload, comment, min, minbit, hour, hourbit, day, daybit, weekday, weekdaybit, month, monthbit) FROM stdin;
\.


--
-- Data for Name: plugins; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.plugins (id, identifier, name, description, createtime, disabled, javascriptmodulefile, functionsviewtemplate, settingsviewtemplate, namelocalizationkey, settingspermission, functionspermission, devicefunctionspermission, enabledfordevice) FROM stdin;
1	audit	Аудит	Аудит действий пользователей приложания	2025-04-11 10:14:22.100198	f	app/components/plugins/audit/audit.module.js	app/components/plugins/audit/views/audit.html	\N	plugin.audit.localization.key.name	plugin_audit_access	plugin_audit_access	plugin_audit_access	f
2	deviceinfo	Детальная информация	Детальная и динамическая информация об устройствах	2025-04-11 10:14:22.195669	f	app/components/plugins/deviceinfo/deviceinfo.module.js	app/components/plugins/deviceinfo/views/info.html	app/components/plugins/deviceinfo/views/settings.html	plugin.deviceinfo.localization.key.name	plugin_deviceinfo_access	plugin_deviceinfo_access	plugin_deviceinfo_access	t
3	devicelog	Журналы	Журналы отладочных записей, присланных устройствами	2025-04-11 10:14:22.374129	f	app/components/plugins/devicelog/devicelog.module.js	app/components/plugins/devicelog/views/logs.html	app/components/plugins/devicelog/views/settings.html	plugin.devicelog.localization.key.name	plugin_devicelog_access	plugin_devicelog_access	plugin_devicelog_access	t
4	messaging	Messaging	Sending messages to devices	2025-04-11 10:14:22.549468	f	app/components/plugins/messaging/messaging.module.js	app/components/plugins/messaging/views/messaging.html	app/components/plugins/messaging/views/settings.html	plugin.messaging.localization.key.name	plugin_messaging_delete	plugin_messaging_send	plugin_messaging_send	t
5	push	Push Messages	Sending Push messages to devices	2025-04-11 10:14:22.628673	f	app/components/plugins/push/push.module.js	app/components/plugins/push/views/push.html	app/components/plugins/push/views/settings.html	plugin.push.localization.key.name	plugin_push_delete	plugin_push_send	plugin_push_send	t
6	xtra	More plugins...	Request for more plugins in the Premium version	2025-04-11 10:14:22.718406	f	app/components/plugins/xtra/xtra.module.js	app/components/plugins/xtra/views/xtra.html	\N	plugin.xtra.localization.key.name	plugin_xtra_access	plugin_xtra_access	plugin_xtra_access	f
\.


--
-- Data for Name: pluginsdisabled; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.pluginsdisabled (pluginid, customerid) FROM stdin;
\.


--
-- Data for Name: pushmessages; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.pushmessages (id, messagetype, deviceid, payload) FROM stdin;
\.


--
-- Data for Name: settings; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.settings (id, backgroundcolor, textcolor, backgroundimageurl, iconsize, desktopheader, customerid, usedefaultlanguage, language, createnewdevices, newdevicegroupid, newdeviceconfigurationid, phonenumberformat, custompropertyname1, custompropertyname2, custompropertyname3, custommultiline1, custommultiline2, custommultiline3, customsend1, customsend2, customsend3, desktopheadertemplate, senddescription, passwordreset, passwordlength, passwordstrength, twofactor, idlelogout) FROM stdin;
\.


--
-- Data for Name: trialkey; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.trialkey (id, keycode, created) FROM stdin;
\.


--
-- Data for Name: uploadedfiles; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.uploadedfiles (id, customerid, filepath, uploadtime) FROM stdin;
\.


--
-- Data for Name: usagestats; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.usagestats (id, ts, instanceid, webversion, community, devicestotal, devicesonline, cputotal, cpuused, ramtotal, ramused, scheme, arch, os) FROM stdin;
\.


--
-- Data for Name: userconfigurationaccess; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.userconfigurationaccess (id, userid, configurationid) FROM stdin;
\.


--
-- Data for Name: userdevicegroupsaccess; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.userdevicegroupsaccess (id, userid, groupid) FROM stdin;
\.


--
-- Data for Name: userhints; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.userhints (id, userid, hintkey, created) FROM stdin;
\.


--
-- Data for Name: userhinttypes; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.userhinttypes (hintkey) FROM stdin;
hint.step.1
hint.step.2
hint.step.3
hint.step.4
\.


--
-- Data for Name: userrolepermissions; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.userrolepermissions (roleid, permissionid) FROM stdin;
1	1
2	2
2	3
2	4
3	3
3	4
1	100
2	100
3	100
100	100
1	101
2	101
1	5
2	5
1	6
2	6
3	6
1	102
2	102
3	102
1	103
2	103
1	104
2	104
3	104
100	104
1	105
2	105
3	105
1	106
2	106
3	106
1	107
2	107
3	107
100	107
1	108
2	108
3	108
1	109
2	109
1	110
2	110
1	111
2	111
3	111
100	111
1	112
2	112
1	113
2	113
3	113
100	113
1	114
2	114
1	115
2	115
3	115
100	115
1	116
2	116
1	117
2	117
3	117
\.


--
-- Data for Name: userroles; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.userroles (id, name, description, superadmin) FROM stdin;
1	Супер-Администратор	Всевидящее око Саурона	t
2	Администратор	Выполняет функции администратора для одной клиентской записи	f
3	Пользователь	Пользователь для одной клиентской записи	f
100	Наблюдатель	Наблюдатель зорко наблюдает	f
\.


--
-- Data for Name: userrolesettings; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.userrolesettings (id, roleid, customerid, columndisplayeddevicestatus, columndisplayeddevicedate, columndisplayeddevicenumber, columndisplayeddevicemodel, columndisplayeddevicepermissionsstatus, columndisplayeddeviceappinstallstatus, columndisplayeddeviceconfiguration, columndisplayeddeviceimei, columndisplayeddevicephone, columndisplayeddevicedesc, columndisplayeddevicegroup, columndisplayedlauncherversion, columndisplayedbatterylevel, columndisplayeddevicefilesstatus, columndisplayeddefaultlauncher, columndisplayedcustom1, columndisplayedcustom2, columndisplayedcustom3, columndisplayedmdmmode, columndisplayedkioskmode, columndisplayedandroidversion, columndisplayedenrollmentdate, columndisplayedserial, columndisplayedpublicip) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: hmdm
--

COPY public.users (id, login, email, name, password, customerid, userroleid, alldevicesavailable, allconfigavailable, passwordreset, authtoken, passwordresettoken, authdata, twofactorsecret, twofactoraccepted, lastloginfail) FROM stdin;
1	admin	fast.daemon@gmail.com	admin	349242D38ED8667B5C11D2412EBEA4636BD3CA3A	1	2	t	t	f	pw30by2ffgYwAIwqXQCI	\N	\N	\N	f	0
\.


--
-- Name: applications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.applications_id_seq', 1, false);


--
-- Name: applicationversions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.applicationversions_id_seq', 10000, false);


--
-- Name: configurationapplicationparameters_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.configurationapplicationparameters_id_seq', 1, false);


--
-- Name: configurationapplications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.configurationapplications_id_seq', 1, false);


--
-- Name: configurationapplicationsettings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.configurationapplicationsettings_id_seq', 1, false);


--
-- Name: configurationfiles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.configurationfiles_id_seq', 1, false);


--
-- Name: configurations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.configurations_id_seq', 1, true);


--
-- Name: customers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.customers_id_seq', 1, true);


--
-- Name: deviceapplicationsettings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.deviceapplicationsettings_id_seq', 1, false);


--
-- Name: devicegroups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.devicegroups_id_seq', 1, false);


--
-- Name: devices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.devices_id_seq', 1, false);


--
-- Name: groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.groups_id_seq', 1, true);


--
-- Name: icons_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.icons_id_seq', 1, false);


--
-- Name: pendingpushes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.pendingpushes_id_seq', 1, false);


--
-- Name: pendingsignup_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.pendingsignup_id_seq', 1, false);


--
-- Name: permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.permissions_id_seq', 117, true);


--
-- Name: plugin_audit_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.plugin_audit_log_id_seq', 2, true);


--
-- Name: plugin_deviceinfo_deviceparams_device_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.plugin_deviceinfo_deviceparams_device_id_seq', 1, false);


--
-- Name: plugin_deviceinfo_deviceparams_gps_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.plugin_deviceinfo_deviceparams_gps_id_seq', 1, false);


--
-- Name: plugin_deviceinfo_deviceparams_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.plugin_deviceinfo_deviceparams_id_seq', 1, false);


--
-- Name: plugin_deviceinfo_deviceparams_mobile2_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.plugin_deviceinfo_deviceparams_mobile2_id_seq', 1, false);


--
-- Name: plugin_deviceinfo_deviceparams_mobile_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.plugin_deviceinfo_deviceparams_mobile_id_seq', 1, false);


--
-- Name: plugin_deviceinfo_deviceparams_wifi_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.plugin_deviceinfo_deviceparams_wifi_id_seq', 1, false);


--
-- Name: plugin_deviceinfo_settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.plugin_deviceinfo_settings_id_seq', 1, false);


--
-- Name: plugin_devicelog_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.plugin_devicelog_log_id_seq', 1, false);


--
-- Name: plugin_devicelog_settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.plugin_devicelog_settings_id_seq', 1, true);


--
-- Name: plugin_devicelog_settings_rules_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.plugin_devicelog_settings_rules_id_seq', 1, false);


--
-- Name: plugin_messaging_messages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.plugin_messaging_messages_id_seq', 1, false);


--
-- Name: plugin_push_messages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.plugin_push_messages_id_seq', 1, false);


--
-- Name: plugin_push_schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.plugin_push_schedule_id_seq', 1, false);


--
-- Name: plugins_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.plugins_id_seq', 6, true);


--
-- Name: pushmessages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.pushmessages_id_seq', 1, false);


--
-- Name: settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.settings_id_seq', 1, false);


--
-- Name: trialkey_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.trialkey_id_seq', 1, false);


--
-- Name: uploadedfiles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.uploadedfiles_id_seq', 1, false);


--
-- Name: usagestats_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.usagestats_id_seq', 1, false);


--
-- Name: userconfigurationaccess_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.userconfigurationaccess_id_seq', 1, false);


--
-- Name: userdevicegroupsaccess_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.userdevicegroupsaccess_id_seq', 1, false);


--
-- Name: userhints_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.userhints_id_seq', 1, false);


--
-- Name: userroles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.userroles_id_seq', 100, true);


--
-- Name: userrolesettings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.userrolesettings_id_seq', 1, false);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: hmdm
--

SELECT pg_catalog.setval('public.users_id_seq', 1, true);


--
-- Name: applications applications_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_pr_key PRIMARY KEY (id);


--
-- Name: applicationversions applicationversions_app_version_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.applicationversions
    ADD CONSTRAINT applicationversions_app_version_key UNIQUE (applicationid, version);


--
-- Name: applicationversions applicationversions_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.applicationversions
    ADD CONSTRAINT applicationversions_pr_key PRIMARY KEY (id);


--
-- Name: configurationapplicationparameters cap_config_application_unique; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationapplicationparameters
    ADD CONSTRAINT cap_config_application_unique UNIQUE (configurationid, applicationid);


--
-- Name: configurationapplicationparameters configuration_application_parameters_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationapplicationparameters
    ADD CONSTRAINT configuration_application_parameters_pr_key PRIMARY KEY (id);


--
-- Name: configurationapplications configuration_applications_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationapplications
    ADD CONSTRAINT configuration_applications_pr_key PRIMARY KEY (id);


--
-- Name: configurationapplicationsettings configurationapplicationsettings_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationapplicationsettings
    ADD CONSTRAINT configurationapplicationsettings_pr_key PRIMARY KEY (id);


--
-- Name: configurationfiles configurationfiles_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationfiles
    ADD CONSTRAINT configurationfiles_pr_key PRIMARY KEY (id);


--
-- Name: configurations configurations_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurations
    ADD CONSTRAINT configurations_pr_key PRIMARY KEY (id);


--
-- Name: customers customer_filesdir_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customer_filesdir_key UNIQUE (filesdir);


--
-- Name: customers customer_name_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customer_name_key UNIQUE (name);


--
-- Name: customers customers_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pr_key PRIMARY KEY (id);


--
-- Name: customers customers_prefix_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_prefix_key UNIQUE (prefix);


--
-- Name: databasechangeloglock databasechangeloglock_pkey; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.databasechangeloglock
    ADD CONSTRAINT databasechangeloglock_pkey PRIMARY KEY (id);


--
-- Name: deviceapplicationsettings deviceapplicationsettings_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.deviceapplicationsettings
    ADD CONSTRAINT deviceapplicationsettings_pr_key PRIMARY KEY (id);


--
-- Name: devicegroups devicegroups_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.devicegroups
    ADD CONSTRAINT devicegroups_pr_key PRIMARY KEY (id);


--
-- Name: devices devices_number_unique; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_number_unique UNIQUE (number);


--
-- Name: devices devices_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_pr_key PRIMARY KEY (id);


--
-- Name: devicestatuses devicestatuses_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.devicestatuses
    ADD CONSTRAINT devicestatuses_pr_key PRIMARY KEY (deviceid);


--
-- Name: groups groups_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pr_key PRIMARY KEY (id);


--
-- Name: icons icons_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.icons
    ADD CONSTRAINT icons_pr_key PRIMARY KEY (id);


--
-- Name: users login_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT login_key UNIQUE (login);


--
-- Name: pendingpushes pending_push_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.pendingpushes
    ADD CONSTRAINT pending_push_pr_key PRIMARY KEY (id);


--
-- Name: pendingpushes pendingpushes_messageid_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.pendingpushes
    ADD CONSTRAINT pendingpushes_messageid_key UNIQUE (messageid);


--
-- Name: pendingsignup pendingsignup_email_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.pendingsignup
    ADD CONSTRAINT pendingsignup_email_key UNIQUE (email);


--
-- Name: pendingsignup pendingsignup_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.pendingsignup
    ADD CONSTRAINT pendingsignup_pr_key PRIMARY KEY (id);


--
-- Name: permissions permissions_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pr_key PRIMARY KEY (id);


--
-- Name: plugin_audit_log plugin_audit_log_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_audit_log
    ADD CONSTRAINT plugin_audit_log_pr_key PRIMARY KEY (id);


--
-- Name: plugin_deviceinfo_deviceparams_device plugin_deviceinfo_deviceparams_device_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_device
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_device_pr_key PRIMARY KEY (id);


--
-- Name: plugin_deviceinfo_deviceparams_device plugin_deviceinfo_deviceparams_device_recordid_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_device
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_device_recordid_key UNIQUE (recordid);


--
-- Name: plugin_deviceinfo_deviceparams_gps plugin_deviceinfo_deviceparams_gps_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_gps
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_gps_pr_key PRIMARY KEY (id);


--
-- Name: plugin_deviceinfo_deviceparams_gps plugin_deviceinfo_deviceparams_gps_recordid_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_gps
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_gps_recordid_key UNIQUE (recordid);


--
-- Name: plugin_deviceinfo_deviceparams_mobile2 plugin_deviceinfo_deviceparams_mobile2_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_mobile2
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_mobile2_pr_key PRIMARY KEY (id);


--
-- Name: plugin_deviceinfo_deviceparams_mobile2 plugin_deviceinfo_deviceparams_mobile2_recordid_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_mobile2
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_mobile2_recordid_key UNIQUE (recordid);


--
-- Name: plugin_deviceinfo_deviceparams_mobile plugin_deviceinfo_deviceparams_mobile_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_mobile
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_mobile_pr_key PRIMARY KEY (id);


--
-- Name: plugin_deviceinfo_deviceparams_mobile plugin_deviceinfo_deviceparams_mobile_recordid_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_mobile
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_mobile_recordid_key UNIQUE (recordid);


--
-- Name: plugin_deviceinfo_deviceparams plugin_deviceinfo_deviceparams_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_pr_key PRIMARY KEY (id);


--
-- Name: plugin_deviceinfo_deviceparams_wifi plugin_deviceinfo_deviceparams_wifi_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_wifi
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_wifi_pr_key PRIMARY KEY (id);


--
-- Name: plugin_deviceinfo_deviceparams_wifi plugin_deviceinfo_deviceparams_wifi_recordid_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_wifi
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_wifi_recordid_key UNIQUE (recordid);


--
-- Name: plugin_deviceinfo_settings plugin_deviceinfo_settings_customer_unique; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_settings
    ADD CONSTRAINT plugin_deviceinfo_settings_customer_unique UNIQUE (customerid);


--
-- Name: plugin_deviceinfo_settings plugin_deviceinfo_settings_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_settings
    ADD CONSTRAINT plugin_deviceinfo_settings_pr_key PRIMARY KEY (id);


--
-- Name: plugin_devicelog_log plugin_devicelog_log_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_log
    ADD CONSTRAINT plugin_devicelog_log_pr_key PRIMARY KEY (id);


--
-- Name: plugin_devicelog_settings plugin_devicelog_settings_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_settings
    ADD CONSTRAINT plugin_devicelog_settings_pr_key PRIMARY KEY (id);


--
-- Name: plugin_devicelog_settings_rules plugin_devicelog_settings_rules_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_settings_rules
    ADD CONSTRAINT plugin_devicelog_settings_rules_pr_key PRIMARY KEY (id);


--
-- Name: plugins plugin_identifier_unq; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugins
    ADD CONSTRAINT plugin_identifier_unq UNIQUE (identifier);


--
-- Name: plugin_messaging_messages plugin_messaging_messages_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_messaging_messages
    ADD CONSTRAINT plugin_messaging_messages_pr_key PRIMARY KEY (id);


--
-- Name: plugin_push_messages plugin_push_messages_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_push_messages
    ADD CONSTRAINT plugin_push_messages_pr_key PRIMARY KEY (id);


--
-- Name: plugin_push_schedule plugin_push_schedule_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_push_schedule
    ADD CONSTRAINT plugin_push_schedule_pr_key PRIMARY KEY (id);


--
-- Name: plugins plugins_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugins
    ADD CONSTRAINT plugins_pr_key PRIMARY KEY (id);


--
-- Name: pushmessages push_message_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.pushmessages
    ADD CONSTRAINT push_message_pr_key PRIMARY KEY (id);


--
-- Name: configurations qrcodekey_uniq; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurations
    ADD CONSTRAINT qrcodekey_uniq UNIQUE (qrcodekey);


--
-- Name: userroles roles_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userroles
    ADD CONSTRAINT roles_pr_key PRIMARY KEY (id);


--
-- Name: settings settings_customer_unique; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT settings_customer_unique UNIQUE (customerid);


--
-- Name: settings settings_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT settings_pr_key PRIMARY KEY (id);


--
-- Name: trialkey trialkey_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.trialkey
    ADD CONSTRAINT trialkey_pr_key PRIMARY KEY (id);


--
-- Name: uploadedfiles uploadedfiles_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.uploadedfiles
    ADD CONSTRAINT uploadedfiles_pr_key PRIMARY KEY (id);


--
-- Name: usagestats usagestats_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.usagestats
    ADD CONSTRAINT usagestats_pr_key PRIMARY KEY (id);


--
-- Name: usagestats usagestats_ts_instanceid_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.usagestats
    ADD CONSTRAINT usagestats_ts_instanceid_key UNIQUE (ts, instanceid);


--
-- Name: userconfigurationaccess userconfigurationaccess_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userconfigurationaccess
    ADD CONSTRAINT userconfigurationaccess_pr_key PRIMARY KEY (id);


--
-- Name: userdevicegroupsaccess userdevicegroupsaccess_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userdevicegroupsaccess
    ADD CONSTRAINT userdevicegroupsaccess_pr_key PRIMARY KEY (id);


--
-- Name: userhints userhints_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userhints
    ADD CONSTRAINT userhints_pr_key PRIMARY KEY (id);


--
-- Name: userhints userhints_userid_hintkey_unique; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userhints
    ADD CONSTRAINT userhints_userid_hintkey_unique UNIQUE (userid, hintkey);


--
-- Name: userhinttypes userhinttypes_hintkey_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userhinttypes
    ADD CONSTRAINT userhinttypes_hintkey_key UNIQUE (hintkey);


--
-- Name: userrolesettings userrolesettings_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userrolesettings
    ADD CONSTRAINT userrolesettings_pr_key PRIMARY KEY (id);


--
-- Name: userrolesettings userrolesettings_role_customer_uniq; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userrolesettings
    ADD CONSTRAINT userrolesettings_role_customer_uniq UNIQUE (roleid, customerid);


--
-- Name: users users_login_unique; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_login_unique UNIQUE (login);


--
-- Name: users users_pr_key; Type: CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pr_key PRIMARY KEY (id);


--
-- Name: applications_customerid_idx; Type: INDEX; Schema: public; Owner: hmdm
--

CREATE INDEX applications_customerid_idx ON public.applications USING btree (customerid);


--
-- Name: applications_pkg_idx; Type: INDEX; Schema: public; Owner: hmdm
--

CREATE INDEX applications_pkg_idx ON public.applications USING btree (pkg);


--
-- Name: applicationversionss_applicationid_idx; Type: INDEX; Schema: public; Owner: hmdm
--

CREATE INDEX applicationversionss_applicationid_idx ON public.applicationversions USING btree (applicationid);


--
-- Name: configurationfiles_configurationid_idx; Type: INDEX; Schema: public; Owner: hmdm
--

CREATE INDEX configurationfiles_configurationid_idx ON public.configurationfiles USING btree (configurationid);


--
-- Name: configurations_contentappid_idx; Type: INDEX; Schema: public; Owner: hmdm
--

CREATE INDEX configurations_contentappid_idx ON public.configurations USING btree (contentappid);


--
-- Name: configurations_customerid_idx; Type: INDEX; Schema: public; Owner: hmdm
--

CREATE INDEX configurations_customerid_idx ON public.configurations USING btree (customerid);


--
-- Name: configurations_mainappid_idx; Type: INDEX; Schema: public; Owner: hmdm
--

CREATE INDEX configurations_mainappid_idx ON public.configurations USING btree (mainappid);


--
-- Name: devices_configurationid_idx; Type: INDEX; Schema: public; Owner: hmdm
--

CREATE INDEX devices_configurationid_idx ON public.devices USING btree (configurationid);


--
-- Name: devices_customerid_idx; Type: INDEX; Schema: public; Owner: hmdm
--

CREATE INDEX devices_customerid_idx ON public.devices USING btree (customerid);


--
-- Name: devices_deviceid_idx; Type: INDEX; Schema: public; Owner: hmdm
--

CREATE INDEX devices_deviceid_idx ON public.devicegroups USING btree (deviceid);


--
-- Name: devices_fastsearch_idx; Type: INDEX; Schema: public; Owner: hmdm
--

CREATE INDEX devices_fastsearch_idx ON public.devices USING btree (fastsearch);


--
-- Name: devices_groupid_idx; Type: INDEX; Schema: public; Owner: hmdm
--

CREATE INDEX devices_groupid_idx ON public.devicegroups USING btree (groupid);


--
-- Name: devices_number_idx; Type: INDEX; Schema: public; Owner: hmdm
--

CREATE INDEX devices_number_idx ON public.devices USING btree (number);


--
-- Name: icons_customerid_idx; Type: INDEX; Schema: public; Owner: hmdm
--

CREATE INDEX icons_customerid_idx ON public.icons USING btree (customerid);


--
-- Name: applications applications_iconid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_iconid_fkey FOREIGN KEY (iconid) REFERENCES public.icons(id) ON DELETE SET NULL;


--
-- Name: applications applications_latestversion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_latestversion_fkey FOREIGN KEY (latestversion) REFERENCES public.applicationversions(id) ON DELETE SET NULL;


--
-- Name: applicationversions applicationversions_applicationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.applicationversions
    ADD CONSTRAINT applicationversions_applicationid_fkey FOREIGN KEY (applicationid) REFERENCES public.applications(id) ON DELETE CASCADE;


--
-- Name: configurationapplicationparameters configurationapplicationparameters_applicationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationapplicationparameters
    ADD CONSTRAINT configurationapplicationparameters_applicationid_fkey FOREIGN KEY (applicationid) REFERENCES public.applications(id) ON DELETE CASCADE;


--
-- Name: configurationapplicationparameters configurationapplicationparameters_configurationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationapplicationparameters
    ADD CONSTRAINT configurationapplicationparameters_configurationid_fkey FOREIGN KEY (configurationid) REFERENCES public.configurations(id) ON DELETE CASCADE;


--
-- Name: configurationapplications configurationapplications_applicationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationapplications
    ADD CONSTRAINT configurationapplications_applicationid_fkey FOREIGN KEY (applicationid) REFERENCES public.applications(id) ON DELETE CASCADE;


--
-- Name: configurationapplications configurationapplications_applicationversionid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationapplications
    ADD CONSTRAINT configurationapplications_applicationversionid_fkey FOREIGN KEY (applicationversionid) REFERENCES public.applicationversions(id) ON DELETE RESTRICT;


--
-- Name: configurationapplications configurationapplications_configurationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationapplications
    ADD CONSTRAINT configurationapplications_configurationid_fkey FOREIGN KEY (configurationid) REFERENCES public.configurations(id) ON DELETE CASCADE;


--
-- Name: configurationapplicationsettings configurationapplicationsettings_applicationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationapplicationsettings
    ADD CONSTRAINT configurationapplicationsettings_applicationid_fkey FOREIGN KEY (applicationid) REFERENCES public.applications(id) ON DELETE CASCADE;


--
-- Name: configurationapplicationsettings configurationapplicationsettings_extrefid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationapplicationsettings
    ADD CONSTRAINT configurationapplicationsettings_extrefid_fkey FOREIGN KEY (extrefid) REFERENCES public.configurations(id) ON DELETE CASCADE;


--
-- Name: configurationfiles configurationfiles_configurationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationfiles
    ADD CONSTRAINT configurationfiles_configurationid_fkey FOREIGN KEY (configurationid) REFERENCES public.configurations(id) ON DELETE CASCADE;


--
-- Name: configurationfiles configurationfiles_fileid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurationfiles
    ADD CONSTRAINT configurationfiles_fileid_fkey FOREIGN KEY (fileid) REFERENCES public.uploadedfiles(id) ON DELETE CASCADE;


--
-- Name: configurations configurations_contentappid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurations
    ADD CONSTRAINT configurations_contentappid_fkey FOREIGN KEY (contentappid) REFERENCES public.applicationversions(id) ON DELETE RESTRICT;


--
-- Name: configurations configurations_mainappid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurations
    ADD CONSTRAINT configurations_mainappid_fkey FOREIGN KEY (mainappid) REFERENCES public.applicationversions(id) ON DELETE RESTRICT;


--
-- Name: deviceapplicationsettings deviceapplicationsettings_applicationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.deviceapplicationsettings
    ADD CONSTRAINT deviceapplicationsettings_applicationid_fkey FOREIGN KEY (applicationid) REFERENCES public.applications(id) ON DELETE CASCADE;


--
-- Name: deviceapplicationsettings deviceapplicationsettings_extrefid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.deviceapplicationsettings
    ADD CONSTRAINT deviceapplicationsettings_extrefid_fkey FOREIGN KEY (extrefid) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: devicegroups devicegroups_deviceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.devicegroups
    ADD CONSTRAINT devicegroups_deviceid_fkey FOREIGN KEY (deviceid) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: devicegroups devicegroups_groupid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.devicegroups
    ADD CONSTRAINT devicegroups_groupid_fkey FOREIGN KEY (groupid) REFERENCES public.groups(id) ON DELETE CASCADE;


--
-- Name: devicestatuses devicestatuses_deviceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.devicestatuses
    ADD CONSTRAINT devicestatuses_deviceid_fkey FOREIGN KEY (deviceid) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: applications fk_customer_1; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT fk_customer_1 FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: configurations fk_customer_2; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.configurations
    ADD CONSTRAINT fk_customer_2 FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: devices fk_customer_3; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT fk_customer_3 FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: groups fk_customer_4; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT fk_customer_4 FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: settings fk_customer_5; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT fk_customer_5 FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: users fk_customer_6; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_customer_6 FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: icons icons_customerid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.icons
    ADD CONSTRAINT icons_customerid_fkey FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: icons icons_fileid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.icons
    ADD CONSTRAINT icons_fileid_fkey FOREIGN KEY (fileid) REFERENCES public.uploadedfiles(id) ON DELETE CASCADE;


--
-- Name: pendingpushes pendingpushes_messageid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.pendingpushes
    ADD CONSTRAINT pendingpushes_messageid_fkey FOREIGN KEY (messageid) REFERENCES public.pushmessages(id) ON DELETE CASCADE;


--
-- Name: plugin_deviceinfo_deviceparams plugin_deviceinfo_deviceparams_customerid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_customerid_fkey FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: plugin_deviceinfo_deviceparams_device plugin_deviceinfo_deviceparams_device_recordid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_device
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_device_recordid_fkey FOREIGN KEY (recordid) REFERENCES public.plugin_deviceinfo_deviceparams(id) ON DELETE CASCADE;


--
-- Name: plugin_deviceinfo_deviceparams plugin_deviceinfo_deviceparams_deviceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_deviceid_fkey FOREIGN KEY (deviceid) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: plugin_deviceinfo_deviceparams_gps plugin_deviceinfo_deviceparams_gps_recordid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_gps
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_gps_recordid_fkey FOREIGN KEY (recordid) REFERENCES public.plugin_deviceinfo_deviceparams(id) ON DELETE CASCADE;


--
-- Name: plugin_deviceinfo_deviceparams_mobile2 plugin_deviceinfo_deviceparams_mobile2_recordid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_mobile2
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_mobile2_recordid_fkey FOREIGN KEY (recordid) REFERENCES public.plugin_deviceinfo_deviceparams(id) ON DELETE CASCADE;


--
-- Name: plugin_deviceinfo_deviceparams_mobile plugin_deviceinfo_deviceparams_mobile_recordid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_mobile
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_mobile_recordid_fkey FOREIGN KEY (recordid) REFERENCES public.plugin_deviceinfo_deviceparams(id) ON DELETE CASCADE;


--
-- Name: plugin_deviceinfo_deviceparams_wifi plugin_deviceinfo_deviceparams_wifi_recordid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_deviceparams_wifi
    ADD CONSTRAINT plugin_deviceinfo_deviceparams_wifi_recordid_fkey FOREIGN KEY (recordid) REFERENCES public.plugin_deviceinfo_deviceparams(id) ON DELETE CASCADE;


--
-- Name: plugin_deviceinfo_settings plugin_deviceinfo_settings_customerid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_deviceinfo_settings
    ADD CONSTRAINT plugin_deviceinfo_settings_customerid_fkey FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: plugin_devicelog_log plugin_devicelog_log_applicationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_log
    ADD CONSTRAINT plugin_devicelog_log_applicationid_fkey FOREIGN KEY (applicationid) REFERENCES public.applications(id) ON DELETE CASCADE;


--
-- Name: plugin_devicelog_log plugin_devicelog_log_customerid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_log
    ADD CONSTRAINT plugin_devicelog_log_customerid_fkey FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: plugin_devicelog_log plugin_devicelog_log_deviceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_log
    ADD CONSTRAINT plugin_devicelog_log_deviceid_fkey FOREIGN KEY (deviceid) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: plugin_devicelog_setting_rule_devices plugin_devicelog_setting_rule_devices_deviceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_setting_rule_devices
    ADD CONSTRAINT plugin_devicelog_setting_rule_devices_deviceid_fkey FOREIGN KEY (deviceid) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: plugin_devicelog_setting_rule_devices plugin_devicelog_setting_rule_devices_ruleid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_setting_rule_devices
    ADD CONSTRAINT plugin_devicelog_setting_rule_devices_ruleid_fkey FOREIGN KEY (ruleid) REFERENCES public.plugin_devicelog_settings_rules(id) ON DELETE CASCADE;


--
-- Name: plugin_devicelog_settings plugin_devicelog_settings_customerid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_settings
    ADD CONSTRAINT plugin_devicelog_settings_customerid_fkey FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: plugin_devicelog_settings_rules plugin_devicelog_settings_rules_applicationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_settings_rules
    ADD CONSTRAINT plugin_devicelog_settings_rules_applicationid_fkey FOREIGN KEY (applicationid) REFERENCES public.applications(id) ON DELETE CASCADE;


--
-- Name: plugin_devicelog_settings_rules plugin_devicelog_settings_rules_configurationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_settings_rules
    ADD CONSTRAINT plugin_devicelog_settings_rules_configurationid_fkey FOREIGN KEY (configurationid) REFERENCES public.configurations(id) ON DELETE CASCADE;


--
-- Name: plugin_devicelog_settings_rules plugin_devicelog_settings_rules_groupid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_settings_rules
    ADD CONSTRAINT plugin_devicelog_settings_rules_groupid_fkey FOREIGN KEY (groupid) REFERENCES public.groups(id) ON DELETE CASCADE;


--
-- Name: plugin_devicelog_settings_rules plugin_devicelog_settings_rules_settingid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_devicelog_settings_rules
    ADD CONSTRAINT plugin_devicelog_settings_rules_settingid_fkey FOREIGN KEY (settingid) REFERENCES public.plugin_devicelog_settings(id) ON DELETE CASCADE;


--
-- Name: plugin_messaging_messages plugin_messaging_messages_customerid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_messaging_messages
    ADD CONSTRAINT plugin_messaging_messages_customerid_fkey FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: plugin_messaging_messages plugin_messaging_messages_deviceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_messaging_messages
    ADD CONSTRAINT plugin_messaging_messages_deviceid_fkey FOREIGN KEY (deviceid) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: plugin_push_messages plugin_push_messages_customerid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_push_messages
    ADD CONSTRAINT plugin_push_messages_customerid_fkey FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: plugin_push_messages plugin_push_messages_deviceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_push_messages
    ADD CONSTRAINT plugin_push_messages_deviceid_fkey FOREIGN KEY (deviceid) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: plugin_push_schedule plugin_push_schedule_customerid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.plugin_push_schedule
    ADD CONSTRAINT plugin_push_schedule_customerid_fkey FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: pluginsdisabled pluginsdisabled_customerid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.pluginsdisabled
    ADD CONSTRAINT pluginsdisabled_customerid_fkey FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: pluginsdisabled pluginsdisabled_pluginid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.pluginsdisabled
    ADD CONSTRAINT pluginsdisabled_pluginid_fkey FOREIGN KEY (pluginid) REFERENCES public.plugins(id) ON DELETE CASCADE;


--
-- Name: pushmessages pushmessages_deviceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.pushmessages
    ADD CONSTRAINT pushmessages_deviceid_fkey FOREIGN KEY (deviceid) REFERENCES public.devices(id) ON DELETE CASCADE;


--
-- Name: uploadedfiles uploadedfiles_customerid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.uploadedfiles
    ADD CONSTRAINT uploadedfiles_customerid_fkey FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: userconfigurationaccess userconfigurationaccess_configurationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userconfigurationaccess
    ADD CONSTRAINT userconfigurationaccess_configurationid_fkey FOREIGN KEY (configurationid) REFERENCES public.configurations(id) ON DELETE CASCADE;


--
-- Name: userconfigurationaccess userconfigurationaccess_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userconfigurationaccess
    ADD CONSTRAINT userconfigurationaccess_userid_fkey FOREIGN KEY (userid) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: userdevicegroupsaccess userdevicegroupsaccess_groupid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userdevicegroupsaccess
    ADD CONSTRAINT userdevicegroupsaccess_groupid_fkey FOREIGN KEY (groupid) REFERENCES public.groups(id) ON DELETE CASCADE;


--
-- Name: userdevicegroupsaccess userdevicegroupsaccess_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userdevicegroupsaccess
    ADD CONSTRAINT userdevicegroupsaccess_userid_fkey FOREIGN KEY (userid) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: userhints userhints_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userhints
    ADD CONSTRAINT userhints_userid_fkey FOREIGN KEY (userid) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: userrolepermissions userrolepermissions_permissionid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userrolepermissions
    ADD CONSTRAINT userrolepermissions_permissionid_fkey FOREIGN KEY (permissionid) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- Name: userrolepermissions userrolepermissions_roleid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userrolepermissions
    ADD CONSTRAINT userrolepermissions_roleid_fkey FOREIGN KEY (roleid) REFERENCES public.userroles(id) ON DELETE CASCADE;


--
-- Name: userrolesettings userrolesettings_customerid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userrolesettings
    ADD CONSTRAINT userrolesettings_customerid_fkey FOREIGN KEY (customerid) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: userrolesettings userrolesettings_roleid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.userrolesettings
    ADD CONSTRAINT userrolesettings_roleid_fkey FOREIGN KEY (roleid) REFERENCES public.userroles(id) ON DELETE CASCADE;


--
-- Name: users users_userroleid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hmdm
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_userroleid_fkey FOREIGN KEY (userroleid) REFERENCES public.userroles(id) ON DELETE RESTRICT;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT ALL ON SCHEMA public TO hmdm;


--
-- PostgreSQL database dump complete
--

