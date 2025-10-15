--
-- PostgreSQL database dump
--

-- Dumped from database version 11.22
-- Dumped by pg_dump version 17.6

-- Started on 2025-10-15 10:12:04

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
-- TOC entry 9 (class 2615 OID 49152)
-- Name: itv; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA itv;


ALTER SCHEMA itv OWNER TO postgres;

--
-- TOC entry 968 (class 1255 OID 49153)
-- Name: get_all_bcht_lines(); Type: FUNCTION; Schema: itv; Owner: postgres
--

CREATE FUNCTION itv.get_all_bcht_lines() RETURNS TABLE(inspection_gid integer, id_reg_ent text, id_reg_sor text, sens_ecoul text, type_obs text, fam_obs text, code_obs text, libel_obs text, orientatio text, geom public.geometry)
    LANGUAGE plpgsql
    AS $$
DECLARE
    inspection_id integer;
BEGIN
    FOR inspection_id IN
        SELECT DISTINCT gid FROM itv.inspection
    LOOP
        RETURN QUERY
        SELECT * FROM itv.get_bcht_lines(inspection_id);
    END LOOP;
END;
$$;


ALTER FUNCTION itv.get_all_bcht_lines() OWNER TO postgres;

--
-- TOC entry 969 (class 1255 OID 49154)
-- Name: get_all_bcht_positions(); Type: FUNCTION; Schema: itv; Owner: postgres
--

CREATE FUNCTION itv.get_all_bcht_positions() RETURNS TABLE(inspection_gid integer, id_reg_ent text, id_reg_sor text, x double precision, y double precision, sens_ecoul text, type_obs text, fam_obs text, code_obs text, libel_obs text, orientatio text, geom public.geometry)
    LANGUAGE plpgsql
    AS $$
            DECLARE
                inspection_id integer;
            BEGIN
                FOR inspection_id IN
                    SELECT DISTINCT gid
                    FROM itv.inspection
                LOOP
                    RETURN QUERY
                    SELECT * FROM itv.get_bcht_positions(inspection_id);
                END LOOP;
            END;
            
$$;


ALTER FUNCTION itv.get_all_bcht_positions() OWNER TO postgres;

--
-- TOC entry 970 (class 1255 OID 49155)
-- Name: get_all_defect_positions(); Type: FUNCTION; Schema: itv; Owner: postgres
--

CREATE FUNCTION itv.get_all_defect_positions() RETURNS TABLE(inspection_gid integer, id_reg_ent text, id_reg_sor text, id_troncon text, metrage numeric, x double precision, y double precision, n_passage text, sens_ecoul text, type_obs text, fam_obs text, code_obs text, libel_obs text, quan_charg text, rmq_obs text, orientatio text, precipitat text, photo text, video text, video_tps text, date_obs text, code_insee character varying, geom public.geometry)
    LANGUAGE plpgsql
    AS $$
            DECLARE
                inspection_id integer;
            BEGIN
                FOR inspection_id IN
                    SELECT DISTINCT gid
                    FROM itv.inspection
                LOOP
                    RETURN QUERY
                    SELECT * FROM itv.get_defect_positions(inspection_id);
                END LOOP;
            END;
            
$$;


ALTER FUNCTION itv.get_all_defect_positions() OWNER TO postgres;

--
-- TOC entry 971 (class 1255 OID 49156)
-- Name: get_all_inspection_data(); Type: FUNCTION; Schema: itv; Owner: postgres
--

CREATE FUNCTION itv.get_all_inspection_data() RETURNS TABLE(inspection_gid integer, nature_res character varying, type_eau character varying, date_deb date, date_fin date, entreprise text, longueur numeric, nom_plan text, nom_rapport text, nom_txt text, remarques text, geom public.geometry)
    LANGUAGE plpgsql
    AS $$
            DECLARE
                inspection_id integer;
            BEGIN
                FOR inspection_id IN
                    SELECT DISTINCT gid
                    FROM itv.inspection
                LOOP
                    RETURN QUERY
                    SELECT * FROM itv.get_inspection_data(inspection_id);
                END LOOP;
            END;
            
$$;


ALTER FUNCTION itv.get_all_inspection_data() OWNER TO postgres;

--
-- TOC entry 972 (class 1255 OID 49157)
-- Name: get_bcht_lines(integer); Type: FUNCTION; Schema: itv; Owner: postgres
--

CREATE FUNCTION itv.get_bcht_lines(inspection_gid_input integer) RETURNS TABLE(inspection_gid integer, id_reg_ent text, id_reg_sor text, sens_ecoul text, type_obs text, fam_obs text, code_obs text, libel_obs text, orientatio text, geom public.geometry)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    coll_table text;
    coll_gid_column text;
    reg_table text;
    reg_gid_column text;
    v_shp_reg_id_fieldname text;
    v_shp_coll_id_fieldname text;
    sql_query text;
    srid integer;
BEGIN
    -- Récupérer tables et champs
    SELECT shp_coll_table, shp_reg_table, shp_reg_id_fieldname, shp_coll_id_fieldname
    INTO coll_table, reg_table, v_shp_reg_id_fieldname, v_shp_coll_id_fieldname
    FROM itv.inspection WHERE gid = inspection_gid_input;

    -- Déterminer les colonnes ID
    IF coll_table IS NOT NULL AND trim(coll_table) <> '' THEN
        coll_gid_column := COALESCE(NULLIF(trim(v_shp_coll_id_fieldname), ''), (
            SELECT column_name FROM information_schema.columns
            WHERE table_schema = 'itv' AND table_name = coll_table AND column_name IN ('numero','ident','gid') LIMIT 1
        ));
    END IF;
    IF reg_table IS NOT NULL AND trim(reg_table) <> '' THEN
        reg_gid_column := COALESCE(NULLIF(trim(v_shp_reg_id_fieldname), ''), (
            SELECT column_name FROM information_schema.columns
            WHERE table_schema = 'itv' AND table_name = reg_table AND column_name IN ('numero','ident','gid') LIMIT 1
        ));
    END IF;

    -- Déterminer SRID
    BEGIN
        IF coll_table IS NOT NULL THEN
            EXECUTE format('SELECT ST_SRID(geom) FROM itv.%I LIMIT 1', coll_table) INTO srid;
        ELSE
            EXECUTE format('SELECT ST_SRID(geom) FROM itv.%I LIMIT 1', reg_table) INTO srid;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        srid := 2154;
    END;

    -- Construire la requête selon présence du collecteur
    IF coll_table IS NOT NULL AND coll_gid_column IS NOT NULL THEN
        -- Avec collecteur
        sql_query := format($f$
            WITH inspection_data AS (
                SELECT
                    v_itv_details.inspection_gid,
                    v_itv_details.id_reg_ent::text,
                    v_itv_details.id_reg_sor::text,
                    v_itv_details.id_troncon::text,
                    v_itv_details.metrage::numeric,
                    v_itv_details.n_passage::text,
                    v_itv_details.sens_ecoul::text,
                    v_itv_details.type_obs::text,
                    v_itv_details.fam_obs::text,
                    v_itv_details.code_obs::text,
                    v_itv_details.libel_obs::text,
                    v_itv_details.quan_charg::text,
                    v_itv_details.rmq_obs::text,
                    v_itv_details.orientatio::text,
                    v_itv_details.precipitat::text,
                    v_itv_details.photo::text,
                    v_itv_details.video::text,
                    v_itv_details.video_tps::text,
                    v_itv_details.date_obs::text,
                    ST_LineMerge(reseau.geom) AS troncon_geom,
                    regard_ent.geom AS regard_entrant_geom,
                    regard_sor.geom AS regard_sortant_geom,
                    CAST(%s AS integer) AS srid
                FROM
                    itv.v_itv_details
                JOIN
                    itv.ids_coll ids_reseau ON ids_reseau.id_itv = v_itv_details.id_troncon
                JOIN
                    itv.ids_reg ids_regard_ent ON ids_regard_ent.id_itv = v_itv_details.id_reg_ent
                JOIN
                    itv.ids_reg ids_regard_sor ON ids_regard_sor.id_itv = v_itv_details.id_reg_sor
                JOIN
                    itv.%I reseau ON reseau.%I::text = ids_reseau.id_sig::text
                JOIN
                    itv.%I regard_ent ON regard_ent.%I::text = ids_regard_ent.id_sig::text
                JOIN
                    itv.%I regard_sor ON regard_sor.%I::text = ids_regard_sor.id_sig::text
                WHERE
                    v_itv_details.inspection_gid = %L
                    AND reseau.geom IS NOT NULL
                    AND regard_ent.geom IS NOT NULL
                    AND regard_sor.geom IS NOT NULL
                    AND fam_obs LIKE 'BCA'::text
            ),
            inspection_with_direction AS (
                SELECT
                    *,
                    CASE
                        WHEN srid = 4326 THEN
                            CASE
                                WHEN ST_Distance(
                                    ST_Transform(ST_StartPoint(troncon_geom), 2154), 
                                    ST_Transform(regard_entrant_geom, 2154)
                                ) < ST_Distance(
                                    ST_Transform(ST_StartPoint(troncon_geom), 2154), 
                                    ST_Transform(regard_sortant_geom, 2154)
                                )
                                THEN 'forward'
                                ELSE 'reverse'
                            END
                        ELSE
                            CASE
                                WHEN ST_Distance(ST_StartPoint(troncon_geom), regard_entrant_geom) < ST_Distance(ST_StartPoint(troncon_geom), regard_sortant_geom)
                                THEN 'forward'
                                ELSE 'reverse'
                            END
                    END AS direction
                FROM
                    inspection_data
            ),
            bcht_positions AS (
                SELECT
                    *,
                    CASE
                        WHEN srid = 4326 THEN
                            CASE
                                WHEN direction = 'forward'
                                THEN ST_LineInterpolatePoint(
                                    ST_Transform(troncon_geom, 2154), 
                                    LEAST(metrage, ST_Length(ST_Transform(troncon_geom, 2154))) / ST_Length(ST_Transform(troncon_geom, 2154))
                                )::geometry(Point, 2154)
                                ELSE ST_LineInterpolatePoint(
                                    ST_Reverse(ST_Transform(troncon_geom, 2154)), 
                                    LEAST(metrage, ST_Length(ST_Transform(troncon_geom, 2154))) / ST_Length(ST_Transform(troncon_geom, 2154))
                                )::geometry(Point, 2154)
                            END
                        ELSE
                            CASE
                                WHEN direction = 'forward'
                                THEN ST_LineInterpolatePoint(
                                    troncon_geom, 
                                    LEAST(metrage, ST_Length(troncon_geom)) / ST_Length(troncon_geom)
                                )::geometry(Point, %s)
                                ELSE ST_LineInterpolatePoint(
                                    ST_Reverse(troncon_geom), 
                                    LEAST(metrage, ST_Length(troncon_geom)) / ST_Length(troncon_geom)
                                )::geometry(Point, %s)
                            END
                    END AS pt_obs
                FROM
                    inspection_with_direction
            ),
            azimuths AS (
                SELECT *,
                    CASE
                        WHEN srid = 4326 THEN
                            ST_Azimuth(
                                ST_LineInterpolatePoint(ST_Transform(troncon_geom, 2154), 0.49),
                                ST_LineInterpolatePoint(ST_Transform(troncon_geom, 2154), 0.51)
                            )
                        ELSE
                            ST_Azimuth(
                                ST_LineInterpolatePoint(troncon_geom, 0.49),
                                ST_LineInterpolatePoint(troncon_geom, 0.51)
                            )
                    END AS azimuth
                FROM bcht_positions
            ),
            segments AS (
                SELECT
                    inspection_gid, id_reg_ent, id_reg_sor, sens_ecoul, type_obs, fam_obs, code_obs, libel_obs, orientatio,
                    CASE 
                        WHEN orientatio = '03h' OR orientatio = '04h' OR orientatio = '05h' THEN
                            ST_MakeLine(
                                ST_Project(pt_obs,0,azimuth - pi()/2),
                                ST_Project(pt_obs,3,azimuth - pi()/2)
                            )
                        WHEN orientatio IN ('06h','07h','08h','09h','10h','11h') THEN
                            ST_MakeLine(
                                ST_Project(pt_obs,0,azimuth + pi()/2),
                                ST_Project(pt_obs,3,azimuth + pi()/2)
                            )
                        WHEN orientatio = '12h' THEN
                            ST_MakeLine(
                                ST_Project(pt_obs,3,azimuth - pi()/2),
                                ST_Project(pt_obs,3,azimuth + pi()/2)
                            )
                        ELSE
                            ST_MakeLine(
                                pt_obs,
                                ST_Project(pt_obs, 3, azimuth)
                            )
                    END::geometry(LineString, 2154) AS geom
                FROM azimuths
            )
            SELECT * FROM segments WHERE geom IS NOT NULL
        $f$, srid, coll_table, coll_gid_column, reg_table, reg_gid_column, reg_table, reg_gid_column, inspection_gid_input, srid, srid);
    ELSE
        -- Sans collecteur
        sql_query := format($f$
            WITH base AS (
                SELECT 
                    v.inspection_gid,
                    v.id_reg_ent::text, v.id_reg_sor::text,
                    v.metrage::numeric, v.sens_ecoul::text,
                    v.type_obs::text, v.fam_obs::text,
                    v.code_obs::text, v.libel_obs::text,
                    v.orientatio::text,
                    ST_Transform(ST_GeometryN(r1.geom,1),2154) AS geom_ent,
                    ST_Transform(ST_GeometryN(r2.geom,1),2154) AS geom_sor,
                    ST_LineInterpolatePoint(
                        ST_MakeLine(
                            ST_Transform(ST_GeometryN(r1.geom,1),2154),
                            ST_Transform(ST_GeometryN(r2.geom,1),2154)
                        ),
                        LEAST(v.metrage,ST_Length(ST_MakeLine(ST_Transform(ST_GeometryN(r1.geom,1),2154),ST_Transform(ST_GeometryN(r2.geom,1),2154))))
                        /ST_Length(ST_MakeLine(ST_Transform(ST_GeometryN(r1.geom,1),2154),ST_Transform(ST_GeometryN(r2.geom,1),2154)))
                    ) AS pt_obs
                FROM itv.v_itv_details v
                JOIN itv.ids_reg re ON re.id_itv = v.id_reg_ent
                JOIN itv.ids_reg rs ON rs.id_itv = v.id_reg_sor
                JOIN itv.%I r1 ON r1.%I::text = re.id_sig::text
                JOIN itv.%I r2 ON r2.%I::text = rs.id_sig::text
                WHERE v.inspection_gid = %L AND v.fam_obs = 'BCA'
            ),
            avec_dir AS (
                SELECT *,
                    ST_Azimuth(geom_ent, geom_sor) AS azimuth
                FROM base
            ),
            segments AS (
                SELECT inspection_gid,id_reg_ent,id_reg_sor,
                       sens_ecoul,type_obs,fam_obs,code_obs,libel_obs,orientatio,
                    CASE 
                        WHEN orientatio = '03h' OR orientatio = '04h' OR orientatio = '05h' THEN
                            ST_MakeLine(
                                ST_Project(pt_obs,0,azimuth - pi()/2),
                                ST_Project(pt_obs,3,azimuth - pi()/2)
                            )
                        WHEN orientatio IN ('06h','07h','08h','09h','10h','11h') THEN
                            ST_MakeLine(
                                ST_Project(pt_obs,0,azimuth + pi()/2),
                                ST_Project(pt_obs,3,azimuth + pi()/2)
                            )
                        WHEN orientatio = '12h' THEN
                            ST_MakeLine(
                                ST_Project(pt_obs,3,azimuth - pi()/2),
                                ST_Project(pt_obs,3,azimuth + pi()/2)
                            )
                        ELSE NULL
                    END AS geom
                FROM avec_dir
            )
            SELECT * FROM segments WHERE geom IS NOT NULL
        $f$, reg_table, reg_gid_column, reg_table, reg_gid_column, inspection_gid_input);
    END IF;

    -- Exécution
    RETURN QUERY EXECUTE sql_query;
