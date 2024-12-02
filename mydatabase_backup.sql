--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3
-- Dumped by pg_dump version 16.3

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
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS '';


--
-- Name: Level; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."Level" AS ENUM (
    'ESCOLAR',
    'UNIVERSITARIO',
    'MIXED'
);


ALTER TYPE public."Level" OWNER TO postgres;

--
-- Name: MotionStatus; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."MotionStatus" AS ENUM (
    'ONGOING',
    'FINISHED',
    'SUSPENDED'
);


ALTER TYPE public."MotionStatus" OWNER TO postgres;

--
-- Name: MotionType; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."MotionType" AS ENUM (
    'MODERATED_CAUCUS',
    'UNMODERATED_CAUCUS',
    'CONSULTATION_OF_THE_WHOLE',
    'ROUND_ROBIN',
    'SPEAKERS_LIST',
    'SUSPENSION_OF_THE_MEETING',
    'ADJOURNMENT_OF_THE_MEETING',
    'CLOSURE_OF_DEBATE'
);


ALTER TYPE public."MotionType" OWNER TO postgres;

--
-- Name: Role; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."Role" AS ENUM (
    'DIRECTOR',
    'DIRECTORA',
    'DIRECTOR_ADJUNTO',
    'DIRECTORA_ADJUNTA',
    'MODERADOR',
    'MODERADORA',
    'CRISIS_ROOM'
);


ALTER TYPE public."Role" OWNER TO postgres;

--
-- Name: SessionStatus; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."SessionStatus" AS ENUM (
    'ONGOING',
    'FINISHED',
    'SUSPENDED',
    'SCHEDULED'
);


ALTER TYPE public."SessionStatus" OWNER TO postgres;

--
-- Name: State; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."State" AS ENUM (
    'PRESENTE',
    'AUSENTE',
    'PRESENTE_Y_VOTANDO'
);


ALTER TYPE public."State" OWNER TO postgres;