END;
$_$;


ALTER FUNCTION itv.get_bcht_lines(inspection_gid_input integer) OWNER TO postgres;

--
-- TOC entry 973 (class 1255 OID 49159)
-- Name: get_bcht_positions(integer); Type: FUNCTION; Schema: itv; Owner: postgres
--

CREATE FUNCTION itv.get_bcht_positions(inspection_gid_input integer) RETURNS TABLE(inspection_gid integer, id_reg_ent text, id_reg_sor text, x double precision, y double precision, sens_ecoul text, type_obs text, fam_obs text, code_obs text, libel_obs text, orientatio text, geom public.geometry)
    LANGUAGE plpgsql
    AS $$
DECLARE
    coll_table text;
    coll_gid_column text;
    reg_table text;
    reg_gid_column text;
    v_shp_reg_id_fieldname text;
    v_shp_coll_id_fieldname text;
    sql_query text;
    srid integer;
BEGIN
    -- Récupérer les noms des tables et des champs personnalisés depuis itv.inspection
    SELECT shp_coll_table, shp_reg_table, shp_reg_id_fieldname, shp_coll_id_fieldname
    INTO coll_table, reg_table, v_shp_reg_id_fieldname, v_shp_coll_id_fieldname
    FROM itv.inspection
    WHERE gid = inspection_gid_input;
    
    -- Déterminer la colonne à utiliser pour la table de collecte
    IF coll_table IS NOT NULL AND trim(coll_table) <> '' THEN
        IF v_shp_coll_id_fieldname IS NOT NULL AND trim(v_shp_coll_id_fieldname) <> '' THEN
            coll_gid_column := v_shp_coll_id_fieldname;
        ELSE
            SELECT column_name INTO coll_gid_column
            FROM information_schema.columns
            WHERE table_schema = 'itv' AND table_name = coll_table AND column_name IN ('numero', 'ident', 'gid')
            LIMIT 1;
        END IF;
    END IF;

    -- Déterminer la colonne à utiliser pour la table de regard
    IF reg_table IS NOT NULL AND trim(reg_table) <> '' THEN
        IF v_shp_reg_id_fieldname IS NOT NULL AND trim(v_shp_reg_id_fieldname) <> '' THEN
            reg_gid_column := v_shp_reg_id_fieldname;
        ELSE
            SELECT column_name INTO reg_gid_column
            FROM information_schema.columns
            WHERE table_schema = 'itv' AND table_name = reg_table AND column_name IN ('numero', 'ident', 'gid')
            LIMIT 1;
        END IF;
    END IF;
				
				-- Récupérer le SRID des géométries de la table de collecte si présente, sinon des regards
    IF coll_table IS NOT NULL AND trim(coll_table) <> '' THEN
        EXECUTE format('SELECT ST_SRID(geom) FROM itv.%I LIMIT 1', coll_table) INTO srid;
    ELSE
        EXECUTE format('SELECT ST_SRID(geom) FROM itv.%I LIMIT 1', reg_table) INTO srid;
    END IF;

                -- Construire la requête SQL dynamique selon la présence du collecteur
    IF coll_table IS NOT NULL AND trim(coll_table) <> '' THEN
        -- Avec collecteur (comportement actuel)
        sql_query := format('
            WITH inspection_data AS (
                SELECT
                    v_itv_details.inspection_gid,
                    v_itv_details.id_reg_ent::text,
                    v_itv_details.id_reg_sor::text,
                    v_itv_details.id_troncon::text,
                    v_itv_details.metrage::numeric,
                    v_itv_details.n_passage::text,
                    v_itv_details.sens_ecoul::text,
                    v_itv_details.type_obs::text,
                    v_itv_details.fam_obs::text,
                    v_itv_details.code_obs::text,
                    v_itv_details.libel_obs::text,
                    v_itv_details.quan_charg::text,
                    v_itv_details.rmq_obs::text,
                    v_itv_details.orientatio::text,
                    v_itv_details.precipitat::text,
                    v_itv_details.photo::text,
                    v_itv_details.video::text,
                    v_itv_details.video_tps::text,
                    v_itv_details.date_obs::text,
                    ST_LineMerge(reseau.geom) AS troncon_geom,
                    regard_ent.geom AS regard_entrant_geom,
                    regard_sor.geom AS regard_sortant_geom,
                    CAST(%s AS integer) AS srid
                FROM
                    itv.v_itv_details
				JOIN
					itv.ids_coll ids_reseau ON ids_reseau.id_itv = v_itv_details.id_troncon
				JOIN
					itv.ids_reg ids_regard_ent ON ids_regard_ent.id_itv = v_itv_details.id_reg_ent
				JOIN
					itv.ids_reg ids_regard_sor ON ids_regard_sor.id_itv = v_itv_details.id_reg_sor
                JOIN
                    itv.%I reseau ON reseau.%I::text = ids_reseau.id_sig::text
                JOIN
                    itv.%I regard_ent ON regard_ent.%I::text = ids_regard_ent.id_sig::text
                JOIN
                    itv.%I regard_sor ON regard_sor.%I::text = ids_regard_sor.id_sig::text
                WHERE
                    v_itv_details.inspection_gid = %L
                    AND reseau.geom IS NOT NULL
                    AND regard_ent.geom IS NOT NULL
                    AND regard_sor.geom IS NOT NULL
                    AND fam_obs LIKE ''BCA''::text
            ),
            inspection_with_direction AS (
                SELECT
                    *,
                    CASE
						WHEN srid = 4326 THEN
							CASE
								WHEN ST_Distance(
									ST_Transform(ST_StartPoint(troncon_geom), 2154), 
									ST_Transform(regard_entrant_geom, 2154)
								) < ST_Distance(
									ST_Transform(ST_StartPoint(troncon_geom), 2154), 
									ST_Transform(regard_sortant_geom, 2154)
								)
								THEN ''forward''
								ELSE ''reverse''
							END
						ELSE
							CASE
								WHEN ST_Distance(ST_StartPoint(troncon_geom), regard_entrant_geom) < ST_Distance(ST_StartPoint(troncon_geom), regard_sortant_geom)
								THEN ''forward''
								ELSE ''reverse''
							END
                    END AS direction
                FROM
                    inspection_data
            ),
            bcht_positions AS (
                SELECT
                    *,
                    CASE
                        WHEN srid = 4326 THEN
                            CASE
                                WHEN direction = ''forward''
                                THEN ST_LineInterpolatePoint(
                                    ST_Transform(troncon_geom, 2154), 
                                    LEAST(metrage, ST_Length(ST_Transform(troncon_geom, 2154))) / ST_Length(ST_Transform(troncon_geom, 2154))
                                )::geometry(Point, 2154)
                                ELSE ST_LineInterpolatePoint(
                                    ST_Reverse(ST_Transform(troncon_geom, 2154)), 
                                    LEAST(metrage, ST_Length(ST_Transform(troncon_geom, 2154))) / ST_Length(ST_Transform(troncon_geom, 2154))
                                )::geometry(Point, 2154)
                            END
                        ELSE
                            CASE
                                WHEN direction = ''forward''
                                THEN ST_LineInterpolatePoint(
                                    troncon_geom, 
                                    LEAST(metrage, ST_Length(troncon_geom)) / ST_Length(troncon_geom)
                                )::geometry(Point, %s)
                                ELSE ST_LineInterpolatePoint(
                                    ST_Reverse(troncon_geom), 
                                    LEAST(metrage, ST_Length(troncon_geom)) / ST_Length(troncon_geom)
                                )::geometry(Point, %s)
                            END
                    END AS geom
                FROM
                    inspection_with_direction
            )
            SELECT DISTINCT
                inspection_gid,
                id_reg_ent,
                id_reg_sor,
                ST_X(geom) AS x, -- Extraction de la coordonnée X
                ST_Y(geom) AS y,  -- Extraction de la coordonnée Y
                sens_ecoul,
                type_obs,
                fam_obs,
                code_obs AS code,
                libel_obs AS libelle,
                orientatio,
				CASE
					WHEN srid = 4326 THEN ST_Transform(geom, 4326)
					ELSE geom
				END AS geom -- Transformation en WGS84 si nécessaire
            FROM
                bcht_positions;
        ', srid, coll_table, coll_gid_column, reg_table, reg_gid_column, reg_table, reg_gid_column, inspection_gid_input, srid, srid);
    ELSE
        -- Sans collecteur : interpolation entre les deux regards
        sql_query := format('
            WITH inspection_data AS (
                SELECT
                    v_itv_details.inspection_gid,
                    v_itv_details.id_reg_ent::text,
                    v_itv_details.id_reg_sor::text,
                    v_itv_details.metrage::numeric,
                    v_itv_details.sens_ecoul::text,
                    v_itv_details.type_obs::text,
                    v_itv_details.fam_obs::text,
                    v_itv_details.code_obs::text,
                    v_itv_details.libel_obs::text,
                    v_itv_details.orientatio::text,
                    ST_GeometryN(regard_ent.geom,1) AS regard_entrant_geom,
                    ST_GeometryN(regard_sor.geom,1) AS regard_sortant_geom,
                    CAST(%s AS integer) AS srid
                FROM
                    itv.v_itv_details
                JOIN
                    itv.ids_reg ids_regard_ent ON ids_regard_ent.id_itv = v_itv_details.id_reg_ent
                JOIN
                    itv.ids_reg ids_regard_sor ON ids_regard_sor.id_itv = v_itv_details.id_reg_sor
                JOIN
                    itv.%I regard_ent ON regard_ent.%I::text = ids_regard_ent.id_sig::text
                JOIN
                    itv.%I regard_sor ON regard_sor.%I::text = ids_regard_sor.id_sig::text
                WHERE
                    v_itv_details.inspection_gid = %L
                    AND regard_ent.geom IS NOT NULL
                    AND regard_sor.geom IS NOT NULL
                    AND fam_obs LIKE ''BCA''::text
            ),
            bcht_positions AS (
                SELECT
                    *,
                    CASE
                        WHEN srid = 4326 THEN
                            ST_LineInterpolatePoint(
                                ST_MakeLine(
                                    ST_Transform(ST_GeometryN(regard_entrant_geom,1), 2154),
                                    ST_Transform(ST_GeometryN(regard_sortant_geom,1), 2154)
                                ),
                                LEAST(metrage, ST_Length(ST_MakeLine(ST_Transform(ST_GeometryN(regard_entrant_geom,1), 2154), ST_Transform(ST_GeometryN(regard_sortant_geom,1), 2154)))) / ST_Length(ST_MakeLine(ST_Transform(ST_GeometryN(regard_entrant_geom,1), 2154), ST_Transform(ST_GeometryN(regard_sortant_geom,1), 2154)))
                            )::geometry(Point, 2154)
                        ELSE
                            ST_LineInterpolatePoint(
                                ST_MakeLine(ST_GeometryN(regard_entrant_geom,1), ST_GeometryN(regard_sortant_geom,1)),
                                LEAST(metrage, ST_Length(ST_MakeLine(ST_GeometryN(regard_entrant_geom,1), ST_GeometryN(regard_sortant_geom,1)))) / ST_Length(ST_MakeLine(ST_GeometryN(regard_entrant_geom,1), ST_GeometryN(regard_sortant_geom,1)))
                            )::geometry(Point, %s)
                    END AS geom
                FROM
                    inspection_data
            )
            SELECT DISTINCT
                inspection_gid,
                id_reg_ent,
                id_reg_sor,
                ST_X(geom) AS x,
                ST_Y(geom) AS y,
                sens_ecoul,
                type_obs,
                fam_obs,
                code_obs AS code,
                libel_obs AS libelle,
                orientatio,
                CASE
                    WHEN srid = 4326 THEN ST_Transform(geom, 4326)
                    ELSE geom
                END AS geom
            FROM
                bcht_positions;
        ', srid, reg_table, reg_gid_column, reg_table, reg_gid_column, inspection_gid_input, srid);
    END IF;

    -- Exécuter la requête SQL dynamique
    RETURN QUERY EXECUTE sql_query;
END;
$$;


ALTER FUNCTION itv.get_bcht_positions(inspection_gid_input integer) OWNER TO postgres;

--
-- TOC entry 974 (class 1255 OID 49161)
-- Name: get_defect_positions(integer); Type: FUNCTION; Schema: itv; Owner: postgres
--

CREATE FUNCTION itv.get_defect_positions(inspection_gid_input integer) RETURNS TABLE(inspection_gid integer, id_reg_ent text, id_reg_sor text, id_troncon text, metrage numeric, x double precision, y double precision, n_passage text, sens_ecoul text, type_obs text, fam_obs text, code_obs text, libel_obs text, quan_charg text, rmq_obs text, orientatio text, precipitat text, photo text, video text, video_tps text, date_obs text, code_insee character varying, geom public.geometry)
    LANGUAGE plpgsql
    AS $$
DECLARE
    coll_table text;
    coll_gid_column text;
    reg_table text;
    reg_gid_column text;
    v_shp_reg_id_fieldname text;
    v_shp_coll_id_fieldname text;
    sql_query text;
    srid integer;
BEGIN
    -- Récupérer les noms des tables et des champs personnalisés depuis itv.inspection
    SELECT shp_coll_table, shp_reg_table, shp_reg_id_fieldname, shp_coll_id_fieldname
    INTO coll_table, reg_table, v_shp_reg_id_fieldname, v_shp_coll_id_fieldname
    FROM itv.inspection
    WHERE gid = inspection_gid_input;
    
    -- Déterminer la colonne à utiliser pour la table de collecte
    IF coll_table IS NOT NULL AND trim(coll_table) <> '' THEN
        IF v_shp_coll_id_fieldname IS NOT NULL AND trim(v_shp_coll_id_fieldname) <> '' THEN
            coll_gid_column := v_shp_coll_id_fieldname;
        ELSE
            SELECT column_name INTO coll_gid_column
            FROM information_schema.columns
            WHERE table_schema = 'itv' AND table_name = coll_table AND column_name IN ('numero', 'ident', 'gid')
            LIMIT 1;
        END IF;
    END IF;

    -- Déterminer la colonne à utiliser pour la table de regard
    IF reg_table IS NOT NULL AND trim(reg_table) <> '' THEN
        IF v_shp_reg_id_fieldname IS NOT NULL AND trim(v_shp_reg_id_fieldname) <> '' THEN
            reg_gid_column := v_shp_reg_id_fieldname;
        ELSE
            SELECT column_name INTO reg_gid_column
            FROM information_schema.columns
            WHERE table_schema = 'itv' AND table_name = reg_table AND column_name IN ('numero', 'ident', 'gid')
            LIMIT 1;
        END IF;
    END IF;

    -- Récupérer le SRID des géométries de la table de collecte si présente, sinon des regards
    IF coll_table IS NOT NULL AND trim(coll_table) <> '' THEN
        EXECUTE format('SELECT ST_SRID(geom) FROM itv.%I LIMIT 1', coll_table) INTO srid;
    ELSE
        EXECUTE format('SELECT ST_SRID(geom) FROM itv.%I LIMIT 1', reg_table) INTO srid;
    END IF;

    -- Construire la requête SQL dynamique selon la présence du collecteur
    IF coll_table IS NOT NULL AND trim(coll_table) <> '' THEN
        -- Avec collecteur (comportement actuel)
        sql_query := format('
            WITH inspection_data AS (
                SELECT
                    v_itv_details.inspection_gid,
                    v_itv_details.id_reg_ent::text,
                    v_itv_details.id_reg_sor::text,
                    v_itv_details.id_troncon::text,
                    v_itv_details.metrage::numeric,
                    v_itv_details.n_passage::text,
                    v_itv_details.sens_ecoul::text,
                    v_itv_details.type_obs::text,
                    v_itv_details.fam_obs::text,
                    v_itv_details.code_obs::text,
                    v_itv_details.libel_obs::text,
                    v_itv_details.quan_charg::text,
                    v_itv_details.rmq_obs::text,
                    v_itv_details.orientatio::text,
                    v_itv_details.precipitat::text,
                    v_itv_details.photo::text,
                    v_itv_details.video::text,
                    v_itv_details.video_tps::text,
                    v_itv_details.date_obs::text,
                    ST_LineMerge(reseau.geom) AS troncon_geom,
                    regard_ent.geom AS regard_entrant_geom,
                    regard_sor.geom AS regard_sortant_geom,
                    CAST(%s AS integer) AS srid
                FROM
                    itv.v_itv_details
                JOIN
                    itv.ids_coll ids_reseau ON ids_reseau.id_itv = v_itv_details.id_troncon AND ids_reseau.id_sig IS NOT NULL
                JOIN
                    itv.ids_reg ids_regard_ent ON ids_regard_ent.id_itv = v_itv_details.id_reg_ent AND ids_regard_ent.id_sig IS NOT NULL
                JOIN
                    itv.ids_reg ids_regard_sor ON ids_regard_sor.id_itv = v_itv_details.id_reg_sor AND ids_regard_sor.id_sig IS NOT NULL
                JOIN
                    itv.%I reseau ON reseau.%I::text = ids_reseau.id_sig::text
                JOIN
                    itv.%I regard_ent ON regard_ent.%I::text = ids_regard_ent.id_sig::text
                JOIN
                    itv.%I regard_sor ON regard_sor.%I::text = ids_regard_sor.id_sig::text
                WHERE
                    v_itv_details.inspection_gid = %L
                    AND reseau.geom IS NOT NULL
                    AND regard_ent.geom IS NOT NULL
                    AND regard_sor.geom IS NOT NULL
                    AND fam_obs !~~ ''BCA''::text
            ),
            inspection_with_direction AS (
                SELECT
                    *,
                    CASE
                        WHEN srid = 4326 THEN
                            CASE
                                WHEN ST_Distance(
                                    ST_Transform(ST_StartPoint(troncon_geom), 2154),
                                    ST_Transform(regard_entrant_geom, 2154)
                                ) < ST_Distance(
                                    ST_Transform(ST_StartPoint(troncon_geom), 2154),
                                    ST_Transform(regard_sortant_geom, 2154)
                                )
                                THEN ''forward''
                                ELSE ''reverse''
                            END
                        ELSE
                            CASE
                                WHEN ST_Distance(ST_StartPoint(troncon_geom), regard_entrant_geom) < ST_Distance(ST_StartPoint(troncon_geom), regard_sortant_geom)
                                THEN ''forward''
                                ELSE ''reverse''
                            END
                    END AS direction
                FROM
                    inspection_data
            ),
            defect_positions AS (
                SELECT
                    *,
                    CASE
                        WHEN srid = 4326 THEN
                            CASE
                                WHEN direction = ''forward''
                                THEN ST_LineInterpolatePoint(
                                    ST_Transform(troncon_geom, 2154),
                                    LEAST(metrage, ST_Length(ST_Transform(troncon_geom, 2154))) / ST_Length(ST_Transform(troncon_geom, 2154))
                                )::geometry(Point, 2154)
                                ELSE ST_LineInterpolatePoint(
                                    ST_Reverse(ST_Transform(troncon_geom, 2154)),
                                    LEAST(metrage, ST_Length(ST_Transform(troncon_geom, 2154))) / ST_Length(ST_Transform(troncon_geom, 2154))
                                )::geometry(Point, 2154)
                            END
                        ELSE
                            CASE
                                WHEN direction = ''forward''
                                THEN ST_LineInterpolatePoint(
                                    troncon_geom,
                                    LEAST(metrage, ST_Length(troncon_geom)) / ST_Length(troncon_geom)
                                )::geometry(Point, %s)
                                ELSE ST_LineInterpolatePoint(
                                    ST_Reverse(troncon_geom),
                                    LEAST(metrage, ST_Length(troncon_geom)) / ST_Length(troncon_geom)
                                )::geometry(Point, %s)
                            END
                    END AS geom
                FROM
                    inspection_with_direction
            ),
            defect_positions_with_code_insee AS (
                SELECT
                    dp.*,
                    c.insee_com
                FROM
                    defect_positions dp
                LEFT JOIN
                    itv.commune c ON ST_Intersects(dp.geom, c.geom)
            )
            SELECT DISTINCT
                inspection_gid,
                id_reg_ent,
                id_reg_sor,
                id_troncon,
                metrage,
                ST_X(geom) AS x,
                ST_Y(geom) AS y,
                n_passage,
                sens_ecoul,
                type_obs,
                fam_obs,
                code_obs,
                libel_obs,
                quan_charg,
                rmq_obs,
                orientatio,
                precipitat,
                photo,
                video,
                video_tps,
                date_obs,
                insee_com AS code_insee,
                CASE
                    WHEN srid = 4326 THEN ST_Transform(geom, 4326)
                    ELSE geom
                END AS geom
            FROM
                defect_positions_with_code_insee;
        ', srid, coll_table, coll_gid_column, reg_table, reg_gid_column, reg_table, reg_gid_column, inspection_gid_input, srid, srid);
    ELSE
        -- Sans collecteur : interpolation entre les deux regards
        sql_query := format('
            WITH inspection_data AS (
                SELECT
                    v_itv_details.inspection_gid,
                    v_itv_details.id_reg_ent::text,
                    v_itv_details.id_reg_sor::text,
                    NULL::text AS id_troncon,
                    v_itv_details.metrage::numeric,
                    v_itv_details.n_passage::text,
                    v_itv_details.sens_ecoul::text,
                    v_itv_details.type_obs::text,
                    v_itv_details.fam_obs::text,
                    v_itv_details.code_obs::text,
                    v_itv_details.libel_obs::text,
                    v_itv_details.quan_charg::text,
                    v_itv_details.rmq_obs::text,
                    v_itv_details.orientatio::text,
                    v_itv_details.precipitat::text,
                    v_itv_details.photo::text,
                    v_itv_details.video::text,
                    v_itv_details.video_tps::text,
                    v_itv_details.date_obs::text,
                    ST_GeometryN(regard_ent.geom,1) AS regard_entrant_geom,
                    ST_GeometryN(regard_sor.geom,1) AS regard_sortant_geom,
                    CAST(%s AS integer) AS srid
                FROM
                    itv.v_itv_details
                JOIN
                    itv.ids_reg ids_regard_ent ON ids_regard_ent.id_itv = v_itv_details.id_reg_ent AND ids_regard_ent.id_sig IS NOT NULL
                JOIN
                    itv.ids_reg ids_regard_sor ON ids_regard_sor.id_itv = v_itv_details.id_reg_sor AND ids_regard_sor.id_sig IS NOT NULL
                JOIN
                    itv.%I regard_ent ON regard_ent.%I::text = ids_regard_ent.id_sig::text
                JOIN
                    itv.%I regard_sor ON regard_sor.%I::text = ids_regard_sor.id_sig::text
                WHERE
                    v_itv_details.inspection_gid = %L
                    AND regard_ent.geom IS NOT NULL
                    AND regard_sor.geom IS NOT NULL
                    AND fam_obs !~~ ''BCA''::text
            ),
            defect_positions AS (
                SELECT
                    *,
                    CASE
                        WHEN srid = 4326 THEN
                            CASE
                                WHEN ST_Length(ST_MakeLine(ST_Transform(regard_entrant_geom, 2154), ST_Transform(regard_sortant_geom, 2154))) > 0 THEN
                                    ST_LineInterpolatePoint(
                                        ST_MakeLine(
                                            ST_Transform(regard_entrant_geom, 2154),
                                            ST_Transform(regard_sortant_geom, 2154)
                                        ),
                                        LEAST(metrage, ST_Length(ST_MakeLine(ST_Transform(regard_entrant_geom, 2154), ST_Transform(regard_sortant_geom, 2154)))) / ST_Length(ST_MakeLine(ST_Transform(regard_entrant_geom, 2154), ST_Transform(regard_sortant_geom, 2154)))
                                    )::geometry(Point, 2154)
                                ELSE
                                    ST_Transform(regard_entrant_geom, 2154)
                            END
                        ELSE
                            CASE
                                WHEN ST_Length(ST_MakeLine(regard_entrant_geom, regard_sortant_geom)) > 0 THEN
                                    ST_LineInterpolatePoint(
                                        ST_MakeLine(regard_entrant_geom, regard_sortant_geom),
                                        LEAST(metrage, ST_Length(ST_MakeLine(regard_entrant_geom, regard_sortant_geom))) / ST_Length(ST_MakeLine(regard_entrant_geom, regard_sortant_geom))
                                    )::geometry(Point, %s)
                                ELSE
                                    regard_entrant_geom
                            END
                    END AS geom
                FROM
                    inspection_data
            ),
            defect_positions_with_code_insee AS (
                SELECT
                    dp.*,
                    c.insee_com
                FROM
                    defect_positions dp
                LEFT JOIN
                    itv.commune c ON ST_Intersects(dp.geom, c.geom)
            )
            SELECT DISTINCT
                inspection_gid,
                id_reg_ent,
                id_reg_sor,
                id_troncon,
                metrage,
                ST_X(geom) AS x,
                ST_Y(geom) AS y,
                n_passage,
                sens_ecoul,
                type_obs,
                fam_obs,
                code_obs,
                libel_obs,
                quan_charg,
                rmq_obs,
                orientatio,
                precipitat,
                photo,
                video,
                video_tps,
                date_obs,
                insee_com AS code_insee,
                CASE
                    WHEN srid = 4326 THEN ST_Transform(geom, 4326)
                    ELSE geom
                END AS geom
            FROM
                defect_positions_with_code_insee;
        ', srid, reg_table, reg_gid_column, reg_table, reg_gid_column, inspection_gid_input, srid);
    END IF;

    -- Exécuter la requête SQL dynamique
    RETURN QUERY EXECUTE sql_query;
END;
$$;


ALTER FUNCTION itv.get_defect_positions(inspection_gid_input integer) OWNER TO postgres;

--
-- TOC entry 975 (class 1255 OID 49163)
-- Name: get_id_sig(text, character varying, integer); Type: FUNCTION; Schema: itv; Owner: postgres
--

CREATE FUNCTION itv.get_id_sig(table_name text, id_itv character varying, inspection integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
    id_sig text;
BEGIN
    EXECUTE format('SELECT id_sig FROM itv.%I WHERE id_itv = $1 AND inspection_gid = $2 LIMIT 1', table_name)
    INTO id_sig
    USING id_itv, inspection;

    RETURN id_sig;
END;
$_$;


ALTER FUNCTION itv.get_id_sig(table_name text, id_itv character varying, inspection integer) OWNER TO postgres;

--
-- TOC entry 976 (class 1255 OID 49164)
-- Name: get_inspection_data(integer); Type: FUNCTION; Schema: itv; Owner: postgres
--

CREATE FUNCTION itv.get_inspection_data(inspection_gid_input integer) RETURNS TABLE(inspection_gid integer, nature_res character varying, type_eau character varying, date_deb date, date_fin date, entreprise text, longueur numeric, nom_plan text, nom_rapport text, nom_txt text, remarques text, geom public.geometry)
    LANGUAGE plpgsql
    AS $$
DECLARE
    coll_table text;
    reg_table text;
    coll_gid_column text;
    reg_gid_column text;
    v_shp_reg_id_fieldname text;
    v_shp_coll_id_fieldname text;
    geom_coll geometry;
    geom_reg geometry;
    srid integer;
BEGIN
    -- Récupérer les noms des tables et des champs personnalisés depuis itv.inspection
    SELECT shp_coll_table, shp_reg_table, shp_reg_id_fieldname, shp_coll_id_fieldname
    INTO coll_table, reg_table, v_shp_reg_id_fieldname, v_shp_coll_id_fieldname
    FROM itv.inspection
    WHERE gid = inspection_gid_input;
    
    -- Déterminer la colonne à utiliser pour la table de collecte
    IF coll_table IS NOT NULL AND trim(coll_table) <> '' THEN
        IF v_shp_coll_id_fieldname IS NOT NULL AND trim(v_shp_coll_id_fieldname) <> '' THEN
            coll_gid_column := v_shp_coll_id_fieldname;
        ELSE
            SELECT column_name INTO coll_gid_column
            FROM information_schema.columns
            WHERE table_schema = 'itv' AND table_name = coll_table AND column_name IN ('numero', 'ident', 'gid')
            LIMIT 1;
        END IF;
    END IF;

    -- Déterminer la colonne à utiliser pour la table de regard
    IF reg_table IS NOT NULL AND trim(reg_table) <> '' THEN
        IF v_shp_reg_id_fieldname IS NOT NULL AND trim(v_shp_reg_id_fieldname) <> '' THEN
            reg_gid_column := v_shp_reg_id_fieldname;
        ELSE
            SELECT column_name INTO reg_gid_column
            FROM information_schema.columns
            WHERE table_schema = 'itv' AND table_name = reg_table AND column_name IN ('numero', 'ident', 'gid')
            LIMIT 1;
        END IF;
    END IF;

    -- Récupérer le SRID des géométries
    IF coll_table IS NOT NULL AND trim(coll_table) <> '' THEN
        EXECUTE format('SELECT ST_SRID(geom) FROM itv.%I LIMIT 1', coll_table) INTO srid;
    ELSE
        EXECUTE format('SELECT ST_SRID(geom) FROM itv.%I LIMIT 1', reg_table) INTO srid;
    END IF;

    -- Calcul des géométries selon la présence du collecteur
    IF coll_table IS NOT NULL AND trim(coll_table) <> '' THEN
        -- Géométrie du collecteur
        EXECUTE format('
            SELECT st_union(geom)
            FROM itv.%I
            WHERE %I::text IN (
                SELECT v_itv_physiq_coll.id_sig
                FROM itv.v_itv_physiq_coll
                WHERE v_itv_physiq_coll.id_troncon::text IN (
                    SELECT v_itv_details.id_troncon
                    FROM itv.v_itv_details
                    WHERE v_itv_details.inspection_gid = %L
                )
            )', coll_table, coll_gid_column, inspection_gid_input) INTO geom_coll;
    ELSE
        geom_coll := NULL;
    END IF;

    -- Géométrie des regards
    EXECUTE format('
        SELECT st_union(geom)
        FROM itv.%I
        WHERE %I::text IN (
            SELECT v_itv_physiq_reg.id_sig
            FROM itv.v_itv_physiq_reg
            WHERE v_itv_physiq_reg.id_regard IN (
                SELECT v_itv_details.id_reg_ent
                FROM itv.v_itv_details
                WHERE v_itv_details.inspection_gid = %L
            ) OR v_itv_physiq_reg.id_regard IN (
                SELECT v_itv_details.id_reg_sor
                FROM itv.v_itv_details
                WHERE v_itv_details.inspection_gid = %L
            )
        )', reg_table, reg_gid_column, inspection_gid_input, inspection_gid_input) INTO geom_reg;

    -- Si geom_reg est un point, buffer pour créer un polygone
    IF ST_GeometryType(geom_reg) = 'ST_Point' THEN
        geom_reg := ST_Buffer(geom_reg, 0.0001);
    END IF;

    -- Calcul du polygone d'inspection selon la présence du collecteur
    IF geom_coll IS NOT NULL THEN
        geom := ST_Envelope(ST_Union(ARRAY[geom_coll, geom_reg]));
    ELSE
        geom := ST_Envelope(geom_reg);
    END IF;

    -- Sélectionner les autres champs et retourner le résultat
    RETURN QUERY EXECUTE format('
        SELECT 
            inspection.gid AS inspection_gid,
            NULL::character varying(2) AS nature_res,
            NULL::character varying(2) AS type_eau,
            (SELECT min("B02_2"."ABF") AS max
            FROM itv."B02" "B02_2",
                itv.passage passage_2
            WHERE passage_2.gid = "B02_2".passage_gid 
            AND passage_2.inspection_gid = inspection.gid) AS date_deb,
            (SELECT max("B02_1"."ABF") AS max
            FROM itv."B02" "B02_1",
                itv.passage passage_1
            WHERE passage_1.gid = "B02_1".passage_gid 
            AND passage_1.inspection_gid = inspection.gid) AS date_fin,
            inspection.entreprise::text,
            sum("B03"."ACG")::numeric AS longueur,
            inspection.pdf_filename::text AS nom_plan,
            inspection.pdf_filename::text AS nom_rapport,
            inspection.file::text AS nom_txt,
            string_agg("B04"."ADE"::text, ''''::text) AS remarques,
            %L::geometry(Polygon, %s) AS geom
        FROM 
            itv."B01",
            itv."B02",
            itv."B03",
            itv."B04",
            itv.passage,
            itv.inspection
        WHERE 
            "B01".passage_gid = passage.gid 
            AND "B02".passage_gid = passage.gid 
            AND "B03".passage_gid = passage.gid 
            AND "B04".passage_gid = passage.gid 
            AND passage.inspection_gid = inspection.gid
            AND inspection.gid = %s

        GROUP BY 
            inspection.gid', geom, srid, inspection_gid_input);
END;
            
$$;


ALTER FUNCTION itv.get_inspection_data(inspection_gid_input integer) OWNER TO postgres;

--
-- TOC entry 977 (class 1255 OID 49166)
-- Name: get_longueur_troncon_sig(character varying, integer); Type: FUNCTION; Schema: itv; Owner: postgres
--

CREATE FUNCTION itv.get_longueur_troncon_sig(id_sig character varying, inspection_gid_input integer) RETURNS double precision
    LANGUAGE plpgsql
    AS $_$
DECLARE
    coll_table text;
    coll_gid_column text;
    v_shp_coll_id_fieldname text;
	v_length double precision;
    v_sql text;
	srid integer;
BEGIN

    -- Récupérer les noms des tables et des champs personnalisés depuis itv.inspection
    SELECT shp_coll_table, shp_coll_id_fieldname
    INTO coll_table, v_shp_coll_id_fieldname
    FROM itv.inspection
    WHERE gid = inspection_gid_input;

    -- Si pas de table collecteur, retourner NULL
    IF coll_table IS NULL OR trim(coll_table) = '' THEN
        RETURN NULL;
    END IF;

    -- Déterminer la colonne à utiliser pour la table de collecte
    IF v_shp_coll_id_fieldname IS NOT NULL AND trim(v_shp_coll_id_fieldname) <> '' THEN
        coll_gid_column := v_shp_coll_id_fieldname;
    ELSE
        SELECT column_name INTO coll_gid_column
        FROM information_schema.columns
        WHERE table_schema = 'itv' AND table_name = coll_table AND column_name IN ('gid')
        LIMIT 1;
    END IF;

    -- Récupérer le SRID de la géométrie de la table de collecte
    EXECUTE format('SELECT ST_SRID(geom) FROM itv.%I WHERE geom IS NOT NULL LIMIT 1', coll_table)
    INTO srid;

    -- Construire la requête SQL dynamique en fonction du SRID
    IF srid = 4326 THEN
        -- Transformer la géométrie en 2154 pour une mesure en mètres
        v_sql := format($f$
            SELECT ST_Length(ST_Transform(geom, 2154)) 
            FROM itv.%I 
            WHERE %I = $1
        $f$, coll_table, coll_gid_column);
    ELSE
        -- SRID déjà métrique : pas besoin de transformer
        v_sql := format($f$
            SELECT ST_Length(geom)
            FROM itv.%I 
            WHERE %I = $1
        $f$, coll_table, coll_gid_column);
    END IF;

    -- Exécuter la requête avec id_sig comme paramètre
    EXECUTE v_sql INTO v_length USING id_sig;

    -- Retourner la longueur
    RETURN ROUND(v_length::numeric, 2);

END;
$_$;


ALTER FUNCTION itv.get_longueur_troncon_sig(id_sig character varying, inspection_gid_input integer) OWNER TO postgres;

--
-- TOC entry 978 (class 1255 OID 49167)
-- Name: set_id_sig(integer); Type: FUNCTION; Schema: itv; Owner: postgres
--

CREATE FUNCTION itv.set_id_sig(inspection_gid_input integer) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
    coll_table text;
    reg_table text;
    coll_gid_column text;
    reg_gid_column text;
    v_shp_reg_id_fieldname text;
    v_shp_coll_id_fieldname text;
BEGIN

    -- Récupérer les noms des tables et des champs personnalisés depuis itv.inspection
    SELECT shp_coll_table, shp_reg_table, shp_reg_id_fieldname, shp_coll_id_fieldname
    INTO coll_table, reg_table, v_shp_reg_id_fieldname, v_shp_coll_id_fieldname
    FROM itv.inspection
    WHERE gid = inspection_gid_input;
    
    -- Déterminer la colonne à utiliser pour la table de collecte
															 
    IF v_shp_coll_id_fieldname IS NOT NULL AND trim(v_shp_coll_id_fieldname) <> '' THEN
        coll_gid_column := v_shp_coll_id_fieldname;
    ELSE
        SELECT column_name INTO coll_gid_column
        FROM information_schema.columns
        WHERE table_schema = 'itv' AND table_name = coll_table AND column_name IN ('gid')
        LIMIT 1;
			   
    END IF;

    -- Déterminer la colonne à utiliser pour la table de regard
														   
    IF v_shp_reg_id_fieldname IS NOT NULL AND trim(v_shp_reg_id_fieldname) <> '' THEN
        reg_gid_column := v_shp_reg_id_fieldname;
    ELSE
        SELECT column_name INTO reg_gid_column
        FROM information_schema.columns
        WHERE table_schema = 'itv' AND table_name = reg_table AND column_name IN ('gid')
        LIMIT 1;
			   
    END IF;

    -- Insérer les données dans la table ids_reg
    EXECUTE format('
        INSERT INTO itv.ids_reg (inspection_gid, id_itv, id_sig)
        SELECT
            $1,
            v_itv_physiq_reg.id_regard,
            (SELECT %I FROM itv.%I WHERE %I::text = v_itv_physiq_reg.id_regard::text LIMIT 1)
        FROM itv.v_itv_physiq_reg
        WHERE inspection_gid = $1
        AND NOT EXISTS (
            SELECT 1 FROM itv.ids_reg r
            WHERE r.inspection_gid = $1 AND r.id_itv = v_itv_physiq_reg.id_regard
        )
    ', reg_gid_column, reg_table, reg_gid_column)
    USING inspection_gid_input;

    -- Insérer les données dans la table ids_coll uniquement si coll_table et coll_gid_column ne sont pas NULL
    IF coll_table IS NOT NULL AND coll_gid_column IS NOT NULL THEN
        EXECUTE format('
            INSERT INTO itv.ids_coll (inspection_gid, id_itv, id_sig)
            SELECT
                $1,
                v_itv_physiq_coll.id_troncon,
                (SELECT %I FROM itv.%I WHERE %I::text = v_itv_physiq_coll.id_troncon::text LIMIT 1)
            FROM itv.v_itv_physiq_coll
            WHERE inspection_gid = $1
            AND NOT EXISTS (
                SELECT 1 FROM itv.ids_coll c
                WHERE c.inspection_gid = $1 AND c.id_itv = v_itv_physiq_coll.id_troncon
            )
        ', coll_gid_column, coll_table, coll_gid_column)
        USING inspection_gid_input;

        -- Insérer les valeurs NULL pour les id_itv sans correspondance dans ids_coll
        EXECUTE format('
            INSERT INTO itv.ids_coll (inspection_gid, id_itv, id_sig)
            SELECT
                $1,
                v_itv_physiq_coll.id_troncon,
                NULL
            FROM itv.v_itv_physiq_coll
            WHERE inspection_gid = $1
            AND NOT EXISTS (
                SELECT 1 FROM itv.ids_coll
                WHERE inspection_gid = $1 AND id_itv = v_itv_physiq_coll.id_troncon
            )
        ')
        USING inspection_gid_input;
    END IF;

    -- Insérer les valeurs NULL pour les id_itv sans correspondance dans ids_reg (toujours exécuté)
    EXECUTE format('
        INSERT INTO itv.ids_reg (inspection_gid, id_itv, id_sig)
        SELECT
            $1,
            v_itv_physiq_reg.id_regard,
            NULL
        FROM itv.v_itv_physiq_reg
        WHERE inspection_gid = $1
        AND NOT EXISTS (
            SELECT 1 FROM itv.ids_reg
            WHERE inspection_gid = $1 AND id_itv = v_itv_physiq_reg.id_regard
        )
    ')
    USING inspection_gid_input;

END;
$_$;


ALTER FUNCTION itv.set_id_sig(inspection_gid_input integer) OWNER TO postgres;

SET default_tablespace = '';

--
-- TOC entry 205 (class 1259 OID 49168)
-- Name: B01; Type: TABLE; Schema: itv; Owner: postgres
--

CREATE TABLE itv."B01" (
    gid integer NOT NULL,
    "AAA" character varying(50),
    "AAB" character varying(15),
    "AAC" character varying(15),
    "AAD" character varying(15),
    "AAE" character varying(15),
    "AAF" character varying(15),
    "AAG" character varying(15),
    "AAH" character varying(50),
    "AAI" character varying(15),
    "AAJ" character varying(100),
    "AAK" character varying(1),
    "AAL" character varying(1),
    "AAM" character varying(100),
    "AAN" character varying(100),
    "AAO" character varying(15),
    "AAP" character varying(15),
    "AAQ" character varying(1),
    "AAT" character varying(15),
    "AAU" character varying(15),
    "AAV" character varying(1),
    passage_gid integer
);


ALTER TABLE itv."B01" OWNER TO postgres;

--
-- TOC entry 4027 (class 0 OID 0)
-- Dependencies: 205
-- Name: TABLE "B01"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON TABLE itv."B01" IS 'Lieu d''inspection';


--
-- TOC entry 4028 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAA"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAA" IS 'Référence de tronçon (ID Tronçon)';


--
-- TOC entry 4029 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAB"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAB" IS 'Référence du noeud de départ (ID Regard)';


--
-- TOC entry 4030 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAC"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAC" IS 'Coordonnées du noeud de départ';


--
-- TOC entry 4031 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAD"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAD" IS 'Référence du nœud 1 (ID regard)';


--
-- TOC entry 4032 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAE"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAE" IS 'Coordonnées du nœud 1';


--
-- TOC entry 4033 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAF"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAF" IS 'Référence du nœud 2 (ID regard)';


--
-- TOC entry 4034 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAG"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAG" IS 'Coordonnées du nœud 2';


--
-- TOC entry 4035 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAH"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAH" IS 'Emplacement longitudinal du
            point de départ de la canalisation
            latérale';


--
-- TOC entry 4036 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAI"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAI" IS 'Emplacement circonférentiel du
            point de départ de la canalisation
            latérale (Position horaire)';


--
-- TOC entry 4037 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAJ"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAJ" IS 'Emplacement';


--
-- TOC entry 4038 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAK"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAK" IS 'Sens de l''écoulement';


--
-- TOC entry 4039 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAL"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAL" IS 'Type d''emplacement';


--
-- TOC entry 4040 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAM"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAM" IS 'Organisation ou entité responsable';


--
-- TOC entry 4041 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAN"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAN" IS 'Commune';


--
-- TOC entry 4042 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAO"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAO" IS 'Code de localisation ou numéro de zone (Quartier)';


--
-- TOC entry 4043 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAP"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAP" IS 'Nom du réseau d''assainissement';


--
-- TOC entry 4044 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAQ"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAQ" IS 'Propriété foncière';


--
-- TOC entry 4045 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAT"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAT" IS 'Référence du noeud 3 (ID Regard)';


--
-- TOC entry 4046 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAU"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAU" IS 'Coordonnées du noeud 3';


--
-- TOC entry 4047 (class 0 OID 0)
-- Dependencies: 205
-- Name: COLUMN "B01"."AAV"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B01"."AAV" IS 'Point de départ de l''inspection
            latérale';


--
-- TOC entry 206 (class 1259 OID 49174)
-- Name: B01_gid_seq; Type: SEQUENCE; Schema: itv; Owner: postgres
--

CREATE SEQUENCE itv."B01_gid_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE itv."B01_gid_seq" OWNER TO postgres;

--
-- TOC entry 4048 (class 0 OID 0)
-- Dependencies: 206
-- Name: B01_gid_seq; Type: SEQUENCE OWNED BY; Schema: itv; Owner: postgres
--

ALTER SEQUENCE itv."B01_gid_seq" OWNED BY itv."B01".gid;


--
-- TOC entry 207 (class 1259 OID 49176)
-- Name: B02; Type: TABLE; Schema: itv; Owner: postgres
--

CREATE TABLE itv."B02" (
    gid integer NOT NULL,
    "ABA" character varying(50),
    "ABB" character varying(1),
    "ABC" character varying(1),
    "ABD" character varying(1),
    "ABE" character varying(1),
    "ABF" date,
    "ABG" character varying(50),
    "ABH" character varying(50),
    "ABI" character varying(50),
    "ABJ" character varying(50),
    "ABK" character varying(50),
    "ABL" character varying(50),
    "ABM" character varying(50),
    "ABN" character varying(50),
    "ABO" character varying(15),
    "ABP" character varying(50),
    "ABQ" double precision,
    "ABR" character varying(15),
    "ABS" character varying(50),
    "ABT" character varying(1),
    passage_gid integer
);


ALTER TABLE itv."B02" OWNER TO postgres;

--
-- TOC entry 4049 (class 0 OID 0)
-- Dependencies: 207
-- Name: TABLE "B02"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON TABLE itv."B02" IS 'Détails concernant l''inspection';


--
-- TOC entry 4050 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABA"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABA" IS 'Norme utilisée';


--
-- TOC entry 4051 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABB"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABB" IS 'Système de codage initial';


--
-- TOC entry 4052 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABC"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABC" IS 'Point de référence longitudinal';


--
-- TOC entry 4053 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABD"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABD" IS 'Non utilisé';


--
-- TOC entry 4054 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABE"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABE" IS 'Méthode de l''inspection';


--
-- TOC entry 4055 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABF"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABF" IS 'Date de l’inspection';


--
-- TOC entry 4056 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABG"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABG" IS 'Heure l''inspection';


--
-- TOC entry 4057 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABH"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABH" IS 'Nom de l''inspecteur';


--
-- TOC entry 4058 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABI"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABI" IS 'Référence de fonction de l’inspecteur';


--
-- TOC entry 4059 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABJ"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABJ" IS 'Référence de fonction de l’inspecteur';


--
-- TOC entry 4060 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABK"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABK" IS 'Support de stockage des images vidéo';


--
-- TOC entry 4061 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABL"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABL" IS 'Format de stockage des photographies';


--
-- TOC entry 4062 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABM"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABM" IS 'Système de position sur la bande vidéo';


--
-- TOC entry 4063 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABN"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABN" IS 'Référence de photographie';


--
-- TOC entry 4064 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABO"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABO" IS 'Référence de vidéo';


--
-- TOC entry 4065 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABP"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABP" IS 'Objet de l''inspection';


--
-- TOC entry 4066 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABQ"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABQ" IS 'Étendue d’inspection prévue';


--
-- TOC entry 4067 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABR"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABR" IS 'Format d''images vidéo';


--
-- TOC entry 4068 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABS"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABS" IS 'Nom de fichier d''images vidéo';


--
-- TOC entry 4069 (class 0 OID 0)
-- Dependencies: 207
-- Name: COLUMN "B02"."ABT"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B02"."ABT" IS 'Étape de l’inspection';


--
-- TOC entry 208 (class 1259 OID 49182)
-- Name: B02_gid_seq; Type: SEQUENCE; Schema: itv; Owner: postgres
--

CREATE SEQUENCE itv."B02_gid_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE itv."B02_gid_seq" OWNER TO postgres;

--
-- TOC entry 4070 (class 0 OID 0)
-- Dependencies: 208
-- Name: B02_gid_seq; Type: SEQUENCE OWNED BY; Schema: itv; Owner: postgres
--

ALTER SEQUENCE itv."B02_gid_seq" OWNED BY itv."B02".gid;


--
-- TOC entry 209 (class 1259 OID 49184)
-- Name: B03; Type: TABLE; Schema: itv; Owner: postgres
--

CREATE TABLE itv."B03" (
    gid integer NOT NULL,
    "ACA" character varying(1),
    "ACB" double precision,
    "ACC" character varying(50),
    "ACD" character varying(3),
    "ACE" character varying(5),
    "ACF" character varying(5),
    "ACG" double precision,
    "ACH" double precision,
    "ACI" character varying(50),
    "ACJ" character varying(1),
    "ACK" character varying(1),
    "ACL" character varying(1),
    "ACM" character varying(1),
    "ACN" character varying(2),
    passage_gid integer
);


ALTER TABLE itv."B03" OWNER TO postgres;

--
-- TOC entry 4071 (class 0 OID 0)
-- Dependencies: 209
-- Name: TABLE "B03"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON TABLE itv."B03" IS 'Détails de la canalisation';


--
-- TOC entry 4072 (class 0 OID 0)
-- Dependencies: 209
-- Name: COLUMN "B03"."ACA"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B03"."ACA" IS 'Forme (canalisation)';


--
-- TOC entry 4073 (class 0 OID 0)
-- Dependencies: 209
-- Name: COLUMN "B03"."ACB"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B03"."ACB" IS 'Hauteur (mm)';


--
-- TOC entry 4074 (class 0 OID 0)
-- Dependencies: 209
-- Name: COLUMN "B03"."ACC"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B03"."ACC" IS 'Largeur (mm)';


--
-- TOC entry 4075 (class 0 OID 0)
-- Dependencies: 209
-- Name: COLUMN "B03"."ACD"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B03"."ACD" IS 'Matérieu constitutif (structure du collecteur)';


--
-- TOC entry 4076 (class 0 OID 0)
-- Dependencies: 209
-- Name: COLUMN "B03"."ACE"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B03"."ACE" IS 'Type de revêtement';


--
-- TOC entry 4077 (class 0 OID 0)
-- Dependencies: 209
-- Name: COLUMN "B03"."ACF"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B03"."ACF" IS 'Matériau de revêtement';


--
-- TOC entry 4078 (class 0 OID 0)
-- Dependencies: 209
-- Name: COLUMN "B03"."ACG"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B03"."ACG" IS 'Longueur unitaire de conduite';


--
-- TOC entry 4079 (class 0 OID 0)
-- Dependencies: 209
-- Name: COLUMN "B03"."ACH"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B03"."ACH" IS 'Profondeur du noeud de départ';


--
-- TOC entry 4080 (class 0 OID 0)
-- Dependencies: 209
-- Name: COLUMN "B03"."ACI"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B03"."ACI" IS 'Profondeur du noeud d''arrivé';


--
-- TOC entry 4081 (class 0 OID 0)
-- Dependencies: 209
-- Name: COLUMN "B03"."ACJ"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B03"."ACJ" IS 'Type de branchement ou de collecteur';


--
-- TOC entry 4082 (class 0 OID 0)
-- Dependencies: 209
-- Name: COLUMN "B03"."ACK"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B03"."ACK" IS 'Utilisation du branchement ou du collecteur';


--
-- TOC entry 4083 (class 0 OID 0)
-- Dependencies: 209
-- Name: COLUMN "B03"."ACL"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B03"."ACL" IS 'Position stratégique';


--
-- TOC entry 4084 (class 0 OID 0)
-- Dependencies: 209
-- Name: COLUMN "B03"."ACM"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B03"."ACM" IS 'Nettoyage préalable';


--
-- TOC entry 4085 (class 0 OID 0)
-- Dependencies: 209
-- Name: COLUMN "B03"."ACN"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B03"."ACN" IS 'Année de mise en service';


--
-- TOC entry 210 (class 1259 OID 49187)
-- Name: B03_gid_seq; Type: SEQUENCE; Schema: itv; Owner: postgres
--

CREATE SEQUENCE itv."B03_gid_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE itv."B03_gid_seq" OWNER TO postgres;

--
-- TOC entry 4086 (class 0 OID 0)
-- Dependencies: 210
-- Name: B03_gid_seq; Type: SEQUENCE OWNED BY; Schema: itv; Owner: postgres
--

ALTER SEQUENCE itv."B03_gid_seq" OWNED BY itv."B03".gid;


--
-- TOC entry 211 (class 1259 OID 49189)
-- Name: B04; Type: TABLE; Schema: itv; Owner: postgres
--

CREATE TABLE itv."B04" (
    gid integer NOT NULL,
    "ADA" character varying(1),
    "ADB" character varying(1),
    "ADC" character varying(1),
    "ADD" character varying(1),
    "ADE" character varying(255),
    passage_gid integer
);


ALTER TABLE itv."B04" OWNER TO postgres;

--
-- TOC entry 4087 (class 0 OID 0)
-- Dependencies: 211
-- Name: TABLE "B04"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON TABLE itv."B04" IS 'Autres informations';


--
-- TOC entry 4088 (class 0 OID 0)
-- Dependencies: 211
-- Name: COLUMN "B04"."ADA"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B04"."ADA" IS 'Précipitations';


--
-- TOC entry 4089 (class 0 OID 0)
-- Dependencies: 211
-- Name: COLUMN "B04"."ADB"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B04"."ADB" IS 'Température';


--
-- TOC entry 4090 (class 0 OID 0)
-- Dependencies: 211
-- Name: COLUMN "B04"."ADC"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B04"."ADC" IS 'Régulation de débit';


--
-- TOC entry 4091 (class 0 OID 0)
-- Dependencies: 211
-- Name: COLUMN "B04"."ADD"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B04"."ADD" IS 'N''est pas utilisé';


--
-- TOC entry 4092 (class 0 OID 0)
-- Dependencies: 211
-- Name: COLUMN "B04"."ADE"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."B04"."ADE" IS 'Remarques générales';


--
-- TOC entry 212 (class 1259 OID 49192)
-- Name: B04_gid_seq; Type: SEQUENCE; Schema: itv; Owner: postgres
--

CREATE SEQUENCE itv."B04_gid_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE itv."B04_gid_seq" OWNER TO postgres;

--
-- TOC entry 4093 (class 0 OID 0)
-- Dependencies: 212
-- Name: B04_gid_seq; Type: SEQUENCE OWNED BY; Schema: itv; Owner: postgres
--

ALTER SEQUENCE itv."B04_gid_seq" OWNED BY itv."B04".gid;


--
-- TOC entry 213 (class 1259 OID 49194)
-- Name: C; Type: TABLE; Schema: itv; Owner: postgres
--

CREATE TABLE itv."C" (
    gid integer NOT NULL,
    "I" double precision,
    "J" character varying(3),
    "A" character varying(3),
    "B" character varying(2),
    "C" character varying(2),
    "D" character varying(10),
    "E" character varying(5),
    "F" character varying(255),
    "G" character varying(5),
    "H" character varying(5),
    "K" character varying(1),
    "L" character varying(15),
    "M" character varying(100),
    "N" character varying(50),
    passage_gid integer
);


ALTER TABLE itv."C" OWNER TO postgres;

--
-- TOC entry 4094 (class 0 OID 0)
-- Dependencies: 213
-- Name: COLUMN "C"."I"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."C"."I" IS 'Longueur inspectée (m)';


--
-- TOC entry 4095 (class 0 OID 0)
-- Dependencies: 213
-- Name: COLUMN "C"."J"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."C"."J" IS 'Code de défaut continu
            -- incertain';


--
-- TOC entry 4096 (class 0 OID 0)
-- Dependencies: 213
-- Name: COLUMN "C"."A"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."C"."A" IS 'Code principal';


--
-- TOC entry 4097 (class 0 OID 0)
-- Dependencies: 213
-- Name: COLUMN "C"."B"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."C"."B" IS 'Caractérisation 1';


--
-- TOC entry 4098 (class 0 OID 0)
-- Dependencies: 213
-- Name: COLUMN "C"."C"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."C"."C" IS 'Caractérisation 2';


--
-- TOC entry 4099 (class 0 OID 0)
-- Dependencies: 213
-- Name: COLUMN "C"."D"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."C"."D" IS 'Quantification 1';


--
-- TOC entry 4100 (class 0 OID 0)
-- Dependencies: 213
-- Name: COLUMN "C"."E"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."C"."E" IS 'Quantification 2';


--
-- TOC entry 4101 (class 0 OID 0)
-- Dependencies: 213
-- Name: COLUMN "C"."F"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."C"."F" IS 'Remarque sur l’observation';


--
-- TOC entry 4102 (class 0 OID 0)
-- Dependencies: 213
-- Name: COLUMN "C"."G"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."C"."G" IS 'Emplacement circonférentiel 1';


--
-- TOC entry 4103 (class 0 OID 0)
-- Dependencies: 213
-- Name: COLUMN "C"."H"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."C"."H" IS 'Emplacement circonférentiel 2';


--
-- TOC entry 4104 (class 0 OID 0)
-- Dependencies: 213
-- Name: COLUMN "C"."K"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."C"."K" IS 'Observation au niveau d''un assemblage';


--
-- TOC entry 4105 (class 0 OID 0)
-- Dependencies: 213
-- Name: COLUMN "C"."L"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."C"."L" IS 'N''est pas utilisé';


--
-- TOC entry 4106 (class 0 OID 0)
-- Dependencies: 213
-- Name: COLUMN "C"."M"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."C"."M" IS 'Réf. photo';


--
-- TOC entry 4107 (class 0 OID 0)
-- Dependencies: 213
-- Name: COLUMN "C"."N"; Type: COMMENT; Schema: itv; Owner: postgres
--

COMMENT ON COLUMN itv."C"."N" IS 'Réf. vidéo';


--
-- TOC entry 214 (class 1259 OID 49197)
-- Name: C_gid_seq; Type: SEQUENCE; Schema: itv; Owner: postgres
--

CREATE SEQUENCE itv."C_gid_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE itv."C_gid_seq" OWNER TO postgres;

--
-- TOC entry 4108 (class 0 OID 0)
-- Dependencies: 214
-- Name: C_gid_seq; Type: SEQUENCE OWNED BY; Schema: itv; Owner: postgres
--

ALTER SEQUENCE itv."C_gid_seq" OWNED BY itv."C".gid;


--
-- TOC entry 215 (class 1259 OID 49199)
-- Name: code_obs; Type: TABLE; Schema: itv; Owner: postgres
--

CREATE TABLE itv.code_obs (
    id integer NOT NULL,
    fam_obs character varying,
    code_obs character varying,
    description character varying,
    caracterisation1 character varying,
    caracterisation1_subcode character varying,
    caracterisation1_subdesc character varying,
    caracterisation2 character varying,
    caracterisation2_subcode character varying,
    caracterisation2_subdesc character varying,
    quantification1 character varying,
    quantification1_unit character varying,
    quantification2 character varying,
    quantification2_unit character varying
);


ALTER TABLE itv.code_obs OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 49205)
-- Name: code_obs_id_seq; Type: SEQUENCE; Schema: itv; Owner: postgres
--

CREATE SEQUENCE itv.code_obs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE itv.code_obs_id_seq OWNER TO postgres;

--
-- TOC entry 4109 (class 0 OID 0)
-- Dependencies: 216
-- Name: code_obs_id_seq; Type: SEQUENCE OWNED BY; Schema: itv; Owner: postgres
--

ALTER SEQUENCE itv.code_obs_id_seq OWNED BY itv.code_obs.id;


--
-- TOC entry 217 (class 1259 OID 49207)
-- Name: commune_gid_seq; Type: SEQUENCE; Schema: itv; Owner: postgres
--

CREATE SEQUENCE itv.commune_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE itv.commune_gid_seq OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 49209)
-- Name: commune; Type: TABLE; Schema: itv; Owner: postgres
--

CREATE TABLE itv.commune (
    gid integer DEFAULT nextval('itv.commune_gid_seq'::regclass) NOT NULL,
    id character varying(24),
    nom character varying(50),
    nom_m character varying(50),
    insee_com character varying(5),
    statut character varying(26),
    population numeric(8,0),
    insee_can character varying(5),
    insee_arr character varying(2),
    insee_dep character varying(3),
    insee_reg character varying(2),
    siren_epci character varying(20),
    geom public.geometry(MultiPolygon,2154)
);


ALTER TABLE itv.commune OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 49216)
-- Name: ids_coll; Type: TABLE; Schema: itv; Owner: postgres
--

CREATE TABLE itv.ids_coll (
    gid integer NOT NULL,
    inspection_gid integer,
    id_itv character varying(50),
    id_sig character varying(50)
);


ALTER TABLE itv.ids_coll OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 49219)
-- Name: correspondance_coll_gid_seq; Type: SEQUENCE; Schema: itv; Owner: postgres
--

CREATE SEQUENCE itv.correspondance_coll_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE itv.correspondance_coll_gid_seq OWNER TO postgres;

--
-- TOC entry 4110 (class 0 OID 0)
-- Dependencies: 220
-- Name: correspondance_coll_gid_seq; Type: SEQUENCE OWNED BY; Schema: itv; Owner: postgres
--

ALTER SEQUENCE itv.correspondance_coll_gid_seq OWNED BY itv.ids_coll.gid;


--
-- TOC entry 221 (class 1259 OID 49221)
-- Name: ids_reg; Type: TABLE; Schema: itv; Owner: postgres
--

CREATE TABLE itv.ids_reg (
    gid integer NOT NULL,
    inspection_gid integer,
    id_itv character varying(50),
    id_sig character varying(50)
);


ALTER TABLE itv.ids_reg OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 49224)
-- Name: correspondance_reg_gid_seq; Type: SEQUENCE; Schema: itv; Owner: postgres
--

CREATE SEQUENCE itv.correspondance_reg_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE itv.correspondance_reg_gid_seq OWNER TO postgres;

--
-- TOC entry 4111 (class 0 OID 0)
-- Dependencies: 222
-- Name: correspondance_reg_gid_seq; Type: SEQUENCE OWNED BY; Schema: itv; Owner: postgres
--

ALTER SEQUENCE itv.correspondance_reg_gid_seq OWNED BY itv.ids_reg.gid;


--
-- TOC entry 223 (class 1259 OID 49226)
-- Name: inspection; Type: TABLE; Schema: itv; Owner: postgres
--

CREATE TABLE itv.inspection (
    gid integer NOT NULL,
    file character varying(255),
    "A1" character varying(50),
    "A2" character varying(5),
    "A3" character varying(2),
    "A4" character varying(1),
    "A5" character varying(1),
    "A6" character varying(5),
    shp_reg character varying(255),
    shp_coll character varying(255),
    entreprise character varying(100),
    pdf_filename character varying(255),
    shp_reg_table character varying(255),
    shp_coll_table character varying(255),
    created_by integer,
    shp_reg_id_fieldname character varying(100),
    shp_coll_id_fieldname character varying(100)
);


ALTER TABLE itv.inspection OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 49232)
-- Name: inspection_gid_seq; Type: SEQUENCE; Schema: itv; Owner: postgres
--

CREATE SEQUENCE itv.inspection_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE itv.inspection_gid_seq OWNER TO postgres;

--
-- TOC entry 4112 (class 0 OID 0)
-- Dependencies: 224
-- Name: inspection_gid_seq; Type: SEQUENCE OWNED BY; Schema: itv; Owner: postgres
--

ALTER SEQUENCE itv.inspection_gid_seq OWNED BY itv.inspection.gid;


--
-- TOC entry 225 (class 1259 OID 49234)
-- Name: passage; Type: TABLE; Schema: itv; Owner: postgres
--

CREATE TABLE itv.passage (
    gid integer NOT NULL,
    n_passage integer,
    inspection_gid integer
);


ALTER TABLE itv.passage OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 49237)
-- Name: passage_gid_seq; Type: SEQUENCE; Schema: itv; Owner: postgres
--

CREATE SEQUENCE itv.passage_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE itv.passage_gid_seq OWNER TO postgres;

--
-- TOC entry 4113 (class 0 OID 0)
-- Dependencies: 226
-- Name: passage_gid_seq; Type: SEQUENCE OWNED BY; Schema: itv; Owner: postgres
--

ALTER SEQUENCE itv.passage_gid_seq OWNED BY itv.passage.gid;


--
-- TOC entry 227 (class 1259 OID 49239)
-- Name: v_inspection; Type: VIEW; Schema: itv; Owner: postgres
--

CREATE VIEW itv.v_inspection AS
 SELECT get_all_inspection_data.inspection_gid,
    get_all_inspection_data.nature_res,
    get_all_inspection_data.type_eau,
    get_all_inspection_data.date_deb,
    get_all_inspection_data.date_fin,
    get_all_inspection_data.entreprise,
    get_all_inspection_data.longueur,
    get_all_inspection_data.nom_plan,
    get_all_inspection_data.nom_rapport,
    get_all_inspection_data.nom_txt,
    get_all_inspection_data.remarques,
    get_all_inspection_data.geom
   FROM itv.get_all_inspection_data() get_all_inspection_data(inspection_gid, nature_res, type_eau, date_deb, date_fin, entreprise, longueur, nom_plan, nom_rapport, nom_txt, remarques, geom);


ALTER VIEW itv.v_inspection OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 49243)
-- Name: v_itv_details; Type: VIEW; Schema: itv; Owner: postgres
--

CREATE VIEW itv.v_itv_details AS
 SELECT row_number() OVER () AS gid,
    inspection.gid AS inspection_gid,
    passage.n_passage,
    "B01"."AAK" AS sens_ecoul,
    "B01"."AAB" AS id_reg_ent,
    "B01"."AAF" AS id_reg_sor,
    "B01"."AAA" AS id_troncon,
    NULL::text AS type_obs,
    "C"."A" AS fam_obs,
    concat("C"."A",
        CASE
            WHEN (("C"."B" IS NOT NULL) AND (("C"."B")::text <> ''::text)) THEN ('-'::text || ("C"."B")::text)
            ELSE ''::text
        END,
        CASE
            WHEN (("C"."C" IS NOT NULL) AND (("C"."C")::text <> ''::text)) THEN ('-'::text || ("C"."C")::text)
            ELSE ''::text
        END) AS code_obs,
    NULL::text AS libel_obs,
    "C"."D" AS quan_charg,
    "C"."F" AS rmq_obs,
    concat(
        CASE
            WHEN (("C"."G" IS NOT NULL) AND (("C"."G")::text <> ''::text)) THEN (lpad(("C"."G")::text, 2, '0'::text) || 'h'::text)
            ELSE ''::text
        END,
        CASE
            WHEN (("C"."H" IS NOT NULL) AND (("C"."H")::text <> ''::text) AND (("C"."G" IS NULL) OR (("C"."G")::text ~~ ''::text))) THEN (lpad(("C"."H")::text, 2, '0'::text) || 'h'::text)
            WHEN (("C"."H" IS NOT NULL) AND (("C"."H")::text <> ''::text) AND ("C"."G" IS NOT NULL) AND (("C"."G")::text <> ''::text)) THEN (('-'::text || lpad(("C"."H")::text, 2, '0'::text)) || 'h'::text)
            ELSE ''::text
        END) AS orientatio,
    "C"."I" AS metrage,
    "B04"."ADA" AS precipitat,
    "C"."M" AS photo,
    "B02"."ABS" AS video,
    "C"."N" AS video_tps,
    "B02"."ABF" AS date_obs
   FROM ((((((itv."B01"
     JOIN itv.passage ON (("B01".passage_gid = passage.gid)))
     JOIN itv.inspection ON ((passage.inspection_gid = inspection.gid)))
     JOIN itv."B02" ON (("B02".passage_gid = passage.gid)))
     JOIN itv."B03" ON (("B03".passage_gid = passage.gid)))
     JOIN itv."B04" ON (("B04".passage_gid = passage.gid)))
     JOIN itv."C" ON (("C".passage_gid = passage.gid)));


ALTER VIEW itv.v_itv_details OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 49248)
-- Name: v_itv_details_bcht; Type: VIEW; Schema: itv; Owner: postgres
--

CREATE VIEW itv.v_itv_details_bcht AS
 SELECT row_number() OVER () AS id,
    get_all_bcht_positons.inspection_gid,
    NULL::text AS id_bcht,
    get_all_bcht_positons.x,
    get_all_bcht_positons.y,
    get_all_bcht_positons.code_obs AS code,
    get_all_bcht_positons.libel_obs AS libelle,
    get_all_bcht_positons.orientatio,
    get_all_bcht_positons.sens_ecoul AS sens_inspe,
    NULL::text AS type_mat,
    NULL::text AS diametre,
    get_all_bcht_positons.id_reg_ent,
    get_all_bcht_positons.id_reg_sor,
    get_all_bcht_positons.geom
   FROM itv.get_all_bcht_positions() get_all_bcht_positons(inspection_gid, id_reg_ent, id_reg_sor, x, y, sens_ecoul, type_obs, fam_obs, code_obs, libel_obs, orientatio, geom);


ALTER VIEW itv.v_itv_details_bcht OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 49252)
-- Name: v_itv_details_bcht_lines; Type: VIEW; Schema: itv; Owner: postgres
--

CREATE VIEW itv.v_itv_details_bcht_lines AS
 SELECT row_number() OVER () AS id,
    get_all_bcht_lines.inspection_gid,
    NULL::text AS id_bcht,
    NULL::double precision AS x,
    NULL::double precision AS y,
    get_all_bcht_lines.code_obs AS code,
    get_all_bcht_lines.libel_obs AS libelle,
    get_all_bcht_lines.orientatio,
    get_all_bcht_lines.sens_ecoul AS sens_inspe,
    NULL::text AS type_mat,
    NULL::text AS diametre,
    get_all_bcht_lines.id_reg_ent,
    get_all_bcht_lines.id_reg_sor,
    get_all_bcht_lines.geom
   FROM itv.get_all_bcht_lines() get_all_bcht_lines(inspection_gid, id_reg_ent, id_reg_sor, sens_ecoul, type_obs, fam_obs, code_obs, libel_obs, orientatio, geom);


ALTER VIEW itv.v_itv_details_bcht_lines OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 49256)
-- Name: v_itv_details_geom; Type: VIEW; Schema: itv; Owner: postgres
--

CREATE VIEW itv.v_itv_details_geom AS
 SELECT row_number() OVER () AS gid,
    get_all.inspection_gid,
    get_all.id_reg_ent,
    get_all.id_reg_sor,
    get_all.id_troncon,
    get_all.metrage,
    get_all.x,
    get_all.y,
    get_all.n_passage,
    get_all.sens_ecoul,
    get_all.type_obs,
    get_all.fam_obs,
    get_all.code_obs,
    get_all.libel_obs,
    get_all.quan_charg,
    get_all.rmq_obs,
    get_all.orientatio,
    get_all.precipitat,
    get_all.photo,
    get_all.video,
    get_all.video_tps,
    get_all.date_obs,
    get_all.code_insee,
    get_all.geom,
    code_obs_tbl.description,
    code_obs_tbl.caracterisation1,
    code_obs_tbl.caracterisation1_subcode,
    code_obs_tbl.caracterisation1_subdesc,
    code_obs_tbl.caracterisation2,
    code_obs_tbl.caracterisation2_subcode,
    code_obs_tbl.caracterisation2_subdesc,
    code_obs_tbl.quantification1,
    code_obs_tbl.quantification1_unit,
    code_obs_tbl.quantification2,
    code_obs_tbl.quantification2_unit
   FROM (itv.get_all_defect_positions() get_all(inspection_gid, id_reg_ent, id_reg_sor, id_troncon, metrage, x, y, n_passage, sens_ecoul, type_obs, fam_obs, code_obs, libel_obs, quan_charg, rmq_obs, orientatio, precipitat, photo, video, video_tps, date_obs, code_insee, geom)
     LEFT JOIN itv.code_obs code_obs_tbl ON ((get_all.code_obs = (code_obs_tbl.code_obs)::text)));


ALTER VIEW itv.v_itv_details_geom OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 49261)
-- Name: v_itv_physiq_coll; Type: VIEW; Schema: itv; Owner: postgres
--

CREATE VIEW itv.v_itv_physiq_coll AS
 SELECT row_number() OVER () AS gid,
    inspection.gid AS inspection_gid,
    COALESCE(NULLIF(("B01"."AAA")::text, ''::text), ((("B01"."AAD")::text || '_'::text) || ("B01"."AAF")::text)) AS id_troncon,
    NULL::text AS type_res,
        CASE
            WHEN (("B03"."ACD")::text = 'AP'::text) THEN '01'::text
            WHEN (("B03"."ACD")::text = 'AA'::text) THEN '02'::text
            WHEN (("B03"."ACD")::text = 'AH'::text) THEN '03'::text
            WHEN (("B03"."ACD")::text = 'AG'::text) THEN '04'::text
            WHEN (("B03"."ACD")::text = 'AM'::text) THEN '05'::text
            WHEN (("B03"."ACD")::text = 'AO'::text) THEN '06'::text
            WHEN (("B03"."ACD")::text = 'AN'::text) THEN '07'::text
            WHEN (("B03"."ACD")::text = 'AZ'::text) THEN '08'::text
            WHEN (("B03"."ACD")::text = 'AE'::text) THEN '09'::text
            WHEN (("B03"."ACD")::text = 'AV'::text) THEN '10'::text
            WHEN (("B03"."ACD")::text = 'AX'::text) THEN '11'::text
            WHEN (("B03"."ACD")::text = 'AL'::text) THEN '12'::text
            WHEN (("B03"."ACD")::text = 'AW'::text) THEN '13'::text
            WHEN (("B03"."ACD")::text = 'AK'::text) THEN '14'::text
            WHEN (("B03"."ACD")::text = 'Z'::text) THEN '15'::text
            WHEN (("B03"."ACD")::text = 'AU'::text) THEN '16'::text
            WHEN (("B03"."ACD")::text = 'AR'::text) THEN '17'::text
            ELSE '00'::text
        END AS type_mat,
        CASE
            WHEN (("B03"."ACC" IS NULL) OR (("B03"."ACC")::text = ''::text)) THEN "B03"."ACB"
            ELSE NULL::double precision
        END AS diam_nom,
        CASE
            WHEN (("B03"."ACC" IS NOT NULL) AND (("B03"."ACC")::text <> ''::text)) THEN "B03"."ACB"
            ELSE NULL::double precision
        END AS hauteur,
        CASE
            WHEN (("B03"."ACC" IS NOT NULL) AND (("B03"."ACC")::text <> ''::text)) THEN "B03"."ACC"
            ELSE NULL::character varying
        END AS largeur,
        CASE
            WHEN (("B03"."ACA")::text = 'B'::text) THEN '01'::text
            WHEN (("B03"."ACA")::text = 'A'::text) THEN '02'::text
            WHEN (("B03"."ACA")::text = 'D'::text) THEN '03'::text
            WHEN (("B03"."ACA")::text = ''::text) THEN '04'::text
            WHEN (("B03"."ACA")::text = ''::text) THEN '05'::text
            WHEN (("B03"."ACA")::text = ''::text) THEN '06'::text
            WHEN (("B03"."ACA")::text = 'F'::text) THEN '07'::text
            WHEN (("B03"."ACA")::text = ''::text) THEN '08'::text
            ELSE '00'::text
        END AS forme,
    "B01"."AAJ" AS nom_voie,
    "B02"."ABQ" AS longueur_troncon_itv,
    itv.get_longueur_troncon_sig((itv.get_id_sig('ids_coll'::text, (("B01"."AAA")::text)::character varying, inspection.gid))::character varying, inspection.gid) AS longueur_troncon_sig,
    itv.get_id_sig('ids_coll'::text, (("B01"."AAA")::text)::character varying, inspection.gid) AS id_sig
   FROM (((((itv."B01"
     JOIN itv.passage ON (("B01".passage_gid = passage.gid)))
     JOIN itv.inspection ON ((passage.inspection_gid = inspection.gid)))
     JOIN itv."B02" ON (("B02".passage_gid = passage.gid)))
     JOIN itv."B03" ON (("B03".passage_gid = passage.gid)))
     JOIN itv."B04" ON (("B04".passage_gid = passage.gid)))
  GROUP BY inspection.gid, "B01"."AAA", "B01"."AAD", "B01"."AAF", "B01"."AAJ", "B02"."ABQ", "B03"."ACA", "B03"."ACB", "B03"."ACC", "B03"."ACD", inspection.shp_coll_table;


ALTER VIEW itv.v_itv_physiq_coll OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 49266)
-- Name: v_itv_physiq_reg; Type: VIEW; Schema: itv; Owner: postgres
--

CREATE VIEW itv.v_itv_physiq_reg AS
 WITH union_reg AS (
         SELECT inspection.gid AS inspection_gid,
            ("B01"."AAD")::text AS id_regard,
            NULLIF(("B03"."ACH")::text, 'NaN'::text) AS profondeur,
            NULL::character varying(1) AS forme,
            "B01"."AAJ" AS nom_voie
           FROM (((((itv."B01"
             JOIN itv."B02" ON (("B02".passage_gid = "B01".passage_gid)))
             JOIN itv."B03" ON (("B03".passage_gid = "B01".passage_gid)))
             JOIN itv."B04" ON (("B04".passage_gid = "B01".passage_gid)))
             JOIN itv.passage ON ((passage.gid = "B01".passage_gid)))
             JOIN itv.inspection ON ((inspection.gid = passage.inspection_gid)))
          WHERE (("B01"."AAD" IS NOT NULL) AND (("B01"."AAD")::text <> ''::text))
        UNION ALL
         SELECT inspection.gid AS gid_inspection,
            ("B01"."AAF")::text AS id_regard,
            NULLIF(("B03"."ACI")::text, 'NaN'::text) AS profondeur,
            NULL::character varying(1) AS forme,
            "B01"."AAJ" AS nom_voie
           FROM (((((itv."B01"
             JOIN itv."B02" ON (("B02".passage_gid = "B01".passage_gid)))
             JOIN itv."B03" ON (("B03".passage_gid = "B01".passage_gid)))
             JOIN itv."B04" ON (("B04".passage_gid = "B01".passage_gid)))
             JOIN itv.passage ON ((passage.gid = "B01".passage_gid)))
             JOIN itv.inspection ON ((inspection.gid = passage.inspection_gid)))
          WHERE (("B01"."AAF" IS NOT NULL) AND (("B01"."AAF")::text <> ''::text))
        )
 SELECT row_number() OVER () AS gid,
    union_reg.inspection_gid,
    union_reg.id_regard,
    COALESCE(max(NULLIF(union_reg.profondeur, ''::text)), NULL::text) AS profondeur,
    NULL::text AS dimension,
    union_reg.forme,
    union_reg.nom_voie,
    itv.get_id_sig('ids_reg'::text, (union_reg.id_regard)::character varying, union_reg.inspection_gid) AS id_sig
   FROM union_reg
  GROUP BY union_reg.inspection_gid, union_reg.id_regard, union_reg.forme, union_reg.nom_voie, (itv.get_id_sig('ids_reg'::text, (union_reg.id_regard)::character varying, union_reg.inspection_gid));


ALTER VIEW itv.v_itv_physiq_reg OWNER TO postgres;

--
-- TOC entry 3834 (class 2604 OID 49358)
-- Name: B01 gid; Type: DEFAULT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv."B01" ALTER COLUMN gid SET DEFAULT nextval('itv."B01_gid_seq"'::regclass);


--
-- TOC entry 3835 (class 2604 OID 49359)
-- Name: B02 gid; Type: DEFAULT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv."B02" ALTER COLUMN gid SET DEFAULT nextval('itv."B02_gid_seq"'::regclass);


--
-- TOC entry 3836 (class 2604 OID 49360)
-- Name: B03 gid; Type: DEFAULT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv."B03" ALTER COLUMN gid SET DEFAULT nextval('itv."B03_gid_seq"'::regclass);


--
-- TOC entry 3837 (class 2604 OID 49361)
-- Name: B04 gid; Type: DEFAULT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv."B04" ALTER COLUMN gid SET DEFAULT nextval('itv."B04_gid_seq"'::regclass);


--
-- TOC entry 3838 (class 2604 OID 49362)
-- Name: C gid; Type: DEFAULT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv."C" ALTER COLUMN gid SET DEFAULT nextval('itv."C_gid_seq"'::regclass);


--
-- TOC entry 3839 (class 2604 OID 49363)
-- Name: code_obs id; Type: DEFAULT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv.code_obs ALTER COLUMN id SET DEFAULT nextval('itv.code_obs_id_seq'::regclass);


--
-- TOC entry 3841 (class 2604 OID 49364)
-- Name: ids_coll gid; Type: DEFAULT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv.ids_coll ALTER COLUMN gid SET DEFAULT nextval('itv.correspondance_coll_gid_seq'::regclass);


--
-- TOC entry 3842 (class 2604 OID 49365)
-- Name: ids_reg gid; Type: DEFAULT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv.ids_reg ALTER COLUMN gid SET DEFAULT nextval('itv.correspondance_reg_gid_seq'::regclass);


--
-- TOC entry 3843 (class 2604 OID 49366)
-- Name: inspection gid; Type: DEFAULT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv.inspection ALTER COLUMN gid SET DEFAULT nextval('itv.inspection_gid_seq'::regclass);


--
-- TOC entry 3844 (class 2604 OID 49367)
-- Name: passage gid; Type: DEFAULT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv.passage ALTER COLUMN gid SET DEFAULT nextval('itv.passage_gid_seq'::regclass);


--
-- TOC entry 3874 (class 2606 OID 49282)
-- Name: ids_reg PK_1a2b3c4d5e6f7g8h9i0j1k2l3m; Type: CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv.ids_reg
    ADD CONSTRAINT "PK_1a2b3c4d5e6f7g8h9i0j1k2l3m" PRIMARY KEY (gid);


--
-- TOC entry 3860 (class 2606 OID 49284)
-- Name: C PK_4a936ec59e3abba7e9444c6cb4e; Type: CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv."C"
    ADD CONSTRAINT "PK_4a936ec59e3abba7e9444c6cb4e" PRIMARY KEY (gid);


--
-- TOC entry 3869 (class 2606 OID 49286)
-- Name: ids_coll PK_4d5e6f7g8h9i0j1k2l3m4n5o6p; Type: CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv.ids_coll
    ADD CONSTRAINT "PK_4d5e6f7g8h9i0j1k2l3m4n5o6p" PRIMARY KEY (gid);


--
-- TOC entry 3877 (class 2606 OID 49288)
-- Name: inspection PK_520b6d6420aa39867a4ef24e560; Type: CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv.inspection
    ADD CONSTRAINT "PK_520b6d6420aa39867a4ef24e560" PRIMARY KEY (gid);


--
-- TOC entry 3857 (class 2606 OID 49290)
-- Name: B04 PK_605881ded05f29ee81b86547cc1; Type: CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv."B04"
    ADD CONSTRAINT "PK_605881ded05f29ee81b86547cc1" PRIMARY KEY (gid);


--
-- TOC entry 3852 (class 2606 OID 49292)
-- Name: B02 PK_9a7a5daac13f24b8e3efc42182c; Type: CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv."B02"
    ADD CONSTRAINT "PK_9a7a5daac13f24b8e3efc42182c" PRIMARY KEY (gid);


--
-- TOC entry 3879 (class 2606 OID 49294)
-- Name: passage PK_9f391f8e81e97c76afa2e044358; Type: CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv.passage
    ADD CONSTRAINT "PK_9f391f8e81e97c76afa2e044358" PRIMARY KEY (gid);


--
-- TOC entry 3849 (class 2606 OID 49296)
-- Name: B01 PK_9f79f415c2fdf12ae8f44659e55; Type: CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv."B01"
    ADD CONSTRAINT "PK_9f79f415c2fdf12ae8f44659e55" PRIMARY KEY (gid);


--
-- TOC entry 3854 (class 2606 OID 49298)
-- Name: B03 PK_e2c43fe16299bd2e844615ca8ea; Type: CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv."B03"
    ADD CONSTRAINT "PK_e2c43fe16299bd2e844615ca8ea" PRIMARY KEY (gid);


--
-- TOC entry 3863 (class 2606 OID 49300)
-- Name: code_obs code_obs_pkey; Type: CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv.code_obs
    ADD CONSTRAINT code_obs_pkey PRIMARY KEY (id);


--
-- TOC entry 3866 (class 2606 OID 49302)
-- Name: commune commune_pkey; Type: CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv.commune
    ADD CONSTRAINT commune_pkey PRIMARY KEY (gid);


--
-- TOC entry 3871 (class 2606 OID 49304)
-- Name: ids_coll unique_coll_inspection_gid_id_itv; Type: CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv.ids_coll
    ADD CONSTRAINT unique_coll_inspection_gid_id_itv UNIQUE (inspection_gid, id_itv);


--
-- TOC entry 3845 (class 1259 OID 49305)
-- Name: IDX_1a2b3c4d5e6f7g8h9i0j1k2l3m; Type: INDEX; Schema: itv; Owner: postgres
--

CREATE INDEX "IDX_1a2b3c4d5e6f7g8h9i0j1k2l3m" ON itv."B01" USING btree ("AAD");


--
-- TOC entry 3850 (class 1259 OID 49306)
-- Name: IDX_3e4f5g6h7i8j9k0l1m2n3o4p5q; Type: INDEX; Schema: itv; Owner: postgres
--

CREATE INDEX "IDX_3e4f5g6h7i8j9k0l1m2n3o4p5q" ON itv."B02" USING btree (passage_gid);


--
-- TOC entry 3872 (class 1259 OID 49307)
-- Name: IDX_4e5f6g7h8i9j0k1l2m3n4o5p6q; Type: INDEX; Schema: itv; Owner: postgres
--

CREATE INDEX "IDX_4e5f6g7h8i9j0k1l2m3n4o5p6q" ON itv.ids_reg USING btree (inspection_gid);


--
-- TOC entry 3846 (class 1259 OID 49308)
-- Name: IDX_4n5o6p7q8r9s0t1u2v3w4x5y6z; Type: INDEX; Schema: itv; Owner: postgres
--

CREATE INDEX "IDX_4n5o6p7q8r9s0t1u2v3w4x5y6z" ON itv."B01" USING btree ("AAF");


--
-- TOC entry 3875 (class 1259 OID 49309)
-- Name: IDX_520b6d6420aa39867a4ef24e56; Type: INDEX; Schema: itv; Owner: postgres
--

CREATE INDEX "IDX_520b6d6420aa39867a4ef24e56" ON itv.inspection USING btree (gid);


--
-- TOC entry 3847 (class 1259 OID 49310)
-- Name: IDX_7a8b9c0d1e2f3g4h5i6j7k8l9m; Type: INDEX; Schema: itv; Owner: postgres
--

CREATE INDEX "IDX_7a8b9c0d1e2f3g4h5i6j7k8l9m" ON itv."B01" USING btree (passage_gid);


--
-- TOC entry 3867 (class 1259 OID 49311)
-- Name: IDX_9b8c7d6e5f4g3h2i1j0k1l2m3n; Type: INDEX; Schema: itv; Owner: postgres
--

CREATE INDEX "IDX_9b8c7d6e5f4g3h2i1j0k1l2m3n" ON itv.ids_coll USING btree (inspection_gid);


--
-- TOC entry 3864 (class 1259 OID 49312)
-- Name: commune_geom_geom_idx; Type: INDEX; Schema: itv; Owner: postgres
--

CREATE INDEX commune_geom_geom_idx ON itv.commune USING gist (geom);


--
-- TOC entry 3880 (class 1259 OID 49313)
-- Name: idx_9f79f415c2fdf12ae8f44659e55; Type: INDEX; Schema: itv; Owner: postgres
--

CREATE INDEX idx_9f79f415c2fdf12ae8f44659e55 ON itv.passage USING btree (inspection_gid);


--
-- TOC entry 3855 (class 1259 OID 49314)
-- Name: idx_B03_passage_gid; Type: INDEX; Schema: itv; Owner: postgres
--

CREATE INDEX "idx_B03_passage_gid" ON itv."B03" USING btree (passage_gid);


--
-- TOC entry 3858 (class 1259 OID 49315)
-- Name: idx_B04_passage_gid; Type: INDEX; Schema: itv; Owner: postgres
--

CREATE INDEX "idx_B04_passage_gid" ON itv."B04" USING btree (passage_gid);


--
-- TOC entry 3861 (class 1259 OID 49316)
-- Name: idx_C_passage_gid; Type: INDEX; Schema: itv; Owner: postgres
--

CREATE INDEX "idx_C_passage_gid" ON itv."C" USING btree (passage_gid);


--
-- TOC entry 3888 (class 2606 OID 49317)
-- Name: passage FK_1d981e67e559985e4245c91f03d; Type: FK CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv.passage
    ADD CONSTRAINT "FK_1d981e67e559985e4245c91f03d" FOREIGN KEY (inspection_gid) REFERENCES itv.inspection(gid) ON DELETE CASCADE;


--
-- TOC entry 3881 (class 2606 OID 49322)
-- Name: B01 FK_20a4c933a0b94722664ee65b03f; Type: FK CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv."B01"
    ADD CONSTRAINT "FK_20a4c933a0b94722664ee65b03f" FOREIGN KEY (passage_gid) REFERENCES itv.passage(gid) ON DELETE CASCADE;


--
-- TOC entry 3885 (class 2606 OID 49327)
-- Name: C FK_20a4c933a0b94722664ee65b03f; Type: FK CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv."C"
    ADD CONSTRAINT "FK_20a4c933a0b94722664ee65b03f" FOREIGN KEY (passage_gid) REFERENCES itv.passage(gid) ON DELETE CASCADE;


--
-- TOC entry 3882 (class 2606 OID 49332)
-- Name: B02 FK_2a3c15388b8af3f9d4f8ece1eb5; Type: FK CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv."B02"
    ADD CONSTRAINT "FK_2a3c15388b8af3f9d4f8ece1eb5" FOREIGN KEY (passage_gid) REFERENCES itv.passage(gid) ON DELETE CASCADE;


--
-- TOC entry 3887 (class 2606 OID 49337)
-- Name: ids_reg FK_3e4f5g6h7i8j9k0l1m2n3o4p5q; Type: FK CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv.ids_reg
    ADD CONSTRAINT "FK_3e4f5g6h7i8j9k0l1m2n3o4p5q" FOREIGN KEY (inspection_gid) REFERENCES itv.inspection(gid) ON DELETE CASCADE;


--
-- TOC entry 3884 (class 2606 OID 49342)
-- Name: B04 FK_5646496fd947c2973f28ad5cd6f; Type: FK CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv."B04"
    ADD CONSTRAINT "FK_5646496fd947c2973f28ad5cd6f" FOREIGN KEY (passage_gid) REFERENCES itv.passage(gid) ON DELETE CASCADE;


--
-- TOC entry 3886 (class 2606 OID 49347)
-- Name: ids_coll FK_8a9b0c1d2e3f4g5h6i7j8k9l0m; Type: FK CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv.ids_coll
    ADD CONSTRAINT "FK_8a9b0c1d2e3f4g5h6i7j8k9l0m" FOREIGN KEY (inspection_gid) REFERENCES itv.inspection(gid) ON DELETE CASCADE;


--
-- TOC entry 3883 (class 2606 OID 49352)
-- Name: B03 FK_c616062b12032abe786ec91a1e1; Type: FK CONSTRAINT; Schema: itv; Owner: postgres
--

ALTER TABLE ONLY itv."B03"
    ADD CONSTRAINT "FK_c616062b12032abe786ec91a1e1" FOREIGN KEY (passage_gid) REFERENCES itv.passage(gid) ON DELETE CASCADE;


-- Completed on 2025-10-15 10:12:05

--
-- PostgreSQL database dump complete
--