--
-- Name: get_committee_attendance(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_committee_attendance(p_committee_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    committee_rec RECORD;
    session_rec RECORD;
    attendance_rec RECORD;
    committee_cursor CURSOR FOR
        SELECT id, name, topic, level
        FROM "Committee"
        WHERE id = p_committee_id;
    session_cursor CURSOR FOR
        SELECT id, date, status
        FROM "Session"
        ORDER BY date;
    attendance_cursor CURSOR (p_session_id INT) FOR
        SELECT a.state, d.name AS delegate_name, c.name AS country_name
        FROM "Asistencia" a
        JOIN "Delegate" d ON a."delegateId" = d.id
        JOIN "Country" c ON d."countryId" = c.id
        WHERE d."committeeId" = p_committee_id AND a."sessionId" = p_session_id
        ORDER BY c.name, d.name;
BEGIN
    OPEN committee_cursor;
    FETCH committee_cursor INTO committee_rec;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Committee with ID % not found', p_committee_id;
    END IF;

    RAISE NOTICE 'Committee: % (%) - Level: %', committee_rec.name, committee_rec.topic, committee_rec.level;

    OPEN session_cursor;
    LOOP
        FETCH session_cursor INTO session_rec;
        EXIT WHEN NOT FOUND;

        RAISE NOTICE '  Session Date: %, Status: %',
                     session_rec.date::date,
                     session_rec.status;

        RAISE NOTICE '    Attendance:';
        OPEN attendance_cursor(session_rec.id);
        LOOP
            FETCH attendance_cursor INTO attendance_rec;
            EXIT WHEN NOT FOUND;

            RAISE NOTICE '      - % (%) - Status: %',
                         attendance_rec.delegate_name,
                         attendance_rec.country_name,
                         attendance_rec.state;
        END LOOP;
        CLOSE attendance_cursor;

        RAISE NOTICE '';
    END LOOP;
    CLOSE session_cursor;

    CLOSE committee_cursor;
END;
$$;


ALTER FUNCTION public.get_committee_attendance(p_committee_id integer) OWNER TO postgres;

--
-- Name: get_committee_attendance_summary(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_committee_attendance_summary(p_committee_id integer) RETURNS TABLE(session_date date, session_status text, total_delegates integer, present_count integer, absent_count integer, present_and_voting_count integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    WITH committee_delegates AS (
        SELECT COUNT(*) AS total_delegates
        FROM "Delegate"
        WHERE "committeeId" = p_committee_id
    )
    SELECT
        s.date::DATE AS session_date,
        s.status::TEXT AS session_status,
        cd.total_delegates,
        COUNT(CASE WHEN a.state = 'PRESENTE' THEN 1 END) AS present_count,
        COUNT(CASE WHEN a.state = 'AUSENTE' THEN 1 END) AS absent_count,
        COUNT(CASE WHEN a.state = 'PRESENTE_Y_VOTANDO' THEN 1 END) AS present_and_voting_count
    FROM
        "Session" s
    LEFT JOIN "Asistencia" a ON s.id = a."sessionId"
    LEFT JOIN "Delegate" d ON a."delegateId" = d.id
    CROSS JOIN committee_delegates cd
    WHERE
        d."committeeId" = p_committee_id OR d."committeeId" IS NULL
    GROUP BY
        s.id, s.date, s.status, cd.total_delegates
    ORDER BY
        s.date;
END;
$$;


ALTER FUNCTION public.get_committee_attendance_summary(p_committee_id integer) OWNER TO postgres;

--
-- Name: get_committee_attendance_with_cursors(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_committee_attendance_with_cursors(committee_id integer) RETURNS TABLE(session_id integer, session_date date, presente_count integer, ausente_count integer, presente_y_votando_count integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    session_rec RECORD;
    attendance_rec RECORD;

    session_cursor CURSOR FOR
        SELECT DISTINCT s.id, s.date
        FROM "Session" s
        JOIN "Asistencia" a ON s.id = a."sessionId"
        JOIN "Delegate" d ON a."delegateId" = d.id
        WHERE d."committeeId" = committee_id;

    attendance_cursor CURSOR (v_session_id INT) FOR
        SELECT a.state, COUNT(*) AS state_count
        FROM "Asistencia" a
        JOIN "Delegate" d ON a."delegateId" = d.id
        WHERE a."sessionId" = v_session_id
        AND d."committeeId" = committee_id
        GROUP BY a.state;

BEGIN
    presente_count := 0;
    ausente_count := 0;
    presente_y_votando_count := 0;

    OPEN session_cursor;
    LOOP
        FETCH session_cursor INTO session_rec;
        EXIT WHEN NOT FOUND;

        -- Reset counts for each session
        presente_count := 0;
        ausente_count := 0;
        presente_y_votando_count := 0;

        OPEN attendance_cursor(session_rec.id);
        LOOP
            FETCH attendance_cursor INTO attendance_rec;
            EXIT WHEN NOT FOUND;

            CASE attendance_rec.state
                WHEN 'PRESENTE' THEN presente_count := attendance_rec.state_count;
                WHEN 'AUSENTE' THEN ausente_count := attendance_rec.state_count;
                WHEN 'PRESENTE_Y_VOTANDO' THEN presente_y_votando_count := attendance_rec.state_count;
            END CASE;
        END LOOP;
        CLOSE attendance_cursor;

        session_id := session_rec.id;
        session_date := session_rec.date;

        RETURN NEXT;
    END LOOP;
    CLOSE session_cursor;
END;
$$;


ALTER FUNCTION public.get_committee_attendance_with_cursors(committee_id integer) OWNER TO postgres;

--
-- Name: get_delegate_attendance_summary(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_delegate_attendance_summary(p_session_id integer) RETURNS TABLE(delegate_name text, delegate_id text, attendance_state public."State")
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        D.name AS delegate_name,
        A."delegateId" AS delegate_id,
        A.state AS attendance_state
    FROM
        "Asistencia" A
    JOIN
        "Delegate" D ON A."delegateId" = D.id
    WHERE
        A."sessionId" = p_session_id;
END;
$$;


ALTER FUNCTION public.get_delegate_attendance_summary(p_session_id integer) OWNER TO postgres;

--
-- Name: has_ongoing_session(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.has_ongoing_session(p_committee_id integer) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT EXISTS(
    SELECT 1
    FROM "Session" s
    JOIN "Committee" c ON s.id = c.id
    WHERE c.id = p_committee_id AND s.status = 'ONGOING'
  );
$$;


ALTER FUNCTION public.has_ongoing_session(p_committee_id integer) OWNER TO postgres;

--
-- Name: prevent_delegate_participation_in_overlapping_sessions(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.prevent_delegate_participation_in_overlapping_sessions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    overlapping_session RECORD;
BEGIN
    SELECT * INTO overlapping_session
    FROM "Asistencia" a
    JOIN "Session" s ON a."sessionId" = s.id
    WHERE a."delegateId" = NEW.delegateId AND
          (s."startTime", s."endTime") OVERLAPS (NEW.session->>s."startTime", NEW.session->>"s"."endTime")
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION 'Delegate cannot participate in overlapping sessions';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.prevent_delegate_participation_in_overlapping_sessions() OWNER TO postgres;

--
-- Name: set_default_start_time_for_session(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_default_start_time_for_session() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW."startTime" IS NULL THEN
        NEW."startTime" = NOW();
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_default_start_time_for_session() OWNER TO postgres;

--
-- Name: sp_close_motion(character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_close_motion(IN p_motion_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE "Motion"
    SET
       "createdAt" = NOW()
    WHERE id = p_motion_id;

    UPDATE "PassedMotion"
    SET status = 'FINISHED'
    WHERE "motionId" = p_motion_id;
END;
$$;


ALTER PROCEDURE public.sp_close_motion(IN p_motion_id character varying) OWNER TO postgres;

--
-- Name: sp_record_delegate_participation(character varying, character varying, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_record_delegate_participation(IN p_passed_motion_id character varying, IN p_delegate_id character varying, IN p_time_used integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO "PassedMotionDelegate" ("id", "passedMotionId", "delegateId", "timeUsed")
    VALUES (gen_random_uuid(), p_passed_motion_id, p_delegate_id, p_time_used)
    ON CONFLICT ("passedMotionId", "delegateId") DO UPDATE SET "timeUsed" = EXCLUDED."timeUsed";
END;
$$;


ALTER PROCEDURE public.sp_record_delegate_participation(IN p_passed_motion_id character varying, IN p_delegate_id character varying, IN p_time_used integer) OWNER TO postgres;

--
-- Name: sp_register_delegate_attendance(character varying, integer, public."State"); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_register_delegate_attendance(IN p_delegate_id character varying, IN p_session_id integer, IN p_state public."State")
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO "Asistencia" ("delegateId", "sessionId", state)
    VALUES (p_delegate_id, p_session_id, p_state)
    ON CONFLICT ("delegateId", "sessionId") DO UPDATE SET state = EXCLUDED.state;
END;
$$;


ALTER PROCEDURE public.sp_register_delegate_attendance(IN p_delegate_id character varying, IN p_session_id integer, IN p_state public."State") OWNER TO postgres;

--
-- Name: sp_update_session_status(integer, public."SessionStatus"); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_update_session_status(IN p_session_id integer, IN p_new_status public."SessionStatus")
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE "Session"
    SET status = p_new_status
    WHERE id = p_session_id;
END;
$$;


ALTER PROCEDURE public.sp_update_session_status(IN p_session_id integer, IN p_new_status public."SessionStatus") OWNER TO postgres;

--
-- Name: total_time_used_in_motion(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.total_time_used_in_motion(p_motion_id text) RETURNS text
    LANGUAGE sql
    AS $$
  SELECT
    CONCAT(
      FLOOR(COALESCE(SUM("timeUsed"), 0) / 60),
      ' minutes ',
      COALESCE(SUM("timeUsed"), 0) % 60,
      ' seconds'
    )
  FROM "PassedMotionDelegate"
  WHERE "passedMotionId" = p_motion_id;
$$;


ALTER FUNCTION public.total_time_used_in_motion(p_motion_id text) OWNER TO postgres;

--
-- Name: update_motion_in_favor_votes_on_delegate_participation(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_motion_in_favor_votes_on_delegate_participation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.timeUsed > 0 THEN
        UPDATE "Motion"
        SET "inFavorVotes" = "inFavorVotes" + 1
        WHERE id = (SELECT "motionId" FROM "PassedMotion" WHERE id = NEW.passedMotionId);
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_motion_in_favor_votes_on_delegate_participation() OWNER TO postgres;

--
-- Name: update_passed_motion_status_on_delegate_update(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_passed_motion_status_on_delegate_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    all_delegates_have_spoken BOOLEAN;
BEGIN
    SELECT TRUE INTO all_delegates_have_spoken
    FROM "PassedMotion" pm
    JOIN "PassedMotionDelegate" pmd ON pm.id = pmd."passedMotionId"
    WHERE pm.id = NEW.passedMotionId
    GROUP BY pm.id
    HAVING SUM(CASE WHEN pmd."timeUsed" > 0 THEN 1 ELSE 0 END) = COUNT(*);

    IF all_delegates_have_spoken THEN
        UPDATE "PassedMotion" SET status = 'FINISHED' WHERE id = NEW.passedMotionId;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_passed_motion_status_on_delegate_update() OWNER TO postgres;

--
-- Name: update_session_status_on_end_time_update(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_session_status_on_end_time_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW."endTime" IS NOT NULL AND OLD."endTime" IS NULL THEN
        UPDATE "Session" SET status = 'FINISHED' WHERE id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_session_status_on_end_time_update() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: Asistencia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Asistencia" (
    id integer NOT NULL,
    "delegateId" text NOT NULL,
    "sessionId" integer NOT NULL,
    state public."State" NOT NULL
);


ALTER TABLE public."Asistencia" OWNER TO postgres;

--
-- Name: Asistencia_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Asistencia_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Asistencia_id_seq" OWNER TO postgres;

--
-- Name: Asistencia_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Asistencia_id_seq" OWNED BY public."Asistencia".id;


--
-- Name: Chair; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Chair" (
    id text NOT NULL,
    name text NOT NULL,
    "clerkId" text,
    email text,
    role public."Role" NOT NULL,
    "committeeId" integer NOT NULL
);


ALTER TABLE public."Chair" OWNER TO postgres;

--
-- Name: Committee; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Committee" (
    id integer NOT NULL,
    name text NOT NULL,
    topic text NOT NULL,
    level public."Level" NOT NULL
);


ALTER TABLE public."Committee" OWNER TO postgres;

--
-- Name: Committee_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Committee_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Committee_id_seq" OWNER TO postgres;

--
-- Name: Committee_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Committee_id_seq" OWNED BY public."Committee".id;


--
-- Name: Country; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Country" (
    id integer NOT NULL,
    name text NOT NULL,
    emoji text
);


ALTER TABLE public."Country" OWNER TO postgres;

--
-- Name: Country_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Country_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Country_id_seq" OWNER TO postgres;

--
-- Name: Country_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Country_id_seq" OWNED BY public."Country".id;


--
-- Name: Delegate; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Delegate" (
    id text NOT NULL,
    name text NOT NULL,
    "countryId" integer NOT NULL,
    "committeeId" integer NOT NULL
);


ALTER TABLE public."Delegate" OWNER TO postgres;

--
-- Name: Motion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Motion" (
    id text NOT NULL,
    type public."MotionType" NOT NULL,
    topic text,
    "totalTime" integer NOT NULL,
    "timePerDelegate" integer,
    "maxDelegates" integer,
    "proposedBy" text NOT NULL,
    "committeeId" integer NOT NULL,
    "sessionId" integer NOT NULL,
    "inFavorVotes" integer DEFAULT 0 NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."Motion" OWNER TO postgres;

--
-- Name: PassedMotion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."PassedMotion" (
    id text NOT NULL,
    "motionId" text NOT NULL,
    "startTime" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status public."MotionStatus" DEFAULT 'ONGOING'::public."MotionStatus" NOT NULL
);


ALTER TABLE public."PassedMotion" OWNER TO postgres;

--
-- Name: PassedMotionDelegate; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."PassedMotionDelegate" (
    id text NOT NULL,
    "passedMotionId" text NOT NULL,
    "delegateId" text NOT NULL,
    "speakingOrder" integer,
    "timeUsed" integer DEFAULT 0 NOT NULL,
    notes text
);


ALTER TABLE public."PassedMotionDelegate" OWNER TO postgres;

--
-- Name: Session; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Session" (
    id integer NOT NULL,
    date timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "startTime" timestamp(3) without time zone NOT NULL,
    "endTime" timestamp(3) without time zone,
    status public."SessionStatus" DEFAULT 'ONGOING'::public."SessionStatus" NOT NULL
);


ALTER TABLE public."Session" OWNER TO postgres;

--
-- Name: Session_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Session_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Session_id_seq" OWNER TO postgres;

--
-- Name: Session_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Session_id_seq" OWNED BY public."Session".id;


--
-- Name: _prisma_migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public._prisma_migrations (
    id character varying(36) NOT NULL,
    checksum character varying(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name character varying(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL
);


ALTER TABLE public._prisma_migrations OWNER TO postgres;

--
-- Name: Asistencia id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Asistencia" ALTER COLUMN id SET DEFAULT nextval('public."Asistencia_id_seq"'::regclass);


--
-- Name: Committee id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Committee" ALTER COLUMN id SET DEFAULT nextval('public."Committee_id_seq"'::regclass);


--
-- Name: Country id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Country" ALTER COLUMN id SET DEFAULT nextval('public."Country_id_seq"'::regclass);


--
-- Name: Session id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Session" ALTER COLUMN id SET DEFAULT nextval('public."Session_id_seq"'::regclass);


--
-- Data for Name: Asistencia; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Asistencia" (id, "delegateId", "sessionId", state) FROM stdin;
968	a64bd9c2-1a10-43e2-b23c-be82da628831	1	AUSENTE
969	b9f94155-2d85-442b-9dc1-da3c5484d691	1	AUSENTE
970	3556ba36-a58f-4e87-aeff-be2782fc5895	1	AUSENTE
971	0784e1f4-d0d9-40b9-ba44-689c9a51561a	1	AUSENTE
972	45e84a4e-c279-482e-8a42-7557ba7d96aa	1	AUSENTE
973	b6ca26bb-a565-4d15-b991-6e9e7721a021	1	AUSENTE
974	4414bcce-42ea-425b-9fa6-bfb93f2394d4	1	AUSENTE
975	d20deb4d-d04f-498c-9d33-e605fb58283a	1	AUSENTE
976	83b6259b-0404-4d7a-b8c8-0a4f7bd136d1	1	AUSENTE
977	97fad8f3-e410-4349-83aa-f724690c6bf2	1	AUSENTE
978	b85b8b21-b3b8-4701-8eab-b2469eacaa2a	1	AUSENTE
979	201946ce-e6c3-447c-9d99-6f373187db7f	1	AUSENTE
980	2e40e141-c4b0-42c2-a39f-a77e884d4c33	1	AUSENTE
981	a4dbcbd1-a37b-4600-87c8-e8b4fcfd1643	1	AUSENTE
982	0e948cea-63d9-4390-94d6-39f528214bd8	1	AUSENTE
983	fa1a2ad6-e65f-42c5-a816-f0730626b9ea	1	AUSENTE
984	8b474ce9-870b-4f59-828f-fa70123b85ce	1	AUSENTE
985	ffe81a03-0dad-4a02-a9da-5cd4dc0d7d13	1	AUSENTE
986	16eb4c87-996c-495d-b67d-25c0785d9409	1	AUSENTE
987	f8b44da0-7297-405a-a1c8-1ec82a118437	1	AUSENTE
988	00f4e974-7f9c-4349-9cef-ca2048d54aef	1	AUSENTE
990	7fb2f5c1-8e67-48e4-854d-aea1b4d27864	1	PRESENTE
\.


--
-- Data for Name: Chair; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Chair" (id, name, "clerkId", email, role, "committeeId") FROM stdin;
cm32cy15n0001uf34yyvumo1d	Patrick Andres Ramirez Santos	user_2oLseZSSjsQoPtfLuqlY0jWppQb	pramirezs@ulasalle.edu.pe	DIRECTOR	3
c13e206b-abb3-4b1e-8a59-ccc165d2a0ea	SILVIO SOLORZANO	\N	\N	DIRECTOR	1
930c44be-9b6e-41bc-85d7-43a3325f1d27	ZAFIRO ZAPANA	\N	\N	DIRECTORA_ADJUNTA	1
d01b5fbb-acec-4134-ab8b-84af92bb43ca	DIANA MAMANI	\N	\N	MODERADORA	1
9c95d1c6-312e-4235-987e-6479171763c7	ALVARO TAPIA	\N	\N	DIRECTOR	2
0f29955f-575a-4f55-91a6-a21e57faacde	DANIELA ENDO	\N	\N	DIRECTORA_ADJUNTA	2
e605ac58-f96a-4cd9-8d11-ff40c3d5d607	SAID SALAS	\N	\N	MODERADOR	2
0f3efcad-6a44-4a6e-9459-9e60ef5eccd5	MARCELO CARPIO	\N	\N	DIRECTOR	3
5c704154-ffa0-4f92-99b1-33147da81060	MARCELLO RODRIGUEZ	\N	\N	DIRECTOR_ADJUNTO	3
516fa0e0-142a-4936-8ff0-f5fae9d0091f	BRUNO RODRIGUEZ	\N	\N	MODERADOR	3
3b86d210-28d6-4b84-ae14-9a989fd4e36c	ALEJANDRA ESCOBEDO	\N	\N	DIRECTORA_ADJUNTA	4
8ea85266-3525-4edf-b150-004693461d23	LIZBETH LAROTA	\N	\N	DIRECTORA_ADJUNTA	4
ecbdef5c-48d4-432c-a984-6c9607733d80	JESSICA HUARCA	\N	\N	MODERADORA	4
91d3a1c1-c340-4f19-9466-a7248fe59a58	GABRIELA VARGAS	\N	\N	DIRECTORA	5
e0679ed5-5e50-4a63-84c9-455924c517a6	GABRIEL BACA	\N	\N	DIRECTOR_ADJUNTO	5
d9a5f3e4-8606-41a4-9145-5f9dbeea1d5f	JULIO BARREDA	\N	\N	MODERADOR	5
464f0599-6611-45d2-aa60-9a08d78cb614	SHARON SOLIS	\N	\N	DIRECTORA	6
fcc40960-bb03-47e2-95c5-b2c5190669da	MASSIEL FARFAN	\N	\N	DIRECTORA_ADJUNTA	6
c747db01-309c-45f2-9a7e-df813ad342c1	ALEXIA PAZ	\N	\N	MODERADORA	6
530ab5c5-bd55-4ec1-a6fd-06ddb770a3f8	ALEJANDRO SANCHEZ	\N	\N	DIRECTOR	7
84392ffd-086d-4cca-8e2c-2e9632ee079b	VALERIA MOROTE	\N	\N	DIRECTORA_ADJUNTA	7
84fb4de7-1438-440b-a8ef-ce02ce2ba3da	ALFREDO ESCAJADILLO	\N	\N	MODERADOR	7
0525c844-e0ce-4b8e-8984-03284d9df1bc	SOPHIA VALDIVIA	\N	\N	DIRECTORA	8
37576783-973d-4566-ae3d-0650ea8c53cf	GABRIEL CHAVEZ	\N	\N	DIRECTOR_ADJUNTO	8
3daa2d51-fcc6-4b7e-a7db-fb64251b77a6	JOSUE RODRIGUEZ	\N	\N	MODERADOR	8
7878b8d3-9da0-40f2-9340-6c80a8ba929f	FABIAN GALDOS	\N	\N	DIRECTOR	9
cc5566f6-f7c7-4d6c-9430-e1fb68072c60	VALERIA VILLAROEL	\N	\N	DIRECTORA_ADJUNTA	9
73312f9c-594c-4759-8555-2e3f7d57c1e9	ALESSA SOZA	\N	\N	MODERADORA	9
e36c8d52-6ba2-4a44-ae8d-ef2a51173cb5	IGNACIO TEJADA	\N	\N	DIRECTOR	10
ca9bc7b2-de0d-435f-9d9e-6cee8e65b2b2	MACARENA POLO	\N	\N	DIRECTORA_ADJUNTA	10
5f245f38-6f60-48b2-9a21-c44b05e4b39c	RODRIGO LLERENA	\N	\N	MODERADOR	10
52516797-1b42-4259-b85f-2a44f0c51c72	JOAQUIN ZARATE	\N	\N	DIRECTOR	11
44db4d35-4f8a-40a8-9216-91e418d8ed60	RODRIGO CARPIO	\N	\N	DIRECTOR_ADJUNTO	11
06797aec-5890-4988-b84f-83d591bc30a0	DIEGO CUETO	\N	\N	MODERADOR	11
\.


--
-- Data for Name: Committee; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Committee" (id, name, topic, level) FROM stdin;
1	TEST	Secretariado de prueba	MIXED
2	ACNUR	Acceso equitativo en la atención médica y tratamiento del enfermedades controladas de refugiados en situaciones de desplazamiento	ESCOLAR
3	CONSEJO DE SEGURIDAD	La situación en Haití	ESCOLAR
4	DISEC	La utilización del espacio ultra terrestre; gestión de desastres espaciales y prevención ante el manejo de los desechos espaciales	ESCOLAR
5	ONU MUJERES	El desarrollo de los derechos civiles, sociales y políticos de las mujeres con diversidades funcionales	ESCOLAR
6	OMS	El estigma de la crisis de salud mental en la población joven económicamente activa en los paises de Asia	ESCOLAR
7	OIEA	Gestión en el proceso de transición energética sostenible	ESCOLAR
8	AFRICAN UNION	Neocolonial Legacy	ESCOLAR
9	UNODC	Impacto del Crimen Organizado y el Lavado de  activos como financiación del terrorismo transnacional	ESCOLAR
10	FIFA	Relaciones entre Barras Bravas y Grupos Delictivos; perspectivas de sanción administrativa ante los equipos deportivos, Controversias en la elección de sedes de torneos: criterios de selección y su impacto en el desarrollo regional	ESCOLAR
11	NAC	La situación de Bosnia y Herzegovina de 1995	ESCOLAR
12	OEA	Salvador Allende, pronóstico de un golpe organizado	ESCOLAR
13	CRISIS HISTÓRICA FRANCIA	Guerras Napoleónicas, el imperio francés	ESCOLAR
14	CRISIS HISTÓRICA EUROPA	Guerras Napoleónicas, Europa	ESCOLAR
15	CRISIS FUTURISTA	Desastre post apocalíptico; un panorama a partir de la saga de Fallout	ESCOLAR
16	CRISIS FANTÁSTICA	El comienzo de una leyenda, ARCANE	ESCOLAR
17	SOCHUM	Religious discrimination and freedom of worship: protecting the rights of religious minorities	ESCOLAR
18	UNESCO	Protección integral de la Libertad de Expresión y los Periodistas en zonas de exclusión y conflictos armados	UNIVERSITARIO
19	CCPCJ	Revisión del marco legal ante la represión policial frente a las manifestaciones políticas	UNIVERSITARIO
20	CDH	Crímenes de Lesa Humanidad en conflictos políticos en América Latina	UNIVERSITARIO
21	UNICEF	Programs for protecting families in poverty: prevention of abandonment and support for home stability	UNIVERSITARIO
22	PRENSA		UNIVERSITARIO
23	CRISIS HISTÓRICA	El horizonte de un sueño roto dada en 1963: La tragedia de Dallas	UNIVERSITARIO
24	ASAMBLEA GENERAL	Rasgos punitivos como parte de la soberania nacional, en aplicación del control social y relaciones exteriores.	MIXED
\.


--
-- Data for Name: Country; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Country" (id, name, emoji) FROM stdin;
1	CHROSS	\N
2	FEDERACION DE FUTBOL DE IRLANDA DEL NORTE	🇬🇧
3	FEDERACION ALEMANA DE FUTBOL	🇩🇪
4	SUDÁN	🇸🇩
5	PORTUGAL	🇵🇹
6	BELARUS	🇧🇾
7	VIETNAM	🇻🇳
8	DINAMARCA	🇩🇰
9	AL JAZEERA	\N
10	COSTA RICA	🇨🇷
11	FEDERACION PERÚANA DE FUTBOL	🇵🇪
12	RUMANIA	🇷🇴
13	AFGANISTAN	🇦🇫
14	JAPAN	🇯🇵
15	CENTRAL AFRICAN REPUBLIC	🇨🇫
16	EMIRATOS ARABES UNIDOS	🇦🇪
17	MAURITANIA	🇲🇷
18	LE MONDE	\N
19	FEDERACION PANAMEÑA DE FUTBOL	🇵🇦
20	GERAUD DUROC	\N
21	GOBERNADOR DE LA COMMONWEALTH DE CUATRO ESTADOS	\N
22	RUANDA	🇷🇼
23	SUECIA	🇸🇪
24	AUGUSTE DE MARMONT	\N
25	FEDERACION DE FUTBOL DE ARABIA SAUDI	🇸🇦
26	IRAQ	🇮🇶
27	ASOCIACION DEL FUTBOL ARGENTINO	🇦🇷
28	CUBA	🇨🇺
29	NUEVA ZELANDA	🇳🇿
30	ARMENIA	🇦🇲
31	MARILYN MONROE	\N
32	CAMERÚN	🇨🇲
33	FERNANDO CARLOS JOSE DE AUSTRIA-ESTE	\N
34	TAILANDIA	🇹🇭
35	TRINIDAD Y TOBAGO	🇹🇹
36	REPUBLICA DE COREA	🇰🇷
37	FEDERACION INDIA DE FUTBOL	🇮🇳
38	J. EDGAR HOOVER	\N
39	FEDERACION ISRAELI DE FUTBOL	🇮🇱
40	CHARLES MAURICE DE TALLEYRAND	\N
41	ESTADOS UNIDOS	🇺🇸
42	THE NATION	\N
43	GOBERNADOR DE LA COMMONWEALTH DEL NORTE	\N
44	CONSEJERO DE SEGURIDAD NACIONAL DE LOS ESTADOS UNIDOS	\N
45	PANAMÁ	🇵🇦
46	CONFEDERACION BRASILEÑA DE FUTBOL	🇧🇷
47	PAPA PIO VII	\N
48	SHOOLA	\N
49	NEPAL	🇳🇵
50	FEDERACION FRANCESA DE FUTBOL	🇫🇷
51	TUNEZ	🇹🇳
52	GEORGES LEOPOLD CHRETIEN FREDERIC DAGOBERT CUVIER	\N
53	SAN VICENTE Y LAS GRANADINAS	🇻🇨
54	FINN	\N
55	KAZAJISTAN	🇰🇿
56	SUDÁN DEL SUR	🇸🇸
57	JUAN VI DE PORTUGAL	\N
58	MIKHAIL KUTUZOV	\N
59	SILCO	\N
60	FEDERICO GUILLERMO III	\N
61	SECRETARIO DE ESTADO DE LOS ESTADOS UNIDOS	\N
62	UNITED KINGDOM	🇬🇧
63	MÉXICO	🇲🇽
64	ZAMBIA	🇿🇲
65	ANGOLA	🇦🇴
66	FEDERACION CANADIENSE DE FUTBOL	🇨🇦
67	SALO	\N
68	SOUTH AFRICA	🇿🇦
69	AMBESSA MEDARDA	\N
70	FEDERACION CHINA DE FUTBOL	🇨🇳
71	FEDERACION JAPÓNESA DE FUTBOL	🇯🇵
72	VIKTOR	\N
73	ARABIA SAUDITA	🇸🇦
74	SOUTH CHINA MORNING POST	\N
75	POLONIA	🇵🇱
76	FRANCISCO II DEL SACRO IMPERIO ROMANO GERMANICO Y I DE AUSTRIA	\N
77	ELIZABETH TAYLOR	\N
78	ANDRE MASSENA	\N
79	SOUTH KOREA	🇰🇷
80	PERÚ	🇵🇪
81	MOZAMBIQUE	🇲🇿
82	JOSEPH FOCUHE	\N
83	PRINCIPE FEDERICO LUIS DE HOHENLOHE-INGELFINGEN	\N
84	MARIA LUISA DE AUSTRIA	\N
85	MARRUECOS	🇲🇦
86	FRANCE	🇫🇷
87	INDIA	🇮🇳
88	FEDERACION EGIPCIA DE FUTBOL	🇪🇬
89	BANGLADESH	🇧🇩
90	SECRETARIO DE DEFENSA DE LOS ESTADOS UNIDOS	\N
91	DEMOCRATIC REPUBLIC OF CONGO	🇨🇩
92	JAPAN TIMES	\N
93	AUTRALIA	🇦🇺
94	FEDERACION BOLIVIANA DE FUTBOL	🇧🇴
95	SINGAPUR	🇸🇬
96	AUSTRIA	🇦🇹
97	PATRIARCA GREGORIO V DE CONSTANTINOPLA	\N
98	FEDERACION COREANA DE FUTBOL	🇰🇷
99	IRAK	🇮🇶
100	REPRESENTANTE DE POSEIDON ENERGY	\N
101	EL UNIVERSO	\N
102	CARL VON CLAUSEWITZ	\N
103	EL COMERCIO	\N
104	PARAGUAY	🇵🇾
105	BULGARIA	🇧🇬
106	GERMANY	🇩🇪
107	ROBERT MCNAMARA	\N
108	EKKO	\N
109	GOBERNADOR DE LA COMMONWEALTH DE COLUMBIA	\N
110	SUDAFRICA	🇿🇦
111	CHINA	🇨🇳
112	ROBERT F. KENNEDY	\N
113	ZERI	\N
114	GRECIA	🇬🇷
115	PAKISTAN	🇵🇰
116	REPUBLICA CHECA	🇨🇿
117	ARTHUR WELLESLEY	\N
118	GOBERNADOR DE LA COMMONWEALTH DEL CENTRO ESTE	\N
119	HAITI	🇭🇹
120	BAHRAIN	🇧🇭
121	CHARLES-EDOUARD DE MONTHOLON	\N
122	NICARAGUA	🇳🇮
123	FINLANDIA	🇫🇮
124	FEDERACION COSTARRICENSE DE FUTBOL	🇨🇷
125	FEDERACION COLOMBIANA DE FUTBOL	🇨🇴
126	EURO NEWS	\N
127	ETIOPÍA	🇪🇹
128	HONDURAS	🇭🇳
129	JAMAICA	🇯🇲
130	SUIZA	🇨🇭
131	CHILE	🇨🇱
132	FEDERACION DE FUTBOL DE ANTIGUA Y BARBUDA	🇦🇬
133	UCRANIA	🇺🇦
134	MONGOLIA	🇲🇳
135	FEDERACION ITALIANA DE FUTBOL	🇮🇹
136	GEORGE WALLACE	\N
137	REINO UNIDO	🇬🇧
138	VI	\N
139	SECRETARIO DE SALUD Y SERVICIOS HUMANOS	\N
140	CAITLYN KIRAMMAN	\N
141	LETONIA	🇱🇻
142	MALASIA	🇲🇾
143	REPRESENTANTE DE BIG MT RESEARCH AND DEVELOPMENT CENTER	\N
144	MIKHAIL BARCLAY DE TOLLY	\N
145	FEDERACION PAKISTANI DE FUTBOL	🇵🇰
146	FEDERACION FINLANDESA DE FUTBOL	🇫🇮
147	JEROME BONAPARTE	\N
148	ECUADOR	🇪🇨
149	SEVIKA	\N
150	BURUNDI	🇧🇮
151	ETIENNE JACQUES JOSEPH MACDONALD	\N
152	GOBERNADOR DE LA COMMONWEALTH DEL SURESTE	\N
153	IRLANDA	🇮🇪
154	BURKINA FASO	🇧🇫
155	GEORGE MCGOVERN	\N
156	COREA DEL SUR	🇰🇷
157	BRASIL	🇧🇷
158	ITALIA	🇮🇹
159	FEDERACION MEXICANA DE FUTBOL ASOCIACION A. C.	🇲🇽
160	FEDERACION GRIEGA DE FUTBOL	🇬🇷
161	FILIPINAS	🇵🇭
162	LYNDON B. JOHNSON	\N
163	COSTA DE MARFIL	🇨🇮
164	CONGO	🇨🇬
165	BARBADOS	🇧🇧
166	RWANDA	🇷🇼
167	RENNI	\N
168	URUGUAY	🇺🇾
169	HORATIO NELSON	\N
170	BOLBOK	\N
171	GOBERNADOR DE LA COMMONWEALTH DEL MEDIO OESTE	\N
172	HUCK	\N
173	NAMIBIA	🇳🇦
174	FEDERACION INGLESA DE FUTBOL	🏴󠁧󠁢󠁥󠁮󠁧󠁿
175	JOHN F. KENNEDY	\N
176	REPUBLICA DEMOCRÁTICA DEL CONGO	🇨🇩
177	QATAR	🇶🇦
178	LOUIS ALEXANDRE BERTHIER	\N
179	CAMEROON	🇨🇲
180	CHAD	🇹🇩
181	ARGENTINA	🇦🇷
182	EL SALVADOR	🇸🇻
183	FEDERACION NEERLANDESA DE FUTBOL	🇳🇱
184	PUERTO RICO	🇵🇷
185	VENEZUELA	🇻🇪
186	GOBERNADOR DE LA COMMONWEALTH DE LAS LLANURAS	\N
187	PAISES BAJOS	🇳🇱
188	JOHN CONNALLY	\N
189	NORUEGA	🇳🇴
190	TOGO	🇹🇬
191	KUWAIT	🇰🇼
192	SMEECH	\N
193	MARCUS	\N
194	IBRAHIM BEY	\N
195	REPRESENTANTE DE ROBCO INDUSTRIES	\N
196	YEMEN	🇾🇪
197	ROY WILKINS	\N
198	FEDERACION DE FUTBOL DE EMIRATOS ARABES UNIDOS	🇦🇪
199	ISRAEL	🇮🇱
200	GOBERNADOR DE LA COMMONWEALTH DE NUEVA INGLATERRA	\N
201	MARTIN LUTHER KING JR.	\N
202	BIRMANIA	🇲🇲
203	INDONESIA	🇮🇩
204	SOMALIA	🇸🇴
205	MURAD BEY	\N
206	BABETTE	\N
207	RUSIA	🇷🇺
208	JOSEFINA DE BEAUHARNAIS	\N
209	NIGERIA	🇳🇬
210	SAUDI ARABIA	🇸🇦
211	DIRECTOR DE LA CIA	\N
212	JORGE III DEL REINO UNIDO	\N
213	JAPÓN	🇯🇵
214	FRANCIA	🇫🇷
215	CABO VERDE	🇨🇻
216	MARGOT	\N
217	SENEGAL	🇸🇳
218	JORDANIA	🇯🇴
219	ALEMANIA	🇩🇪
220	AUSTRALIA	🇦🇺
221	THE NEW YORK TIMES	\N
222	BÉLGICA	🇧🇪
223	RUSSIA	🇷🇺
224	FEDERACION DE FUTBOL DE GHANA	🇬🇭
225	EUGENE DE BEUHARNAIS	\N
226	GEBHARD LEBERECHT VON BLUCHER	\N
227	PALESTINA	🇵🇸
228	COLOMBIA	🇨🇴
229	TURQUÍA	🇹🇷
230	IRAN	🇮🇷
231	GUATEMALA	🇬🇹
232	PIOTR IVANOVICH BAGRATION	\N
233	JOACHIM MURAT	\N
234	EL MERCURIO	\N
235	GOBERNADOR DE LA COMMONWEALTH DEL GOLFO	\N
236	RENATA GLASC	\N
237	ALEJANDRO I DE RUSIA	\N
238	GOBERNADOR DE LA COMMONWEALTH DEL ESTE	\N
239	UNITED STATES	🇺🇸
240	JEAN DE DIEU SOULT	\N
241	BRAZIL	🇧🇷
242	EL PAIS	\N
243	REAL FEDERACION ESPAÑOLA DE FUTBOL	🇪🇸
244	JAYCE TALIS	\N
245	REUTERS	\N
246	GHANA	🇬🇭
247	FEDERACION DE FUTBOL DE CHILE	🇨🇱
248	CUTHBERT COLLINGWOOD	\N
249	AVA GARDNER	\N
250	REPRESENTANTE DE VAULT-TEC CORPORATION	\N
251	SKY YOUNG	\N
252	GOBERNADOR DE LA COMMONWEALTH DEL SUROESTE	\N
253	CNN	\N
254	REPUBLICA DOMINICANA	🇩🇴
255	MALTA	🇲🇹
256	FEDERACION IRAQUI DE FUTBOL	🇮🇶
257	NAPOLEON BONAPARTE	\N
258	LA VANGUARDIA	\N
259	LUIS-NAPOLEON BONAPARTE	\N
260	PALESTINE	🇵🇸
261	NIGER	🇳🇪
262	SECRETARIO DE ENERGIA DE LOS ESTADOS UNIDOS	\N
263	LA REPUBLICA	\N
264	HOSKEL	\N
265	KENIA	🇰🇪
266	FEDERACION AUSTRIACA DE FUTBOL	🇦🇹
267	BOLIVIA	🇧🇴
268	ARGELIA	🇩🇿
269	JINX (POWDER)	\N
270	LIBANO	🇱🇧
271	JOSEPH-NAPOLEON BONAPARTE	\N
272	REPRESENTANTE DE REPCONN AEROSPACE	\N
273	UNITED ARAB EMIRATES	🇦🇪
274	MICHEL NEY	\N
275	LUXEMBURGO	🇱🇺
276	BBC	\N
277	LIBIA	🇱🇾
278	FEDERACION NORUEGA DE FUTBOL	🇳🇴
279	SIERRA LEONA	🇸🇱
280	ARTHUR GOLDBERG	\N
281	HUBERT HUMPHREY	\N
282	SRI LANKA	🇱🇰
283	ESLOVENIA	🇸🇮
284	JACQUELINE KENNEDY	\N
285	THE WASHINGTON POST	\N
286	FEDERACION ESTADOUNIDENSE DE FUTBOL	🇺🇸
287	FERNANDO VII	\N
288	REPRESENTANTE DE WEST TEK CORPORATION	\N
289	FEDERACION RUSA DE FUTBOL	🇷🇺
290	LOUIS ANTOINE DE BOURBON	\N
291	JEAN BAPTISTE BERNADOTTE	\N
292	SINGED	\N
293	JEAN LANNES	\N
294	CANADÁ	🇨🇦
295	SIRIA	🇸🇾
296	ESPAÑA	🇪🇸
297	EGIPTO	🇪🇬
298	CHINA DAILY	\N
\.


--
-- Data for Name: Delegate; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Delegate" (id, name, "countryId", "committeeId") FROM stdin;
7fb2f5c1-8e67-48e4-854d-aea1b4d27864	jean pierre AROQUIPA	1	16
6b71355e-3f57-421a-aedc-159729455587	Franco Santos	2	10
ffd1284c-6e93-417f-a64b-5ddc3ba41821	Facundo Cárdenas	3	10
220553b1-0e28-4878-aebc-5b396b856234	Christian Hinojosa	4	20
0b7cfb3e-fc6b-40d2-993e-e1a0bcc2edfb	GABRIELA MENDOZA	5	11
a09d4531-2de3-429f-a316-d2f61f84289b	AYLIN MERMA	6	5
42555247-d625-45ec-84d9-8305ccbf052a	Jean Wagner	7	6
dd93f3bd-f43e-4996-bec0-b302de2c34da	Pierina Méndez	7	4
c2b7301d-ac6e-4ba6-a2ff-db991f573972	Nathaly Valdivia	8	6
aba7febd-178e-40fc-bce9-3d9ad9762af7	Romina Rodríguez	8	7
ea49c38e-cfd1-4be7-9126-1f433bd56935	Mario Vilca	8	11
8ffd83e7-a2b2-4958-9e89-20d4d098c6fb	Eduardo Peña	8	24
9e6dbda2-8875-41ff-bb19-6641de0c88fb	Joaquín RODRÍGUEZ	9	22
05dae633-44e0-4682-986e-2d3a1af3e95c	Melina Maquera	10	5
af49b2d3-c78b-4490-a4c0-9a013a57c1fb	Carolina VASQUÉZ	10	12
d831314e-0036-4bbc-a0ac-cf7918d3c48f	Olenka SALAS	10	12
b512e9d9-d184-4245-b8de-493159be7f45	Bryan Ortiz	10	24
4f5d8e42-b163-4ff1-8b18-fa9a281d2170	Diego Gallegos	11	10
22d0b796-2e14-4b6b-b057-297eac00fc6a	Nicolas Bedregal	12	6
ad7732ff-ba7e-402a-ab12-7398e5063520	Fernanda Salcedo	12	7
9c05a81b-367c-48bc-8bbc-dbbb90ee82d0	Mariell Gutierrez	13	18
5e19114b-eecb-4b10-92ad-fb84a464527e	Nicolas Cahui	13	5
1a709e23-cfd2-41db-b235-242c845de40d	Sergio Jimenez	13	24
6314eeb4-4472-49c8-abbd-a5cbd6afaef5	Iver CHUQUIMIA	13	2
8a836018-3ae5-475f-a17b-4ad540d60cd4	FIORELLA AVILA	14	17
6a0dcb46-3bca-45ca-8246-b411c9211d9e	GAEL RODRIGUEZ	15	8
8aa9e14b-d418-4899-8fcd-5f619c7fd7f2	Hilden Salas	16	18
4205afaf-4d9e-4d83-9dba-4335e51ce2fd	Fabiana Klauer	16	7
c6224cbb-1d75-4d6d-ba7f-b8395788983b	Yvanna Rivera	16	4
af2b40c4-4b7d-4fab-87f5-5aaea91d9a17	Aydan Choquepata	16	20
091c8428-5232-46ab-89ff-38aa394a52f2	Estefania Cusihuamán	17	5
8130d6e2-3e47-4cff-b84e-4df2a7a57158	Leidy FALCÓN	18	22
f906c5c2-493b-4b90-99ef-e3768d9774f1	Juliett Vasquez	19	10
620b70eb-94c9-4e7a-8c50-cb0569c434c3	GABRIELA MUÑOZ	20	13
9fa8862e-74d0-400a-ad29-8a60742c7640	VALENTINA TORRES	21	15
b9d10a98-6b19-4af7-ac71-7e69f4e9ade7	Aldana Ancí	22	2
999a5a13-d7cc-4d1d-8518-6aa5ecf15651	Santiago Laureano	23	6
26097536-aa30-4df8-95dc-19f8917c3552	Byron Ventura	23	4
60b26290-6339-4bf2-9bc9-b2cc40d548b8	NICOLLE CHAYÑA	24	13
015a4dfa-5fca-4ecd-9487-15b4541c005a	María Jesús Cornejo	25	10
dbc1869b-6ce2-4f49-8c14-7a044d90e0d2	Missuri Quispe	26	18
684e2fe7-d628-44fa-8f79-5af13bf9b7e5	Marcelo Villanueva	27	10
a64bd9c2-1a10-43e2-b23c-be82da628831	BENJAMIN MAYTA	28	3
6d5720d1-f675-493c-ac09-9341d1c22260	Jhonatan Duran	28	5
9a6f5962-0022-4e15-9bc0-eb3119c48309	Frank Fernández	28	20
7ff5481e-b6ca-4266-8836-bb9b959415be	Viameli CCAMA	28	19
961e73c0-a5e7-42fd-9811-456b204a0daf	Leonardo Cáceres	29	5
17061e26-90f0-413d-a4d2-005a694f107c	Inés Huamán	29	6
4dadebb1-4409-416c-9ef4-fc9d5851337c	Rafaela Malaga	30	9
1ae88c81-01c4-4c76-8fc9-0f6e9a821a50	Camila Bravo	30	5
daf3d213-2396-4656-9b60-3cd50c8ac17c	Camila Pinto	30	6
68cc87cd-4085-4c88-9e46-6ab0ea00a1ef	CECILIA LINARES	31	23
429be36d-fc47-4fb2-935a-2d7c9dedd0b5	Luciana BERNAL	32	2
84927cd9-5bda-42c0-9b17-9f13e8883788	JOSE CHOQUEHUANCA	33	14
359c6566-c8c4-4c00-9984-a3511bbc4608	AMIRA CLAUX	34	9
9eaf0f6b-05a0-4952-93ba-6f5875d18f9b	Alondra Huarcaya	34	6
4b91d906-3de4-483e-844e-69831c78578c	Juan Burga	34	4
4708cd23-e49a-4923-9f9e-6d87496fef01	Jorge Mariño	35	9
8b474ce9-870b-4f59-828f-fa70123b85ce	MIA FLOREZ	36	3
c1a0f97a-965d-4cf1-af39-154ea0361162	Dante Pamo	36	9
064a52c8-29a1-41b5-bae9-a242d0a2d21b	Maria Silvera	36	18
d0529dde-9d72-481d-8ab9-d280f81e6125	GONZALO MONTESINOS	36	5
630a585e-5876-4be3-bcd7-ba1a71d11ea3	Isabella Carbajal	36	7
03be4e13-3cb7-4d52-be29-61989990a9f9	Paolo Deza	37	10
0f957c66-915a-4a35-9a29-76366d476e39	PIERO HURTADO	38	23
bc9f2d07-fa08-4abf-9885-428c40b5fdf0	Matias Cornejo	39	10
e87d0513-ef7e-4448-9e67-77fd16368e8d	LYONEL ROJAS	40	13
a4dbcbd1-a37b-4600-87c8-e8b4fcfd1643	LUCIANA ACOSTA	41	3
9d85abd4-785a-459a-b308-7071f461597e	ARIADNA MACEDO	41	9
98152b7e-1973-4a14-ad0c-c3e48b6e851f	Luna Choquehuanca	41	18
1d78d295-6ff8-464b-aa98-d148f03b3ccb	Gerald Castillo	41	5
1172dfbe-606f-43ca-947d-4201f56c08ab	Fernanda Muñoz	41	6
7cf77730-b23f-460b-a8e3-ed61e0803bb7	Maria Rivera	41	7
a5b154c2-d51c-4912-b0ee-6c61754cff4c	Adriana Sierra	41	12
36c30dfa-cc76-43e2-9027-c417d294da50	Fabiana Mestas	41	12
b1d88788-2689-4b35-9720-97b5b7e4a64a	CAMILA ESQUIVEL	41	11
0df1d6e2-aafb-4463-b210-5f99329d2e61	Mauricio Bernedo	41	20
a2647e57-41a0-4f93-8862-a88874b56113	James Delgado	41	19
48fd7d55-6f9d-4037-9fed-410edc029d0b	Nayely CCAMA	41	24
82e19836-438f-425a-9db6-b9f9fde00695	Carla Ojeda	41	2
3faaae4b-b97c-435a-bb92-3563bfec5cb9	Luz VENTURA	42	22
81c0c83b-3ddd-4fd7-b160-fb0940fa8f85	JOHANA RODRIGUEZ	43	15
717321ae-54b0-4ad6-ba49-0454a46a5fc6	MATIAS VELÁSQUEZ	44	15
58f2485a-1ef0-4e30-b4f6-d50bbac24440	GONZALO CÁRDENAS	45	9
24a74170-5f62-4f04-8ed5-f874fdea301c	Mariana Escobedo	45	5
8de968ac-289b-4646-a70b-50336b1a7851	EMILY LUNA	45	2
d630b756-338d-4428-af1d-ce1c5ea10c2a	José Becerra	46	10
a77d654e-f090-4520-a221-059dfaf9616d	ALEJANDRO PAUCAR	47	14
8eb68f48-9811-4780-bd5f-3cfce52f4b75	JOISE LUNA	48	16
0f377665-d00a-453d-a5df-fd5b5aeafcc3	Oriana Banda	49	6
58919a04-c465-483c-bbb3-692e52f297f3	Juan Arenas	50	10
25aaa623-2517-4079-aee7-0a89cc4d8081	Esperanza Choque	51	5
f35c6d11-ee75-4f61-801b-f0217f77e303	Nicolas Vargas	51	4
da930d09-2295-427c-8670-74deb0016c76	Alexander Ramos	52	13
07a8238a-9d63-405d-8541-58bed697b7d1	Sebastian Huisa	53	12
eedf7e9a-1589-4e57-8d47-7d99028a7fae	Iair Mamani	53	12
f732abb7-b407-4f34-a299-10ae23ffd177	LEDDY FLORES	54	16
e6b607a9-7f1c-407b-8c04-f320d7196d43	Lucero Apaza	55	7
2e83c14e-2574-4f73-9cfd-3e1a7190f0d2	Sebastián MIRANDA	56	2
999a6c17-ac2e-4c3e-b4eb-48f341691d29	EMILIA RAFAEL	57	14
bced52f0-5b17-4c31-8291-933f9553ea7d	PIERO RETAMOZO	58	14
8b4c7c98-48ca-4b1b-8f92-ff7cdf9be6da	ANDRE ESCARRACHI	59	16
c43b83b9-f085-43e9-9f9d-c6a345d28699	ADRIANO VALDERRAMA	60	14
a7889181-5f6c-4ae6-91ef-21e873cad3ed	DANIEL CAÑAHUARA	61	15
038b2f83-b132-418d-9ed1-9b5c4c0a557e	SANDRA QUISPE	62	21
3e25cbdf-c0f1-4f29-8506-76997b083f69	FRANCO MEDINA	62	17
b170219a-0875-476a-b1ec-e5ec57b7da85	ALMENDRA MACEDO	63	9
74d5b3a8-d6ab-4eea-ac75-78750085e3ae	Carla López	63	18
374970c2-433c-47cd-83c5-294d7d8e2990	Camila Alcca	63	5
33b0bd01-4602-4218-996c-d116ab2a8e41	Gabriela Corrales	63	7
f5744908-a3c4-4094-ae79-c4d0f9024350	Camila PAREDES	63	12
8f406025-8839-4551-b2dc-5488777b1b72	Yunia Pacheco	63	12
d4197d0d-0683-41a4-be02-d83c451dfde1	Jorge Escribens del Carpio	63	4
2e7b24b1-f760-47bb-b48c-56c400492b32	Jackeline Vilca	63	20
fcbcaffa-ba00-4464-9e7f-6af83c5c9966	José AARÓN ARCE	63	19
1e26825b-7815-4f51-9d4f-c168abaf5856	LETIZIA JIRON	63	24
6aa852b4-eac9-45b3-b6dd-4d5a913bf202	Luciana Torres	63	2
c0b2b5e1-d45f-44c2-81a5-2e78cdbe0cf5	Alisson Anccoccallo	64	5
5cdabad6-9880-46a8-b3b2-4a82c96e043a	Aarón Ramirez	65	8
49fe2f16-028d-4a32-9649-8bde088fa6fe	Santiago Lazarte	66	10
bc43d9c3-d6a0-4849-adea-e55192e4097a	FABIO SANCHEZ	67	16
c7600f5d-1d07-45d0-85a0-f8cccb4922aa	ZURIEL BERENICE LA TORRE	68	8
b89526b6-72eb-4b3b-8354-8e11877c2d46	HEMA LUNA	69	16
4df33720-3064-4a98-b9f1-10533cf05fa9	OLEG CUSIRRAMOS	70	10
626b2372-56a5-450d-9c73-f896364b15b4	HuGO Aguilar	71	10
eade2a9f-e48d-49a3-b2cd-2ada059e3301	RUTH LABARTHE	72	16
3bb6ef85-fe69-4310-aa2f-5ab03c7d9326	IVAN PERALTA	73	9
e885719f-3942-48cb-98c5-fd5a9f7e73b7	Joselyn Tuesta	73	5
df1ae3ea-3f59-45a4-8134-89d88e96cc2e	Sebastián Quintana	73	7
0c773a2c-9cf5-49ef-a34a-d74795c4ba0e	Edgar Alvarez	73	4
b5aa8294-8ae8-41e0-9503-8a250c7c7a7b	Jharol CÉSPEDES	73	2
a745c7e2-2188-49b0-9bce-862ed939af13	Alisson SÁNCHEZ	74	22
5e247216-e2a8-47cd-a099-00c04308d0d1	ARIANA SIERRA	75	9
73392dbc-9dab-489a-ba06-e7de8c57e9da	Marleny Soto	75	6
88cd5eb0-d42b-46ea-980f-c7ecb4f30ccd	CAMILA LETONA	75	4
d85c378e-a2fc-43c9-8b9c-a2389608560d	Saúl Rojas	75	2
c81b6a36-4768-41cd-b262-347ae77c2302	ROMINA APAZA	76	14
aace8805-dd6c-4a95-af8e-8d27f3cf520a	LUCERO PACURI	77	23
0f8301b3-1f51-4c3d-9f05-1ec7a7be39eb	TAIRA CCASANI	78	13
105b0e82-32bb-4b49-a27e-e43bc5c70481	KALEB MENDOZA	79	17
8526c30a-bdad-471f-b119-18f054bc4b99	MATIAS NOEL	80	9
a4ab9e5c-5e46-4ec4-bd7c-341501a49e0e	Jorge Torres	80	18
8aaf466a-e1ca-467c-a14b-1867bbc4da3c	Camila Mendoza	80	5
fbfd9970-93fe-41f6-87fd-c2c33d75bbba	ARIANA PORTILLA	80	4
ff1d6a71-529e-43b3-b25f-ca4c31204ee4	Matias Cuno	80	20
f293f093-4dfc-4410-baf0-9806412bdfb2	Milena PONCE	80	24
5e249cfe-89c0-4044-b70e-fb40617ea6dd	ERICK GERALDEZ	80	2
201946ce-e6c3-447c-9d99-6f373187db7f	LUANA LARICO	81	3
ee2131c6-69cc-440a-a0d0-574e295372fe	PIERO VEGA	82	13
f49b0277-6729-4f67-9d63-eaf43c6c45eb	FRANCISCO MARTINEZ	83	14
dbea8af2-123f-48e5-96de-885430b10baf	ANAHÍ CHAMANA	84	13
c577bc91-8d20-4388-9648-1fe00f13fb0f	FABIAN CASTAÑEDA	85	9
dfc3623d-73bc-4625-84fa-9c9892f46bf0	Fhallcha Perez	85	5
38c5400d-aa27-4aa4-8279-2a4e0bc51bb3	Armando Zenteno	85	7
3aecf8df-9ae8-4900-96bf-180b3e7a4171	José Maldonado	85	20
a99e1321-2e48-4fa8-8eb3-fa6eaf349105	Joaquin Montes	85	2
076d0279-09ea-4e55-8b10-05aab6e3aada	ADRIAN RUIZ	86	17
9d418d86-5c15-405d-81c7-8cadbdf9f819	LUCIANA ALARCÓN	87	9
7b264a12-69e1-4857-9b3d-f1b4382ae85b	Daniela Carruitero	87	5
039f60bf-15e4-43c8-850d-bd4341c40ef4	Sofia Alvarez	87	6
59185f79-b329-49df-ab2b-f47824ef3c3f	Shirley Gomez	87	4
49110d1b-f8bd-4d7d-a2d1-6583ac503bd9	Gabriela Sapacayo	87	20
e324dfbf-e009-46d6-8bc7-61c3b54bfddd	André Heredia	87	24
d34a8e1e-5d7b-4907-a198-09f68b6a5649	Leticia YABAR	87	2
4a8e7fb3-f710-4abd-b5fc-e4a13c8a9c19	Ariana Llerena	88	10
7d0060aa-e0c1-4018-aa47-ab9a90aeea58	Heydi Tejada	89	5
ceb93bdf-41d2-4fc7-aa49-fa1fd2263536	Leonardo Hurtado	89	6
9516703f-e4c6-41cb-a177-2ec8a749a7c8	Valeria Fenández	89	7
f99ea9f6-fbfe-46bf-b51f-21d68a7602d8	FERNANDA ILLANEZ	90	15
e7f3709c-a371-4814-b36d-363e598a7d8a	STEPHANO OBANDO	91	8
0656814c-16f3-480c-9c4a-9688616a57e3	Andrea SUAQUITA	92	22
c047f2b6-bcf3-4de6-8fbc-319edabf35a3	Berennicie Nina	93	5
3c5524cf-50c3-4153-a329-db71b45401d8	Scarlet Villanueva	94	10
03a1a7e9-06fa-45ee-8159-23597ffb0667	David Valdeiglesias	95	6
5fda3b14-fc71-40b1-884c-71c590a963eb	Adriano Flores	95	7
d5c0d558-e875-43a5-aa4b-0d27fa0f1ec6	IVANNA ZANABRIA	96	9
03e1811e-1c65-4520-b995-9107491424a9	Luciana Perochena	96	18
084cd7e2-6586-416c-8316-d34eb0da7bd5	Sully Choque	96	4
2a310641-1e09-4562-8c8a-3a843a5e3516	Ana MANRIQUE	96	19
f1b495f6-ed0d-4daf-bccd-a682b01be0f9	Luis Yapu	97	14
d37a9cdd-7cbf-4910-8f9a-6733dfbea2e9	Gianfranco Quispe	98	10
a8bfcc0d-7ed0-46f7-938a-b8a9c803d1b8	Yesibel Cahuanihancco	99	7
af79972e-e3ac-418c-b2cf-472ad2203807	Bryan Apaza	100	15
fe03abbe-e589-45b5-a70c-c9be5d457743	Zenaida QUISPE	101	22
8f650dfb-3674-403b-8a00-80fd2f24151c	LEONEL BELTRAN	102	14
45477ebb-d138-46c6-94ea-b04a60be4264	Any PALOMINO	103	22
edf1d36e-0f04-45a4-b272-4719e1d79210	Marco Merma	104	7
6cb0b31c-87e0-416f-9620-0e492f9beb44	SeBASTIÁN HUERTA	104	12
ffedbcaa-2a43-4616-8da5-b7250c069a6d	SERGIO SOTO	104	12
669ca349-f643-48d4-9639-5ecf63b29dde	Josías ESTRADA	104	2
7077770c-508e-4a91-a19d-277ad29ddc3e	Joaquin Araoz	105	7
c7f59611-3f36-4bb7-a7ee-bd0ca6f5c408	FABIANA MEDINA	106	21
94c92b96-18e2-44ac-87ac-1fa70a387fbe	SERGIO CHAYAN	106	17
2cd86668-5a1f-4ec4-b952-8389acc6dcaa	ENZO ALBARRACIN	107	23
b0173777-8520-4f74-ad28-c85be215fe39	PATRIC PAUCAR	108	16
7e2eb1ec-cfd5-4d17-a0f0-bd2d64999460	GERARDO TORRES	109	15
753b0c61-5187-406e-bd47-c0bd95981e45	ADRIAN DANIEL DEL CARPIO	110	9
02a8b385-cc74-4181-aabe-f303494a2e87	Camila Moscoso	110	5
940f45ad-8b31-43b7-b804-bd6ae99c733d	Ana Quispe	110	6
307d0497-081e-471c-a417-602051e9af94	Mikaela Cano	110	7
5929d377-0b7a-4b4b-8736-56b5da4c297f	Eduardo Apaza	110	4
bc372cf7-0fa9-4bc6-9ea5-7acc770c5f24	Sharon PUMALEQUE	110	19
5f16ba95-4c6a-42ee-aaac-22360e0515c5	JORGE BERRIO	110	2
0784e1f4-d0d9-40b9-ba44-689c9a51561a	ENZO MEZA	111	3
f3bd878f-13ba-4985-b9c2-850292c06eda	VANESSA PALACIOS	111	9
5aba83d3-c5a7-4e61-a4e3-1b567cd47de5	LUCIANA TORRES	111	21
bad94761-73b6-44d6-99d2-64bec764f815	Anderson Bedregal	111	18
5c514d23-8e74-4910-8303-724fb01ce653	DANIELA PAREDES	111	17
024170bd-d5ee-4935-929b-1fffef830018	Allegra Morvely	111	5
bbe055f2-f4c9-4efa-b047-6991406b4c5d	Gabriel Vargas	111	7
a8f3af2b-a1ce-4f78-903d-ba07af66c0db	Rodrigo Zevallos	111	4
d329b8b4-0fc8-4f27-a39d-03c7d5ee9d44	Mauricio Tavera	111	20
2c29df0f-03cb-46ce-8eab-be9460b29357	Nicolas Esquia	111	19
ed6eaf54-5921-47ce-b925-ec991547e8fc	LAURA MELANIE	111	24
ed9b909e-25c3-4f19-873e-8e2caed7a8af	Lucyana LAZO	111	2
c88025b3-e19f-4f43-807a-21441200f970	Marcelo Barazorda	112	23
7cbd9d79-d72f-4fa5-9154-277c51172a2c	yarelia álvarez	113	16
199cb72c-fcc2-4a4f-b85d-96a0b206618d	Alyssa Mamani	114	18
d0939e43-600b-4102-83c9-17300002db29	CAMILA CHIPANA	114	6
26732ede-4a69-416f-8c69-93c603d3e820	TATIANA LOPEZ	114	11
73958364-9d50-481a-be3c-ea9ab804fdd0	Miguel Ibarra	114	4
84be93ca-a6c5-47c2-b3e5-4db9f2955747	Massimo Salazar	115	9
84576b24-5915-4d27-8d7d-020fc721e735	Felipe Pauccara	115	18
629920ec-4f35-4fed-b7e4-89499bb00f37	Enrique Aguilar	115	5
82e98465-40e6-4518-b9c1-f634817a5983	Isis Zegarra	115	6
6f01fe2b-5962-4f81-b1cb-ccc9a0a6bbe6	Bernardo Bardales	115	4
874b25cf-ce77-41ba-8cbc-41b3c435eaf7	Alejandro LLAVE	115	24
f833fe37-762d-437f-9765-0958a1a2d2da	Francisco Ccahui	116	6
ef2be5f7-f7fb-4f4c-aab7-c047ee28d59a	SEBASTIAN HOLGUIN	117	14
108d27bf-d9de-4f19-9254-bd82db7fe6c2	JHONSHEY SAMATA	118	15
2e40e141-c4b0-42c2-a39f-a77e884d4c33	LUANNA TALAVERA	119	3
4040bef5-e5dd-4854-a0bb-0f5cf5ec2b37	NESTOR GUTIERREZ	119	12
f15c2a9c-21f7-4bee-80a3-c6270c47d46d	YARETZI ALESSHA	119	12
ea459ca0-b1b5-445d-9c3b-e8097b6abe71	Tipo Nahuel	120	19
95521e13-e938-4c4b-9107-150aac2b8fa3	MATEO SALAS	121	13
9251384f-f400-4037-b346-a03cd5095e1e	Harold Baldeón	122	4
c798307d-fefd-4d88-8b4d-e1c6cae3dae7	Dominik Arce	123	9
afb68baa-248a-4eb4-9ace-dad1a1c9a8a6	Jazmín Gutierrez	123	5
a34fe473-b322-46c7-95ac-31c58aa8ecb3	Micaela Huacán	123	6
2fc01081-8832-481d-b49d-c2009ad4d7f3	Mikella Suero	123	7
94de631e-6f64-4fec-be40-a0ed007c3db9	Oscar Tapia	123	4
ab7e2f6e-5e1a-4f0b-b3cf-c2e90a2f575c	Naomi Rayas	123	20
4815eb6c-31c6-4306-a067-d8f4d3f5a2fc	Azalia Benavente	123	19
079915bd-71b2-4ded-b717-4e63be1aef32	Juan Quispe	124	10
ddb6650e-24b3-4efc-a64d-4f375e1c6313	Diego Huallpa	125	10
538578cf-c907-430d-8e78-18bed5b7e01e	Juan PAZ	126	22
dc770b25-60b8-42cf-aba5-33894f6ab0d3	Matheo BERNAL	127	2
dfea29b0-dfef-482f-92d5-157d75085503	HECTOR GOMEZ DE LA TORRE	128	9
4e27d563-bba4-4eba-9650-09ebe0978b11	GABRIEL UGARTE	128	12
4ab6486e-e51f-43c9-ac7c-7ac042911138	FabiÁN ALARCON	128	12
05b34f93-2b92-4019-8816-ed0aced7fe40	Frankie Vilca	128	20
f303154b-24a8-47a3-b67b-d464b8ad3c83	Githell CUTIRE	129	12
c93a4091-542f-4eee-ac63-a2e56c42036c	Isabella Peña	129	12
b6ca26bb-a565-4d15-b991-6e9e7721a021	GABRIEL GUITTON	130	3
af1ade2f-9547-42ee-8d28-dcae707c025e	OSCAR SÁNCHEZ	130	9
7a389cf5-2742-4a04-8380-9512127ada75	Gianella Soto	130	5
b342b123-b56e-450e-9b46-27d8f3344886	Fabricio Cari	130	6
7c2d5aa9-386c-4a00-ac92-d8125af9d79f	Ivana Astorga	130	7
e901e93a-3259-49c3-ae09-0461ead5ca43	María Rodríguez	130	4
8da56923-1520-46ed-9318-7d5a410dd06f	Shaneri CONTRERAS	130	2
8460fc21-faee-4627-9ada-6d95953282af	Benedic Barrientos	131	6
c61990ca-8ddb-4f4d-9082-d9e0673c0943	Sebastián QUISPE	131	12
faf06f84-21e9-45d8-9f2a-42a3c2204509	kiao VILCA	131	12
a4551c84-ad9b-426a-8c8e-ce0b9e8c5ca8	Ariana Baca	131	4
538a42db-6c06-4eea-9f7f-4bc092547b3d	Katherine Arizapana	131	20
68e15d66-74ee-4791-8016-696f380b2054	Maryori gonzales	131	19
67a79117-bec4-419c-91e7-4bfcb31250a1	Fabian COAQUIRA	131	24
fead3f9d-6971-4156-a541-a82521b72575	Mariana FRANCO	131	2
f7fafec6-9804-405c-bbf9-1bf8755afc65	Aderly Román	132	10
739a0c3b-7830-43a6-9740-dbe81fa6703e	Joaquín Yato	133	18
563e3281-4abe-4d8e-a3bd-88ec8858703e	Paolo Ari	133	6
de6f6e58-e83e-4001-81ef-2508130aad2d	Sebastian Rebaza	133	7
89ab8f01-b678-41a9-b5d6-f7b6f569d046	Marthin Coaguila	133	4
f3ad4045-a417-4911-80a2-d0a93be091b8	SOPHIE CONCHA	133	2
375d13f6-618b-4d06-8761-4cce71ef29ad	Roland Oscco	134	6
3c0052c1-fe97-4859-a579-c469c6f6555c	Sthefano Pinto	135	10
086affce-0de9-4b31-8c20-8a2fc313efdd	GABRIEL SOTO	136	23
ffe81a03-0dad-4a02-a9da-5cd4dc0d7d13	MILAGROS MOTTA	137	3
d62de08c-0a84-427b-9f95-3509f411ddf8	VALERIA SOTO	137	9
d6ea9cb5-96f5-481b-82bc-8427d0d2741c	Luciana Meléndez	137	5
54d63c3a-7820-48df-98f7-e6fea10f5550	YOAV HIDALGO	137	6
6f2fad47-d2ea-4868-b1f1-988377e0a5dc	Renzo Silva	137	7
a2df2bd4-8ae2-4dc2-b5d8-33d993525ed6	NICOLAS POLANCO	137	11
57591512-506c-4fcd-87f9-44d64870db41	Sabastián Alvites	137	4
cdfa7fb9-0195-4b5f-80bb-0ffe51fe7476	Allisa Alvarado	137	20
4472d1c5-8514-47e0-8b9f-607f93220c75	Abigail ARCE	137	19
eb29e889-0261-447a-962c-10e56742538b	Matias Gutiérrez	137	24
ee995696-a0f9-4d39-b470-f450ccf252ca	LUCIANA LUCERO DEL CARPIO	137	2
4d955917-0579-426f-9452-1507a9adf23e	FERNANDA DANI	138	16
71645858-eacb-47cf-b58a-25acfd5c8478	DANIEL VIVEROS	139	15
66c8751f-4ef4-44f1-9bb7-4ec7179457ff	LUCIANA CHUMPITAZ	140	16
11f2b318-ea09-44b3-9357-7ff5792a9ec0	Katherin Arapa	141	5
c284642b-1f1a-430c-ab5d-dd6e75f4fcf0	Josefina Figueroa	142	5
1e71b4ec-f35f-4b9d-9bf3-9119786ce365	Kiara Montañez	142	6
99cb7505-4b26-4ef2-a67c-022ba6eeebd9	Diana Urquizo	142	4
64b83a16-1e2d-48b1-9fa3-2e5c88c8e13d	GERARD FLORES	143	15
cdb76ab8-036d-4cf4-a7cb-b9dc0e40b16d	INDIRA VERA	144	14
fa592b6a-993a-4b93-8b63-244ae951479d	Matias Sanchez	145	10
ad5bcef1-28aa-4408-bb49-47a3df6e47d9	Adolfo Paredes	146	10
592ad9a3-e7d2-499e-abc8-395f7dcf4750	LUANA ALTUNA	147	13
b85b8b21-b3b8-4701-8eab-b2469eacaa2a	LEONARDO POLANCO	148	3
17ad58e3-a7b5-4f34-b569-ab8e5022f8da	DAYSI UÑUNCO	148	5
ed44497e-e5ad-41c7-98cc-fa86f88bab14	Jose Ccasani	148	7
34c2ee11-6ec2-4ec9-8e98-3e1199f86fd6	Sebastian Alvarez	148	12
99c78939-27ca-4ea6-ae05-45f18e05c292	Mathias Rocha	148	12
66de981b-edb5-4f62-b813-30ee2c6610e5	Danilo Alfaro	148	2
f16753f9-80bf-479c-8c83-8e110dc5dc7f	ADRIANA JARAMILLO	149	16
0683c574-2b8a-4b8a-9639-9ab1c1d18176	GRECIA GUTIERREZ	150	9
aca9b2ff-8e84-4586-bf8b-30990b6e7c38	RUDY HUARCA	150	8
63e7bdb8-8a75-41c9-9022-e4d138aa5a0f	PATRICIO ROJAS	151	13
d0973117-ccae-4ecb-84cb-709d752ef0c2	JACOB ZAVALAGA	152	15
63c6d99b-1e29-4647-9575-d1438b264451	SALVADOR QUISPE	153	9
c2d45132-3fd2-45a2-848b-5900e449276b	ARELIS LOSSIO	154	7
b6a92d32-71fa-4458-a1bc-42df698a50f2	Emmanuel CARDENAS	155	23
06e584f3-87be-4039-913b-8a2e03a6cd7c	Micaela Delgado	156	6
5faf3889-57b7-492f-b296-09342b62bc84	Rodrigo Símbala	156	4
eda36930-9bca-421a-acff-210fcea0af80	LUANA CUYO	156	2
89bfa225-5a57-4da4-88e8-b3f60453a51e	Lucas Vargas	157	18
2477885f-9c09-4bf1-81d7-b3c194c28160	Sebastian Madariaga	157	5
fe5cdcd6-c9ed-47a4-a07c-f21a747554de	Rodrigo Gorbeña	157	6
992ef0bc-9ccd-4b60-ac9e-405e2dda0077	Dayron Chacon	157	7
d175c4e4-7aea-4431-a1f2-7f57a58210f5	Luhana Villegas	157	4
2c721a5e-1e3a-4641-a102-dd3b78c41f5d	Sabrina Cayra	157	20
f12d7e2f-c157-4872-8bba-e273712f0478	Diego Gonzales	157	2
45e84a4e-c279-482e-8a42-7557ba7d96aa	GABRIELA LOVON	158	3
4b5b1042-b80f-4549-a8f3-6bf11139c930	ANDREA SANCHEZ	158	9
8c94c6ca-80d6-4374-9075-e8125f2132af	Kleydi Vargas	158	6
bda40bdd-2f72-4f7a-886b-17032558684a	SOFIA SOLANO	158	11
23542433-5235-4529-b607-14ea0a7eb3ed	Leire Gutiérrez	158	4
7ede9502-9173-4629-99a9-b330dd7afd70	Leonela Zegarra	158	19
f900c4cc-e6b1-44ce-a916-666ff87ce412	José MARÍA Aguilar	158	2
88b04042-2c40-4900-b06e-5a8a2559fd42	Nicolas Miranda	159	10
56dbfc78-9c20-4940-87ff-a6b957d21d1e	Wili Chirinos	160	10
82471e2c-fa07-4c3b-8205-4709e70805d2	Andrea Heredia	161	18
9e55ec6e-658d-41d8-9005-bb5e02ebf72e	Doménica Paredes	161	5
93ba918d-cc6a-4055-89ed-e4edcbb3bc80	Joaquin Aroni	161	6
1dd0aa43-006f-47f2-bdef-f81547d35f2d	Jassid JIMÉNEZ	161	24
94aa0300-b926-4528-a297-48ca07bf418d	SANTIAGO BOLAÑOS	162	23
22a08a8e-779e-487f-8c15-daa539ec37e6	Jeanpier Cutipa	163	7
8867f445-4371-426f-905b-30984a9dac62	GRACIA AGURTO	164	8
98566773-b8c0-49d9-abed-d2d4699c5b21	GABRIELA RODRIGUEZ	165	12
250daa5f-c0c8-473d-9311-12c9a655aa8c	ALISSON CAHUANA	165	12
5977186c-fd63-41a0-9653-dc6c685fb06b	ALEJANDRA PAMPA	166	8
40b2e4ae-122b-4e47-ad1a-e2c131002b20	PATRICIA YAPO	167	16
9d44252b-45bc-4a1b-85eb-a7b3718d973e	Isaac Carbajal	168	12
3c65986a-2881-4dcb-ba1f-ae0faef47069	Jhordan Guitton	168	12
e06e7a63-6ab8-4fe5-b744-be9d4ca50b81	Ximena ABRIL Manzaneda	168	19
0e597766-eeaa-40ca-ad6f-adc8439b25bf	Ana Perez	168	2
67eb7fe5-22a9-495a-baa4-563231c9c0b3	Sergio Tutucayo	169	14
c8e19c35-8169-4421-aea1-d92d3cb69c05	ANDRE PINTO	170	16
ce1033a1-8644-4feb-b34d-bef5c76aec84	VALERIA OLAZO	171	15
671cf2b5-5911-4c1f-b7b8-080917cd59f7	MICAELA ALVAREZ	172	16
fb97aa07-4f34-4aec-b033-e23b267c0a08	Diego Huamán	173	7
871fc8b2-4598-48a0-9c86-2c9da2a1d544	Gabriel Oviedo	174	10
cc697cda-b83f-4569-829b-415cc4b8a894	MICHELLE GUTIERREZ	175	23
16eb4c87-996c-495d-b67d-25c0785d9409	NICK PORTUGAL	176	3
7e1ac2ad-bed8-4ed5-8c4a-96d30447c2a4	Gabriela DE JESÚS COTTA	176	2
85f2c80c-8ac6-4164-8d29-246a41e238c8	ADRIANO RIVERA	177	7
d4770c07-04d7-431d-8094-8aa3988ad26d	Johana ARPI	177	19
1d93f5ee-ff94-4085-9ea0-de9f76bd4c12	Valentina Miranda	177	2
357102c1-c895-481c-8458-ad5ca3f2cc4b	VANIA CHIPA	178	13
13ca2785-0bd3-4915-9824-394d965f8be7	VALENTINA LUZA	179	8
3693e6ce-dd46-4f15-bfae-19596a44a71f	IVANNA DAVILA	180	8
4dd676ef-f474-4802-b4a5-9e722e8459cf	Gabriel Kalinowski	181	7
49762960-8b3b-4a75-9d8f-14f1c989e94b	NANCY PUÑO	181	12
fdd5d183-6af8-4c37-b265-ff8b47d83c54	YERLY HUAMANI	181	12
f901e698-69ee-4da0-8a40-8577bb890413	Alejandro Zanabria	181	4
3544a30d-ed68-453f-83dc-7ed454f199ae	Fernando Curay	181	20
7a14b99a-979b-4858-b6d7-3e526b721484	María Fuentes	181	24
071ac4cf-dde1-4480-bbd6-4b3091330e30	Jazmín Ayca	181	2
00f4e974-7f9c-4349-9cef-ca2048d54aef	Yury Muñiz	182	3
c833ba1e-8ba2-477f-96ca-fb14987a137d	Karyme Huanca	183	10
333f78b8-d32e-4743-bc6b-26ba54f64db9	Rocio Carcausto	184	20
ab3df08a-1790-4eef-8ce4-86fd2985a581	RODRIGO NALVARTE	185	21
3ce292b5-001c-495d-a7bc-9e5f03189afb	María Huashuayo	185	5
2a42920a-f5d9-4238-9fdf-b7959b740e4d	Fidel Castillo	185	12
a0339cf1-0d51-4c98-818d-1ace5fb013d2	Matias Ccami	185	12
50ac585b-874c-4f63-a59a-ade817667098	YAMELY CCALLATA	185	2
69bb1465-4c39-4784-adc3-bca56150ed03	ALEXANDRA HERRERA	186	15
3f10ae27-2213-4828-a447-294c9391656d	FABIANA HUAMANÍ	187	9
917d714d-499b-4784-b3d7-308e4fc2f3f6	Luciana Pinazo	187	6
44540169-c283-48b6-aba5-b7a170d98233	Daniel Contreras	187	7
7d868b8e-6a79-4ced-973d-e0c6df6f5b64	ISMAEL TOHALINO	187	11
3388180d-f74a-4a4c-87be-8f7316449211	Angeles Mamani	187	20
fcc74b43-60de-417a-b348-878f9937ea2f	SERGIO VILLENA	188	23
8307e5df-b2f5-48b3-b5c5-e7846b39922e	Azumy Ccama	189	18
efa254d0-e96f-4f90-b5cb-9a5e36881fae	Yuliana Vásquez	189	6
e867ffdd-5a9c-4e1c-b58b-44a5055d23ba	Sebastian Pinto	189	7
b8ed415d-4ebe-4a86-a84a-fd0ad7856c15	MATHIAS MARTINEZ	189	11
8942d891-c7a9-4583-8b1f-bc05f83f1f5b	Gustavo Gutierrez	189	4
c1bc819a-93eb-47e9-85b4-7118c0543593	GIANELLA GONZALES	189	24
696524f7-80a4-447b-861c-730f579131ce	Bianca Polar	190	5
6629fd41-fe8c-43c0-bbd2-66ef1cd173b8	THIAGO PAZ	191	2
729a2370-189a-4af8-a891-05e5e3f07ad6	FLOR MAMANI	192	16
2c036365-e553-4657-8656-4315b6d8f0c2	SANTIAGO CUSILAYME	193	16
2fdbea83-3a93-4ccd-9b60-91b4897660f1	FABIO VIZCARRA	194	14
029f4761-29e1-4a75-b387-1d48299e539a	MICAELA VIZCARRA	195	15
0d5a5b13-c0f8-4e66-acdb-5227598982b1	Cesar Quispe	196	18
c89e258b-72d2-4161-94a7-65e0e237240f	Ayumi Mestas	196	5
ec5e7936-4e5a-47c9-9b6a-13988be061c6	Emmanuel ESPINOZA	196	2
3eb65cd9-7fd8-4bec-a24f-cdb1be01c683	FRANCISCO LOPEZ	197	23
bfa0a46a-6500-441d-8156-b34097602426	SANTIAGO SALAS	198	10
a74b4af0-7b57-419e-bbcd-10d5f546a767	DIANA MAMANI	199	9
f3eaebd9-4ebc-4cd0-90f6-3d04b6b5ca29	Rocio Arosquipa	199	18
e63fab68-b152-43f9-b41d-3e718bab9157	SANTIAGO TICONA	199	17
1549737f-a86e-4af3-86f4-74a188882cbf	Nicolás Achahui	199	5
642df465-1c9b-4b2b-bc87-2ef6e329923f	Ximena Concha	199	6
fbf161c8-9273-4866-be70-ea3ed216e2e5	Piero Cabrera	199	4
5f045cd1-7823-441c-9709-e75c79db2893	Gabriel ESPINOZA	199	2
5527e640-9d5d-4370-97d6-ce9c3f97257b	RODRIGO RIVERO	200	15
9454a25e-630a-4676-b757-cea7fce57872	AIRTON CARDENAS	201	23
388ae54a-3569-4cbf-b6ee-7a3c64e1a336	Jesús Carrasco	202	6
192fa277-3c47-48f4-8fbc-1bdd0ccbf3b7	Silvana Bellido	203	7
de0dcda6-ca9f-424d-8860-f55ea95928e1	Piero Gallegos	203	4
e8900e23-39d6-42c8-acb1-d09b03a28929	Luz Lozano	203	20
67e45e52-5432-4eb6-8e40-9a788ae7c00c	OSCAR TEVES	203	24
c855dac7-e3ee-4bce-bd51-d0a8bd0280d2	KAMILA ESCOBAR	204	5
13c29e33-9249-46da-821f-048da6172ff9	ANDRE YANARICO	205	14
a90fe19c-257b-410f-ac9c-5710adc240e0	CAMILA QUISPE	206	16
fa1a2ad6-e65f-42c5-a816-f0730626b9ea	Mathias Gamero	207	3
d18b9a4b-14d9-475c-9037-0bc5606885ad	ANA BELLINA	207	9
d0420fa3-19d7-4576-b79d-c7623ae6dc5b	Karen Bustinza	207	18
2cbaa951-ab89-4f48-9d06-c1ae379f8207	Karim Ortiz	207	5
15481cbd-3602-4a1c-8869-643daf05dd35	Solsharyna Villacorta	207	6
0c5c4be9-ab60-4eb2-84db-670a5dd2067f	Mathias Silva	207	7
3d734894-8355-49a1-a883-41b6a309c424	Marie Tripet	207	4
d244e99e-18b2-483d-9c83-b00005414d49	Lilian Chura	207	20
74efd893-0bbc-4e3c-834f-d72fbe888db1	Sofia LUYO	207	2
25a4f210-d23f-4996-b628-cc9d5fa00c84	LESLIE HIDALGO	208	13
df2c7822-a50c-415a-b6fe-b3da9db8db68	MARIAJOSE FLORES	209	9
e86c0628-733b-4c60-a989-f6f7ebf293b9	Valeria Juarez	209	6
77eb1a9c-bf22-423e-b3bb-dc2aa867bbdb	Myaneysha Villacorta	209	4
78a05b6b-93f0-4ee4-b879-39953aed2627	Luciana VERA DE LA Fuente	209	2
e2c77779-9e92-46a7-b7a3-be269cc3a3ac	DANNA CATACORA	210	17
ec3fa82e-ce10-4e35-bd1e-e6b6383d4082	GRETTY MOLINA	211	15
15f3bd39-dde1-4c40-9d2c-c4f4a4c09257	SALVADOR CHUI	212	14
d20deb4d-d04f-498c-9d33-e605fb58283a	JESUS HURTADO	213	3
4fa5c4c4-ad8a-42fb-befe-f2e5942f7866	MARCELO MANCHEGO	213	9
2b48e926-1ae3-453c-90e6-7ebe35f50211	Anjhaly Rodríguez	213	18
59ac024e-7ade-4a6b-9b92-691ea21c068b	Shande Equía	213	5
ed1fad32-02a8-42b2-992e-a120934e1b0a	Adriana Gómez	213	6
dfe5bff1-e014-462c-9af5-f0dd9a3842b8	Valentina Tejada	213	7
c4c5b5df-736c-4aa9-b4c6-83241061b777	GABRIELA LIU	213	4
f6f6bc8e-e577-42b6-a0f9-86ce8c6eb8d2	Nelsi Coaguila	213	20
8cfb02df-f644-4dfa-88b4-a203122ba7ad	PATRICIA LOAIZA	213	24
5e325e1d-963b-4f8f-9912-058c5cc2fbc6	Luis CARBAJAL	213	2
3556ba36-a58f-4e87-aeff-be2782fc5895	CARLOS PENA	214	3
c4321a1a-1c7e-46c8-a8e2-afd7d206c1d5	LUANA ROJAS	214	9
06771c3a-ffb6-4c6f-b9a3-e87b2e39dd31	Atena Perez	214	18
8bd8964a-9fdf-442b-bd71-4c4d3cb9fc69	Patrick Ramirez	214	6
62963d2e-92d2-42e2-96fa-6023affe1204	Luciana Miranda	214	7
70201305-1518-463a-9890-6ec2601fe99b	ALEXANDRA PAMO	214	11
1f358b51-70fc-430b-9e2f-30d2c3f598fc	Sophia Nuñez	214	4
94d6db61-93e3-4e47-9780-cb9275260bef	Leonardo Herrera	214	20
28293eb2-5e97-44af-85bf-8485696e64dc	MATIAS RAMIREZ	214	24
80561981-8e6c-428b-b208-d8bc76b5b393	Valer QUISPE	214	2
d5d37ad7-37f8-4b53-9166-dbd259f44a2c	Angie Coraquillo	215	5
5684c439-4560-40a0-9a19-8d4b03d633f9	VALENTINA ESPINAR	215	8
6d434f39-4956-4610-b604-ed4022ce62bd	SALVADOR SUSANIBAR	216	16
2e3e9841-dd27-4504-af15-9ec071cc3924	Kayrrel Herrera	217	21
c889fd16-a825-427f-8983-8152c99d928e	Dasha Telles	217	5
d95ace84-53fa-487d-92ea-771a8c256772	Kristell LOPEZ	218	2
a8609797-65fd-4ada-b22b-facc513220b0	YIMY CHÁVEZ	219	9
2412d4a4-e5ea-4cd1-a0b7-02920e4f1fa6	Michelle Christina Gaete	219	18
1208e89c-d343-4efb-a9db-f88472064405	Rodrigo Carpio	219	5
d39c4374-a7a7-4338-8176-2f521a41293e	Rafaela Valdivia	219	6
f50c3fdb-6bed-4d9e-91ce-8cb30a316358	José Velasquez	219	7
29ed5fb1-3d31-4a00-afa4-8a08466018de	Juan Perez	219	11
e23de2b8-ddc4-4f88-b38c-5646f39f9d24	Luciana Dávila	219	4
aa2f7096-373d-4364-b5e9-ba235c839f5c	Kaely Huacasi	219	20
3d6079b3-e85d-4498-8dd4-a902f729bc57	Cesar CARDENAS	219	24
6947c554-d6ec-480a-9149-1508ee2707e9	Andrés Rodríguez	219	2
5afe3ec0-2e3d-44c7-adc8-e17b1170497a	César Salas	220	9
7bcab27c-8f70-4b00-86e6-d19cd1e6f241	Brid Huaylla	220	6
d696c123-76b4-4a64-9fa1-59bf48356f82	Esteban Navarrete	220	7
02dba6cd-0a04-40f0-b84b-dfc55ea97e32	Giovanni Ravello	220	4
db71b0e4-141a-414f-b954-e91012541af7	Joaquin RODRÍGUEZ	221	22
717ee8e3-8a45-4dc9-9605-76476d523a2d	MATHIAS SALCEDO	222	9
b1bedcba-57a6-46dd-b210-48c4b2821f22	PAOLA YUPANQUI	222	11
eb0ef00d-5d21-4b90-b03c-45facf618def	Nicole Valdez	222	20
682d0826-2f05-41e1-b2dd-e04367405deb	Alexander QUISPE	222	24
ec2b13a1-db2e-4703-8162-8b143e92a4ac	BIANCA MANCHEGO	223	17
3b8e4b12-3f19-41f5-9ba4-6e4ba04873e4	Alison Arnica	224	10
be0ff465-5a01-425c-b290-3f735f785b54	ERICK SALAS	225	13
388c946f-497d-4e42-9648-dd390da80947	MATIAS VELASQUEZ	226	14
d65782dd-63b5-4f70-ad32-28fca6ee29e1	Karol Minauro	227	18
e8b820f2-12e6-4e2b-8b3d-c818e3af6d07	Santiago Mansilla	227	4
64acb64a-12f5-4356-ae1c-9bdb18ba46de	Daira MEDINA	227	2
e328e507-b075-4605-b1a6-4eb6697d2e0c	ADRIANA LUNA	228	9
d8e59130-5e46-4403-84f1-bff27351a75a	Qorinka Sacaca	228	18
7025ecb6-8032-43dc-91f4-92f9b195ff40	Benjamín Portales	228	5
361745d0-9835-4105-9b4f-fa786a13bebf	Rosa MAMANI	228	12
b0c5dd41-bf0f-4650-bd5d-bb69ba427825	Luis ÁNGEL COARITA	228	12
3152da10-e96f-42b7-9670-f8294efef189	JAIR CONDEMAYTA	228	4
83f65533-f703-40cd-8073-77e69d7040e7	Kiara Alfonso Huacasi	228	20
a728e14e-bd98-43fe-a4bf-da81bf903f58	Jhon CCARITA	228	24
2e3b831e-3db5-4879-9102-8508f4113434	Karol Alcocer	228	2
e24954ad-0275-48b8-afdc-e5fdf07842e4	ANA HUAMAN	229	5
2eefd7d8-b90a-4569-9bd4-9f8d2e78a628	Alvaro Manrique	229	6
25988e8b-4056-4f33-b262-ccdd8ac6e777	Gonzalo Cárdenas	229	7
e89b5d75-8dd6-46f4-a49a-44db958f6321	Alexis Salinas	229	4
faaaff79-a73b-4260-805b-6d5657f986db	Renji VALDEZ	229	2
9ffb46ff-ffcf-44c0-b32c-bff1d8843880	VICENTE SÁNCHEZ	230	9
2ceb25b0-db8c-424c-a819-1ebd1ad21f1e	Ashley Díaz	230	18
380daf3c-7c7c-4d06-b5c6-9873ba8ad801	SUJEIRI CERDEÑA	230	17
984fce7e-a26b-4c8a-8eca-4194c9cae0a2	Lucio Valdivia	230	4
2a4ed371-5873-4fc4-9a33-1007b7454f82	Cristhian TURPO	230	19
7f14be3d-d8c4-498d-b9a7-aa6571654fb7	DEBORA VARCA	231	12
25d4ccd7-bee7-454d-b2eb-5afdcecb7615	ALEJANDRA MAYTA	231	12
1f34fea1-0f3d-49d3-af5b-f180310ca129	ADRIANO MARAZA	232	14
b5fbe174-3a5e-4bb2-a5b1-1cf02c127dde	NICOLAS NAVAL	233	13
23b4461c-a2f3-4d31-8c2a-dafb0518063e	Martha PUMARINO	234	22
054e491d-8bb0-44ce-aba1-5df7e8fda039	DILIA LAZO	235	15
3e04e070-eff6-4448-be5d-00b3fe36ac4f	LUCIANA VENTURA	236	16
0e60ae4e-8b1f-42c8-9ed3-f885631ad162	LEONARDO DELGADO	237	14
33e570a8-cb97-4099-8c60-7b0da909f29e	YAKHELIN PALLANI	238	15
466d0d8e-ff53-470b-aea3-5444d11cf8ac	MAYSSA DE LA CRUZ	239	21
028079a7-9ea2-4061-9a4d-6e6cfeb50827	RAFAELA AGUILAR	239	17
3fda9742-7060-4707-9cc0-d3b3a9b33cc3	GERARDO TORRES	240	13
83d4e6e6-1d05-477b-9694-83cfb77da474	DIEGO TORRES	241	17
6404d19f-01c6-49e3-8f72-4c834ba691a3	Fabiana CÁRDENAS	242	22
2ab9bb6e-606a-444b-8296-7c152c33767e	Nicolás Sarria	243	10
5e8cbd7b-b85d-421c-8583-3a6ff617dc0a	Bruno Villanueva	244	16
302a89eb-9f12-4dcf-ba9a-ad971b8b5d77	Fernando LUQUE	245	22
6cd866ed-2676-45dc-9192-f0efcfe95b9a	Mia Malca	246	6
3b5e1916-497e-4a77-ade2-874a321e4ebe	Alvaro Ccalluchi	247	10
6b4fd696-963c-44a5-9ec8-25ce8d42cf57	SEBASTIAN PAREDES	248	14
db59e489-e45c-420c-8a83-c4e7d314aa1d	GUILIAN VALENCIA	249	23
c24465bc-f638-4d13-828e-a27bbcedbb99	JOAQUIN CARPIO	250	15
d8176124-30d9-4867-abc3-cee01c755edb	ARIANA PAYALICH	251	16
eed96f7a-db8b-4cb8-8124-006402c83c74	LUCIANA CHIRINOS	252	15
7ffa2b33-0438-47f9-97e9-fb6fcfa5b2e5	Diana PACHECO	253	22
4414bcce-42ea-425b-9fa6-bfb93f2394d4	JAIME MIRANDA	254	3
36ebba3c-509e-4d58-afa2-2db771015e5f	ANDREA DIAZ	254	9
ca017e18-04bc-4b8d-b8a3-89c3cf0bbd6f	Yurem Tapia	254	12
d2ef6bc6-db8c-4d15-930e-596ba195c980	Joaquín Huanca	254	12
2346f6c2-41ff-4b47-a848-3da2f67457de	Nahaiah Núñez	254	20
b9f94155-2d85-442b-9dc1-da3c5484d691	BRAULIO VALDERRAMA	255	3
f90898e3-afc5-49b2-89c6-054e93107a1a	Luciana Rojas	255	9
8c0bd80c-3942-4ce1-adc0-44f827a2f5d2	HERBERT HONDERMANN	256	10
9d2a789b-e747-490d-a13b-a124705e7b5b	NEYHER MENDOZA	257	13
947d4044-31ab-44e6-a5e9-3b7324b7bbb3	Nicolle CHILI	258	22
8f2d37ed-2260-41c7-83c5-58ad18d63224	JHOSMEL CAMPANA	259	14
5a859f36-e539-423a-9fd5-9756203589b3		260	21
13b621d1-a09a-46be-bd6b-f0c9a526bfae	ALESKHA OCHOCHOQUE	261	17
4cd4162b-20f3-4526-a768-777d6b77657b	EMILIA LINARES	261	8
f672ee64-a0e1-471c-9b14-d05dc1e5a042	PAUL YANA	262	15
82759853-4328-4cd8-ba32-0b709fb3a514	Ofelia ÁLVAREZ	263	22
167eaf13-af7b-49a4-861f-ac33faae634f	CANDY CHISLLA	264	16
69a31d6e-11cf-4016-bb6e-aa6e5d056a35	Jhoselyn Justo	265	7
7337446c-3064-4913-811c-f8d2d01758a6	Luciana Miranda	265	4
a7d9a7d7-22ab-465c-a7bc-0607582bd67a	Helliot Morales	265	2
1099d932-efee-4b5e-b8be-6c5708ca6758	ANGEL CACERES	266	10
872aba8e-3a74-49fa-85ab-b8f70f81f5a1	Cristopher Fuentes	267	9
75c3d7c4-898a-490b-8c5c-656c5da6cf55	Nayuth Flores	267	18
20fb258f-fda1-4091-966a-d354691f85eb	Raphaela ABSI	267	12
7e4ab9dc-0255-4bdb-bf6e-7c5f0939e904	Ariana FRANCO	267	12
cf044f8e-a004-43e5-accf-c144be0feb5e	Darwin Ortiz	267	20
97fad8f3-e410-4349-83aa-f724690c6bf2	JOSE MARÍA NOVA	268	3
cf772a4d-997b-4725-b653-1e04d5e5e90f	FACUNDO ALARCÓN	268	9
d67caf86-ad50-4e8d-9387-05ff29f233db	Heiner Gonzales	268	18
c52dda66-b0b7-49ba-a047-3a4b525da654	Rodrigo Rossel	268	7
b0caeb60-969f-47df-8146-b30ca8f434eb	DANIELA PAREDES	269	16
327e1871-c19b-4428-a7d4-91c154db8497	Juan Chocano	270	5
54f1a14e-c756-47b2-821d-2e04cb388174	Galy Espinoza	270	6
d444a392-fcf3-4092-8fd5-3b8d92579954	RODRIGO ROSADO	271	13
4dd7990b-95e8-4678-9e23-58f6777e8814	Luis Aroni	272	15
89bae781-5ec2-4d06-a4d5-926e1967b051	Daniel Casas	273	21
4b4ffb95-00e1-4b39-995f-de9b45992b53	ADRIAN LAVERIANO	274	13
ceac8834-a3f6-4467-ba80-703acc3e8757	MARIA RIVAS	275	11
d08a7cf6-b41b-42d7-97b9-05ee4050714c	Hillary Villena	275	4
02d05582-dabc-4aed-991f-2e729bbcf3d0	JANIRA PINEDA	276	22
1b803832-07b7-4b78-96c3-98239a6060c0	Luana URQUIETA	277	2
376fbb6a-78d5-4ae6-91b0-6c559cb02fbc	Nicolas Solano	278	10
f8b44da0-7297-405a-a1c8-1ec82a118437	ROUSE QUICAÑA	279	3
16806821-69ef-4775-b59b-3c73cf84ffe2	VICTOR CASTELLANOS	280	23
838d7290-7092-437c-b0db-121c179832c4	LEONARDO LLERENA	281	23
c08fb6cc-fab0-4a43-b3d9-14af0d35ac99	André Rubin de Celis	282	6
83b6259b-0404-4d7a-b8c8-0a4f7bd136d1	JORGE PAREDES	283	3
24f2c054-8bc8-4a3f-8cdf-a4db53c67ea6	MARISOL PAREDES	284	23
2f69ca6d-88a3-4d81-8b87-51b7c74c94ec	Nataly Villagra	285	22
c6c4746f-19de-466a-b96e-3c99e589923a	Matias Carrasco	286	10
17637d77-4ac3-47e3-9fe1-1491ad8da76b	Jemar Huamani	287	14
158a4f2b-b1f0-41bf-86b8-7a44eed2a2e7	ANGELI FLORES	288	15
83fc79a7-abf5-474a-8346-cc82024853eb	Rodrigo Cutimbo	289	10
fc7a1410-7d99-4782-b08c-cf78c6a38be4	SANTIAGO RAVINES	290	13
aca1427b-0cc5-4aaf-bf54-0a045c2893a2	BRUST BRAVO	291	13
2c43e3dc-7d91-4b84-b2ca-e07822463a56	Bruno Rocchetti	292	16
273d6990-8aab-464a-9750-71433da9b70c	CRISTHIAN EQUINIQO	293	13
0e948cea-63d9-4390-94d6-39f528214bd8	MARIA JOSÉ VARGAS	294	3
f1222a84-68ee-4279-8cfa-1d348e9b7b84	Fabian Gamarra	294	9
d9b82c7d-b5fe-4282-ade0-7e48a20b535f	ANDREA RAMOS	294	21
23a329d7-bc4f-4873-91f6-c329b3e44621	Alvaro Robles	294	18
fd8d48ea-6dc2-490d-9d3c-43152becf4c2	Milagros Quispe	294	5
a68ea816-701c-45d7-b9c4-994deffbb703	Alfredo Salome	294	6
4a2c0c56-6557-46dd-a358-305ba5e369cf	Yamilet Santander	294	7
238d20b4-75b6-4f22-8d57-876b61f43fe9	ALAN LAZÁRO	294	11
39d696d7-3e79-4025-ac54-7c76242bbb1d	Fernanda Rodríguez	294	4
1a931ff8-ce7f-4927-aca9-b48770fab392	Estrella Miranda	294	24
678ebdf2-b52b-4c47-8c1b-4cbf41ee9ba2	María JOSÉ Salazar	294	2
b65e22c9-bc7b-48b2-be26-aa6dadc47515	Jimena POSTIGO	295	2
d0d2aad3-b973-47f8-8f44-da4e5ad59eae	YULIA LADRÓN DE GUEVARA	296	9
285af13f-ef48-401d-9b63-bd6c8d67fff7	Ariana Carrasco	296	18
eac74fe1-da17-4125-a7dc-77e12746ef12	Eniel Colquehuanca	296	6
be7fa713-1ce6-4b3f-a54f-628691d7e564	Farid Lizárraga	296	7
305b0abb-321b-4151-8fb2-ad1fe88ea408	MARYORIE VARGAS	296	11
0aa46475-db52-46f3-bec8-fcc68066fd53	Lucia Arenas	296	4
34191aed-89b9-4bfe-a767-b19278fb66cf	Tomás BECERRA	296	24
16519e91-07a8-4b11-8c6b-c0845ac0b2cd	Mikeyla Cora	296	2
da8d8308-b559-4953-a4fa-e5803e75661e	DOMENICA RAVINES	297	5
9040bf3d-5f76-4590-80d0-8ff4df8e7917	Sebastian Flores	297	6
233138aa-2e74-4d62-8fc1-bb57a7327fa4	Fabia López	297	4
29122e9d-d3e5-4986-85ac-5e33d4f13375	Joaquin Macedo	297	2
26ba1c58-99f0-4d25-b0e7-a9c76dae259d	Sara ARHUIRE	298	22
\.


--
-- Data for Name: Motion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Motion" (id, type, topic, "totalTime", "timePerDelegate", "maxDelegates", "proposedBy", "committeeId", "sessionId", "inFavorVotes", "createdAt") FROM stdin;
2	UNMODERATED_CAUCUS	Crisis Response	20	\N	\N	6314eeb4-4472-49c8-abbd-a5cbd6afaef5	2	1	0	2024-12-02 13:36:09.743
3	MODERATED_CAUCUS	Climate Action	10	1	10	6314eeb4-4472-49c8-abbd-a5cbd6afaef5	2	1	0	2024-12-02 13:36:09.743
4	MODERATED_CAUCUS	Healthcare Systems	12	1	12	6314eeb4-4472-49c8-abbd-a5cbd6afaef5	2	1	0	2024-12-02 13:36:09.743
5	UNMODERATED_CAUCUS	Trade Relations	15	\N	\N	b9d10a98-6b19-4af7-ac71-7e69f4e9ade7	2	1	0	2024-12-02 13:36:09.743
6	MODERATED_CAUCUS	Cybersecurity	18	2	9	b9d10a98-6b19-4af7-ac71-7e69f4e9ade7	2	1	0	2024-12-02 13:36:09.743
7	MODERATED_CAUCUS	Education Reform	20	2	10	b9d10a98-6b19-4af7-ac71-7e69f4e9ade7	2	1	0	2024-12-02 13:36:09.743
8	UNMODERATED_CAUCUS	Diplomatic Relations	25	\N	\N	b9d10a98-6b19-4af7-ac71-7e69f4e9ade7	2	1	0	2024-12-02 13:36:09.743
9	MODERATED_CAUCUS	Human Rights	15	1	15	b9d10a98-6b19-4af7-ac71-7e69f4e9ade7	2	1	0	2024-12-02 13:36:09.743
10	MODERATED_CAUCUS	Technology Access	16	2	8	b9d10a98-6b19-4af7-ac71-7e69f4e9ade7	2	1	0	2024-12-02 13:36:09.743
11	UNMODERATED_CAUCUS	Environmental Protection	20	\N	\N	429be36d-fc47-4fb2-935a-2d7c9dedd0b5	2	1	0	2024-12-02 13:36:09.743
12	MODERATED_CAUCUS	Food Security	14	2	7	429be36d-fc47-4fb2-935a-2d7c9dedd0b5	2	1	0	2024-12-02 13:36:09.743
13	MODERATED_CAUCUS	Public Health	15	1	15	429be36d-fc47-4fb2-935a-2d7c9dedd0b5	2	1	0	2024-12-02 13:36:09.743
14	UNMODERATED_CAUCUS	Infrastructure Development	18	\N	\N	429be36d-fc47-4fb2-935a-2d7c9dedd0b5	2	1	0	2024-12-02 13:36:09.743
15	MODERATED_CAUCUS	Gender Equality	12	1	12	82e19836-438f-425a-9db6-b9f9fde00695	2	1	0	2024-12-02 13:36:09.743
16	MODERATED_CAUCUS	Youth Employment	16	2	8	8de968ac-289b-4646-a70b-50336b1a7851	2	1	0	2024-12-02 13:36:09.743
17	UNMODERATED_CAUCUS	Cultural Exchange	15	\N	\N	2e83c14e-2574-4f73-9cfd-3e1a7190f0d2	2	1	0	2024-12-02 13:36:09.743
18	MODERATED_CAUCUS	Digital Innovation	20	2	10	6aa852b4-eac9-45b3-b6dd-4d5a913bf202	2	1	0	2024-12-02 13:36:09.743
19	MODERATED_CAUCUS	Sustainable Development	15	1	15	b5aa8294-8ae8-41e0-9503-8a250c7c7a7b	2	1	0	2024-12-02 13:36:09.743
20	UNMODERATED_CAUCUS	Peace Building	25	\N	\N	b5aa8294-8ae8-41e0-9503-8a250c7c7a7b	2	1	0	2024-12-02 13:36:09.743
1	MODERATED_CAUCUS	Economic Impact	15	1	15	6314eeb4-4472-49c8-abbd-a5cbd6afaef5	2	1	0	2024-12-02 13:56:40.421
\.


--
-- Data for Name: PassedMotion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."PassedMotion" (id, "motionId", "startTime", status) FROM stdin;
e8219172-0b17-436c-ae4c-1204bcf5dc77	6	2024-12-02 13:49:27.204	ONGOING
fb708b8e-c99c-41ca-900b-90eb4dd1b9dd	10	2024-12-02 13:49:27.204	ONGOING
a58f572a-fa03-4762-848e-0aee1220d4bc	15	2024-12-02 13:49:27.204	ONGOING
2a6fcd48-74a6-4528-93a4-7c7731793fd6	20	2024-12-02 13:49:27.204	ONGOING
210e9a8b-a892-4fea-94ef-e2ffc73748d9	1	2024-12-02 13:49:27.204	FINISHED
\.


--
-- Data for Name: PassedMotionDelegate; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."PassedMotionDelegate" (id, "passedMotionId", "delegateId", "speakingOrder", "timeUsed", notes) FROM stdin;
460cf8b9-6459-46f9-bae2-9083158ea5fa	210e9a8b-a892-4fea-94ef-e2ffc73748d9	5f16ba95-4c6a-42ee-aaac-22360e0515c5	1	23	Brief comment
844a34d0-2ca2-4d72-97ae-1d8bcf953e64	210e9a8b-a892-4fea-94ef-e2ffc73748d9	ed9b909e-25c3-4f19-873e-8e2caed7a8af	2	17	Another note
6a3c73f7-bcd3-4454-a2a8-9867778ba329	210e9a8b-a892-4fea-94ef-e2ffc73748d9	6314eeb4-4472-49c8-abbd-a5cbd6afaef5	3	42	Quick point made
4eba01be-ff30-4344-b286-e3019075bc46	210e9a8b-a892-4fea-94ef-e2ffc73748d9	429be36d-fc47-4fb2-935a-2d7c9dedd0b5	4	55	Supporting the motion
e8fbe118-a9b1-42fe-b661-8ffa818d9830	210e9a8b-a892-4fea-94ef-e2ffc73748d9	29122e9d-d3e5-4986-85ac-5e33d4f13375	5	31	Opposed, with reasons
d9bfb560-d2ce-470d-836b-42828fcee476	210e9a8b-a892-4fea-94ef-e2ffc73748d9	b9d10a98-6b19-4af7-ac71-7e69f4e9ade7	6	49	Query on finances
81a38514-746d-4823-8220-46636ce7ca5a	210e9a8b-a892-4fea-94ef-e2ffc73748d9	6629fd41-fe8c-43c0-bbd2-66ef1cd173b8	7	13	Seconding the motion
e2b837a1-6fb4-4a0b-9db4-2fd4c8ae03b6	210e9a8b-a892-4fea-94ef-e2ffc73748d9	80561981-8e6c-428b-b208-d8bc76b5b393	8	58	Concern on timing
df4e2d88-8fd3-4bf6-90cc-3cfd787f8a3f	210e9a8b-a892-4fea-94ef-e2ffc73748d9	6947c554-d6ec-480a-9149-1508ee2707e9	9	22	Suggestion for amendment
cb9aedef-4c22-48e7-ba4e-dd2ab51da951	210e9a8b-a892-4fea-94ef-e2ffc73748d9	64acb64a-12f5-4356-ae1c-9bdb18ba46de	10	46	Final thoughts
70f15077-3fc4-44ed-9f8f-4acaa18fcb7b	e8219172-0b17-436c-ae4c-1204bcf5dc77	60b26290-6339-4bf2-9bc9-b2cc40d548b8	\N	120	\N
\.


--
-- Data for Name: Session; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Session" (id, date, "startTime", "endTime", status) FROM stdin;
2	2024-11-08 00:00:00	2024-11-08 23:15:00	2024-11-09 00:30:00	SCHEDULED
3	2024-11-09 00:00:00	2024-11-09 13:30:00	2024-11-09 15:00:00	SCHEDULED
4	2024-11-09 00:00:00	2024-11-09 15:30:00	2024-11-09 18:00:00	SCHEDULED
5	2024-11-09 00:00:00	2024-11-09 19:30:00	2024-11-09 22:00:00	SCHEDULED
6	2024-11-09 00:00:00	2024-11-09 22:30:00	2024-11-10 00:00:00	SCHEDULED
7	2024-11-10 00:00:00	2024-11-10 13:30:00	2024-11-10 15:00:00	SCHEDULED
8	2024-11-10 00:00:00	2024-11-10 15:30:00	2024-11-10 17:00:00	SCHEDULED
9	2024-11-10 00:00:00	2024-11-10 19:30:00	2024-11-10 21:30:00	SCHEDULED
1	2024-11-08 00:00:00	2024-11-08 22:00:00	2024-11-08 23:00:00	FINISHED
\.


--
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
\.


--
-- Name: Asistencia_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Asistencia_id_seq"', 990, true);


--
-- Name: Committee_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Committee_id_seq"', 24, true);


--
-- Name: Country_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Country_id_seq"', 298, true);


--
-- Name: Session_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Session_id_seq"', 9, true);


--
-- Name: Asistencia Asistencia_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Asistencia"
    ADD CONSTRAINT "Asistencia_pkey" PRIMARY KEY (id);


--
-- Name: Chair Chair_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Chair"
    ADD CONSTRAINT "Chair_pkey" PRIMARY KEY (id);


--
-- Name: Committee Committee_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Committee"
    ADD CONSTRAINT "Committee_pkey" PRIMARY KEY (id);


--
-- Name: Country Country_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Country"
    ADD CONSTRAINT "Country_pkey" PRIMARY KEY (id);


--
-- Name: Delegate Delegate_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Delegate"
    ADD CONSTRAINT "Delegate_pkey" PRIMARY KEY (id);


--
-- Name: Motion Motion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Motion"
    ADD CONSTRAINT "Motion_pkey" PRIMARY KEY (id);


--
-- Name: PassedMotionDelegate PassedMotionDelegate_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."PassedMotionDelegate"
    ADD CONSTRAINT "PassedMotionDelegate_pkey" PRIMARY KEY (id);


--
-- Name: PassedMotion PassedMotion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."PassedMotion"
    ADD CONSTRAINT "PassedMotion_pkey" PRIMARY KEY (id);


--
-- Name: Session Session_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Session"
    ADD CONSTRAINT "Session_pkey" PRIMARY KEY (id);


--
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- Name: Asistencia_delegateId_sessionId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "Asistencia_delegateId_sessionId_key" ON public."Asistencia" USING btree ("delegateId", "sessionId");


--
-- Name: Chair_clerkId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "Chair_clerkId_key" ON public."Chair" USING btree ("clerkId");


--
-- Name: Chair_email_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "Chair_email_key" ON public."Chair" USING btree (email);


--
-- Name: Committee_name_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "Committee_name_key" ON public."Committee" USING btree (name);


--
-- Name: PassedMotionDelegate_passedMotionId_delegateId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "PassedMotionDelegate_passedMotionId_delegateId_key" ON public."PassedMotionDelegate" USING btree ("passedMotionId", "delegateId");


--
-- Name: PassedMotion_motionId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "PassedMotion_motionId_key" ON public."PassedMotion" USING btree ("motionId");


--
-- Name: Asistencia prevent_delegate_participation_in_overlapping_sessions_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER prevent_delegate_participation_in_overlapping_sessions_trigger BEFORE INSERT ON public."Asistencia" FOR EACH ROW EXECUTE FUNCTION public.prevent_delegate_participation_in_overlapping_sessions();


--
-- Name: Session set_default_start_time_for_session_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_default_start_time_for_session_trigger BEFORE INSERT ON public."Session" FOR EACH ROW EXECUTE FUNCTION public.set_default_start_time_for_session();


--
-- Name: PassedMotionDelegate update_motion_in_favor_votes_on_delegate_participation_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_motion_in_favor_votes_on_delegate_participation_trigger AFTER UPDATE OF "timeUsed" ON public."PassedMotionDelegate" FOR EACH ROW EXECUTE FUNCTION public.update_motion_in_favor_votes_on_delegate_participation();


--
-- Name: PassedMotionDelegate update_passed_motion_status_on_delegate_update_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_passed_motion_status_on_delegate_update_trigger AFTER UPDATE OF "timeUsed" ON public."PassedMotionDelegate" FOR EACH ROW EXECUTE FUNCTION public.update_passed_motion_status_on_delegate_update();


--
-- Name: Session update_session_status_on_end_time_update_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_session_status_on_end_time_update_trigger AFTER UPDATE OF "endTime" ON public."Session" FOR EACH ROW EXECUTE FUNCTION public.update_session_status_on_end_time_update();


--
-- Name: Asistencia Asistencia_delegateId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Asistencia"
    ADD CONSTRAINT "Asistencia_delegateId_fkey" FOREIGN KEY ("delegateId") REFERENCES public."Delegate"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Asistencia Asistencia_sessionId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Asistencia"
    ADD CONSTRAINT "Asistencia_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES public."Session"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Chair Chair_committeeId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Chair"
    ADD CONSTRAINT "Chair_committeeId_fkey" FOREIGN KEY ("committeeId") REFERENCES public."Committee"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Delegate Delegate_committeeId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Delegate"
    ADD CONSTRAINT "Delegate_committeeId_fkey" FOREIGN KEY ("committeeId") REFERENCES public."Committee"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Delegate Delegate_countryId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Delegate"
    ADD CONSTRAINT "Delegate_countryId_fkey" FOREIGN KEY ("countryId") REFERENCES public."Country"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Motion Motion_committeeId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Motion"
    ADD CONSTRAINT "Motion_committeeId_fkey" FOREIGN KEY ("committeeId") REFERENCES public."Committee"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Motion Motion_proposedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Motion"
    ADD CONSTRAINT "Motion_proposedBy_fkey" FOREIGN KEY ("proposedBy") REFERENCES public."Delegate"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Motion Motion_sessionId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Motion"
    ADD CONSTRAINT "Motion_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES public."Session"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: PassedMotionDelegate PassedMotionDelegate_delegateId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."PassedMotionDelegate"
    ADD CONSTRAINT "PassedMotionDelegate_delegateId_fkey" FOREIGN KEY ("delegateId") REFERENCES public."Delegate"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: PassedMotionDelegate PassedMotionDelegate_passedMotionId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."PassedMotionDelegate"
    ADD CONSTRAINT "PassedMotionDelegate_passedMotionId_fkey" FOREIGN KEY ("passedMotionId") REFERENCES public."PassedMotion"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: PassedMotion PassedMotion_motionId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."PassedMotion"
    ADD CONSTRAINT "PassedMotion_motionId_fkey" FOREIGN KEY ("motionId") REFERENCES public."Motion"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO armun_app;


--
-- Name: TABLE "Asistencia"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."Asistencia" TO armun_app;


--
-- Name: SEQUENCE "Asistencia_id_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public."Asistencia_id_seq" TO armun_app;


--
-- Name: TABLE "Chair"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."Chair" TO armun_app;


--
-- Name: TABLE "Committee"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."Committee" TO armun_app;


--
-- Name: SEQUENCE "Committee_id_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public."Committee_id_seq" TO armun_app;


--
-- Name: TABLE "Country"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."Country" TO armun_app;


--
-- Name: SEQUENCE "Country_id_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public."Country_id_seq" TO armun_app;


--
-- Name: TABLE "Delegate"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."Delegate" TO armun_app;


--
-- Name: TABLE "Motion"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."Motion" TO armun_app;


--
-- Name: TABLE "PassedMotion"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."PassedMotion" TO armun_app;


--
-- Name: TABLE "PassedMotionDelegate"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."PassedMotionDelegate" TO armun_app;


--
-- Name: TABLE "Session"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."Session" TO armun_app;


--
-- Name: SEQUENCE "Session_id_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public."Session_id_seq" TO armun_app;


--
-- Name: TABLE _prisma_migrations; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public._prisma_migrations TO armun_app;


--
-- PostgreSQL database dump complete
--

