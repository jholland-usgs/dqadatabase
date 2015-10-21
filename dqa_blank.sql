--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: fnsclgetchanneldata(integer[], integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION fnsclgetchanneldata(integer[], integer, date, date) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
	channelIDs alias for $1;
	metricID alias for $2;
	startDate alias for $3;
	endDate alias for $4;
	channelData TEXT;
	computeType int;
	metricName TEXT;
BEGIN
	Select fkComputeTypeID, name from tblMetric where pkMetricID = metricID INTO computeType, metricName;
	CASE computeType
		--Metric Data
		WHEN 1 THEN
			--Average across total number of values
			SELECT INTO channelData string_agg(CONCAT(id, ',',avg, ',', fnsclGetPercentage(avg, metricName)), E'\n') FROM (
				SELECT md1.fkChannelID as id, round((SUM(md1.value)/count(md1.*))::numeric, 2) as avg
				FROM tblMetricData md1
				WHERE md1.fkChannelID = any(channelIDs)
					AND 
					md1.date >= to_char(startDate, 'J')::INT
					AND md1.date <= to_char(endDate, 'J')::INT
					AND md1.fkMetricID = metricID
				GROUP BY md1.fkChannelID ) channels;
		WHEN 2 THEN
			--Average across days NOT ACCURATE
			select '2' into channelData;
		WHEN 3 THEN
			--Count all values, return sum
			SELECT INTO channelData string_agg(CONCAT(id, ',',sum, ',', fnsclGetPercentage(sum, metricName)), E'\n') FROM (
				SELECT md1.fkChannelID as id, round(SUM(md1.value)::numeric, 0) as sum
				FROM tblMetricData md1
				WHERE md1.fkChannelID = any(channelIDs)
					AND 
					md1.date >= to_char(startDate, 'J')::INT
					AND md1.date <= to_char(endDate, 'J')::INT
					AND md1.fkMetricID = metricID
				GROUP BY md1.fkChannelID ) channels;
		
		WHEN 5 THEN
			--Calculate data between last calibrations
			SELECT INTO channelData string_agg(CONCAT(id, ',',sum, ',', fnsclGetPercentage(sum, metricName)), E'\n') FROM (
				SELECT md1.fkChannelID as id, round((to_char(endDate, 'J')::INT-max(date))::numeric, 0) as sum
				FROM tblMetricStringData md1
				WHERE md1.fkChannelID = any(channelIDs)
					AND md1.date <= to_char(endDate, 'J')::INT
					AND md1.fkMetricID = metricID
				GROUP BY md1.fkChannelID ) channels;
		WHEN 6 THEN
			--Average across number of values
			select '6' into channelData;
		ELSE
			--Insert error into error log
			select 'Error' into channelData;
	END CASE;

	
	RETURN channelData;
END;
$_$;


ALTER FUNCTION public.fnsclgetchanneldata(integer[], integer, date, date) OWNER TO postgres;

--
-- Name: fnsclgetchannelplotdata(integer, integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION fnsclgetchannelplotdata(integer, integer, date, date) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
	channelID alias for $1;
	metricID alias for $2;
	startDate alias for $3;
	endDate alias for $4;
	channelPlotData TEXT;
	computeType int;
BEGIN
	
	Select fkComputeTypeID from tblMetric where pkMetricID = metricID INTO computeType;
	CASE computeType
		--Metric Data
		WHEN 1 THEN
			--Average across total number of values
			SELECT INTO channelPlotData string_agg(CONCAT(sdate, ',',avg), E'\n') FROM (
				SELECT to_date(md1.date::text, 'J') as sdate, round(md1.value::numeric, 4) as avg
				FROM tblMetricData md1
				WHERE md1.fkChannelID = channelID
					AND 
					md1.date >= to_char(startDate, 'J')::INT
					AND md1.date <= to_char(endDate, 'J')::INT
					AND md1.fkMetricID = metricID
				 ) channels;
		WHEN 2 THEN
			--Average across days NOT ACCURATE
			select '2' into channelPlotData;
		WHEN 3 THEN
			--Count all values, return sum
			SELECT INTO channelPlotData string_agg(CONCAT(sdate, ',',avg), E'\n') FROM (
				SELECT to_date(md1.date::text, 'J') as sdate, round(md1.value::numeric, 4) as avg
				FROM tblMetricData md1
				WHERE md1.fkchannelID = channelID
					AND 
					md1.date >= to_char(startDate, 'J')::INT
					AND md1.date <= to_char(endDate, 'J')::INT
					AND md1.fkMetricID = metricID
				) stations;
		--Calibration Data
		WHEN 5 THEN
			--Calculate data between last calibrations
			select '5' into channelPlotData;
		WHEN 6 THEN
			--Average across number of values
			select '6' into channelPlotData;
		ELSE
			--Insert error into error log
			select 'Error' into channelPlotData;
	END CASE;

	
	RETURN channelPlotData;
END;
$_$;


ALTER FUNCTION public.fnsclgetchannelplotdata(integer, integer, date, date) OWNER TO postgres;

--
-- Name: fnsclgetchannels(integer[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION fnsclgetchannels(integer[]) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
	stationIDs alias for $1;
	channelString TEXT;
BEGIN
	SELECT 
	INTO channelString
		string_agg( 
			CONCAT(
				  'C,'
				, pkchannelID
				, ','
				, name
				, ','
				, tblSensor.location
				, ','
				, fkStationID
			)
			, E'\n' 
		)
	FROM tblChannel
	JOIN tblSensor
		ON tblChannel.fkSensorID = tblSensor.pkSensorID
	WHERE tblSensor.fkStationID = any(stationIDs)
	AND NOT tblChannel."isIgnored" ;

	RETURN channelString;
	
END;
$_$;


ALTER FUNCTION public.fnsclgetchannels(integer[]) OWNER TO postgres;

--
-- Name: fnsclgetdates(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION fnsclgetdates() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
	dateString TEXT;
BEGIN
	
	SELECT INTO dateString
		string_agg(
			"date"
			, E'\n'
		)
	FROM (

	SELECT CONCAT('DS,', MIN(date)) as date
	  FROM tbldate
	  UNION
	SELECT CONCAT('DE,', MAX(date)) as date
	  FROM tbldate
	) dates; --to_char('2012-03-01'::date, 'J')::INT  || to_date(2456013::text, 'J')

	RETURN dateString;
END;
$$;


ALTER FUNCTION public.fnsclgetdates() OWNER TO postgres;

--
-- Name: fnsclgetgroups(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION fnsclgetgroups() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
	groupString TEXT;
BEGIN


	
	SELECT 
	INTO groupString
		string_agg( DISTINCT
			CONCAT(
				  'G,'
				, gp.pkGroupID
				, ','
				, gp."name"
				, ','
				, gp."fkGroupTypeID"

			    
			)
			, E'\n' 
		)
	FROM "tblGroup" gp;
		

	RETURN groupString;
	
END;
$$;


ALTER FUNCTION public.fnsclgetgroups() OWNER TO postgres;

--
-- Name: fnsclgetgrouptypes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION fnsclgetgrouptypes() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
	groupTypeString TEXT;
BEGIN


         SELECT                                                              
         INTO groupTypeString                                                
                 string_agg( groupTypeData                                   
                         , E'\n'                                             
                 )                                                           
                 FROM                                                        
                         (SELECT                                             
                                 CONCAT(                                     
                                           'T,'                              
                                         , "pkGroupTypeID"                   
                                         , ','                               
                                         , "tblGroupType".name               
                                         ,','                                
                                         , string_agg(                       
                                                   "tblGroup".pkGroupID::text
                                                 , ','                       
                                                 ORDER BY "tblGroup".name)   
                                 ) AS groupTypeData                          
                         FROM "tblGroupType"                                 
                         Join "tblGroup"                                     
                                 ON "fkGroupTypeID" = "pkGroupTypeID"        
                         GROUP BY "pkGroupTypeID"                            
                         ORDER BY "tblGroupType".name) AS grouptypes         
         ;                                                                   
                                                                             
         RETURN groupTypeString;
	
END;
$$;


ALTER FUNCTION public.fnsclgetgrouptypes() OWNER TO postgres;

--
-- Name: fnsclgetmetrics(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION fnsclgetmetrics() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
	metricString TEXT;
BEGIN


	
	SELECT 
	INTO metricString
		string_agg( 
			CONCAT(
				  'M,'
				, pkMetricID
				, ','
				, coalesce(DisplayName, name, 'No name')

			    
			)
			, E'\n' 
		)
	FROM tblMetric;

	RETURN metricString;
	
END;
$$;


ALTER FUNCTION public.fnsclgetmetrics() OWNER TO postgres;

--
-- Name: fnsclgetpercentage(double precision, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION fnsclgetpercentage(double precision, character varying) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
	valueIn alias for $1;
	metricName alias for $2;
	percent double precision;
	isNum boolean;
BEGIN

	SELECT TRUE INTO isNum;
	CASE metricName

		--State of Health
		WHEN 'AvailabilityMetric' THEN
			SELECT valueIN INTO percent;
		WHEN 'GapCountMetric' THEN
			SELECT (100.0 - 15*(valueIn - 0.00274)/0.992) INTO percent;
		WHEN 'MassPositionMetric' THEN
			SELECT (100.0 - 15*(valueIn - 3.52)/10.79) INTO percent;
		WHEN 'TimingQualityMetric' THEN
			SELECT valueIN INTO percent;
		WHEN 'DeadChannelMetric:4-8' THEN
			SELECT (valueIN*100) INTO percent;
		
		--Coherence
		WHEN 'CoherencePBM:4-8' THEN
			SELECT (100.0 - 15*(1 - valueIn)/0.0377) INTO percent;
		WHEN 'CoherencePBM:18-22' THEN
			SELECT (100.0 - 15*(0.99 - valueIn)/0.12) INTO percent;
		WHEN 'CoherencePBM:90-110' THEN
			SELECT (100.0 - 15*(0.93 - valueIn)/0.0337) INTO percent;
		WHEN 'CoherencePBM:200-500' THEN
			SELECT (100.0 - 15*(0.83 - valueIn)/0.346) INTO percent;

		--Power Difference
		WHEN 'DifferencePBM:4-8' THEN
			SELECT (100.0 - 15*(abs(valueIn) - 0.01)/0.348) INTO percent;
		WHEN 'DifferencePBM:18-22' THEN
			SELECT (100.0 - 15*(abs(valueIn) - 0.01)/1.17) INTO percent;
		WHEN 'DifferencePBM:90-110' THEN
			SELECT (100.0 - 15*(abs(valueIn) - 0.04)/4.66) INTO percent;
		WHEN 'DifferencePBM:200-500' THEN
			SELECT (100.0 - 15*(abs(valueIn) - 0.03)/5.97) INTO percent;

		--Noise/StationDeviationMetric
		WHEN 'StationDeviationMetric:4-8' THEN
			SELECT (100.0 - 15*(abs(valueIn) - 0.11)/3.32) INTO percent;
		WHEN 'StationDeviationMetric:18-22' THEN
			SELECT (100.0 - 15*(abs(valueIn) - 0.17)/2.57) INTO percent;
		WHEN 'StationDeviationMetric:90-110' THEN
			SELECT (100.0 - 15*(abs(valueIn) - 0.02)/2.88) INTO percent;
		WHEN 'StationDeviationMetric:200-500' THEN
			SELECT (100.0 - 15*(abs(valueIn) - 0.07)/2.90) INTO percent;

		--NLNM Deviation
		WHEN 'NLNMDeviationMetric:4-8' THEN
			SELECT (100.0 - 15*(valueIn - 3.33)/12.53) INTO percent;
		WHEN 'NLNMDeviationMetric:18-22' THEN
			SELECT (100.0 - 15*(valueIn - 13.41)/12.64) INTO percent;
		WHEN 'NLNMDeviationMetric:90-110' THEN
			SELECT (100.0 - 15*(valueIn - 13.57)/14.79) INTO percent;
		WHEN 'NLNMDeviationMetric:200-500' THEN
			SELECT (100.0 - 15*(valueIn - 20.74)/15.09) INTO percent;

		--Calibrations Does not exist when added, name may need changed.
		WHEN 'CalibrationMetric' THEN
			SELECT (100 - 10*power(valueIn/365, 2)) INTO percent;
		WHEN 'MeanError' THEN
			SELECT (100 - 500*valueIn) INTO percent;
		ELSE
			SELECT FALSE INTO isNum;
	END CASE;

	IF isNum = TRUE THEN
		IF percent >= 100 THEN
			RETURN '100';
		ELSIF percent <= 0 THEN
			RETURN '0';
		ELSE
			RETURN percent::text; 
		END IF;
	ELSE
		RETURN 'n'; --Front end strips out anything that isn't a number
	END IF;
END;
$_$;


ALTER FUNCTION public.fnsclgetpercentage(double precision, character varying) OWNER TO postgres;

--
-- Name: fnsclgetstationdata(integer[], integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION fnsclgetstationdata(integer[], integer, date, date) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
	stationIDs alias for $1;
	metricID alias for $2;
	startDate alias for $3;
	endDate alias for $4;
	stationData TEXT;
	computeType int;
	metricName TEXT;
BEGIN
/*SELECT sum(value) as valueSum, sum(day) as dayCount, sen1.fkStationID, metricID
FROM(
    (
    --#EXPLAIN EXTENDED
    Select    --#pc1.valueSum, pc1.dayCount
            pc1.valueSum as value, pc1.dayCount as day
            , pc1.fkMetricID as metricID, pc1.fkChannelID as channelID
        FROM tblPreComputed pc1 --#FORCE INDEX (idx_tblPreComputed_Dates_fkParent)
        LEFT OUTER JOIN tblPreComputed pc2 --FORCE INDEX FOR JOIN (idx_tblPreComputed_Dates_primary)
            ON pc1.fkParentPreComputedID = pc2.pkPreComputedID 
                AND 2455988 <= pc2.start
                AND 2456018 >= pc2."end"
        WHERE   2455988 <= pc1.start
            AND 2456018 >= pc1."end"
            AND pc2.pkPreComputedID IS NULL
            
        --#GROUP BY pc1.fkChannelID, pc1.fkMetricID ORDER BY NULL
    )
    UNION ALL
    (
   -- #EXPLAIN EXTENDED
    Select   md1.value as value, 1 as day
            , md1.fkMetricID as metricID, md1.fkChannelID as channelID
        FROM tblMetricData md1
        WHERE 
            (date >= 2455988
                AND date <=  2455988 + 10 - (2455988 % 10) --#2455990
            )
            OR
            (date >=  2456018 - (2456018 % 10) --#2456010
                AND date <= 2456018)

        --#GROUP BY md1.fkChannelID, md1.fkMetricID ORDER BY NULL
    )
) semisum
INNER JOIN tblChannel ch1
    ON semisum.channelID = ch1.pkChannelID
        AND NOT ch1."isIgnored"
INNER JOIN tblSensor sen1
    ON ch1.fkSensorID = sen1.pkSensorID

GROUP BY sen1.fkStationID, semisum.metricID
*/
	Select fkComputeTypeID, name from tblMetric where pkMetricID = metricID INTO computeType, metricName;
	CASE computeType
		--Metric Data
		WHEN 1 THEN
			--Average across total number of values
			SELECT INTO stationData string_agg(CONCAT(id, ',',avg, ',', fnsclGetPercentage(avg, metricName)), E'\n') FROM (
				SELECT sen1.fkStationID as id, round((SUM(md1.value)/count(md1.*))::numeric, 4)::numeric as avg
				FROM tblMetricData md1
				JOIN tblChannel ch1
					ON ch1.pkChannelID = md1.fkChannelID
					AND NOT ch1."isIgnored"
				JOIN tblSensor sen1
					ON ch1.fkSensorID = sen1.pkSensorID
				WHERE sen1.fkStationID = any(stationIDs)
					AND 
					md1.date >= to_char(startDate, 'J')::INT
					AND md1.date <= to_char(endDate, 'J')::INT
					AND md1.fkMetricID = metricID
				GROUP BY sen1.fkStationID ) stations;
		WHEN 2 THEN
			--Average across days NOT ACCURATE
			select '2' into stationData;
		WHEN 3 THEN
			--Count all values, return sum
			SELECT INTO stationData string_agg(CONCAT(id, ',',sum, ',', fnsclGetPercentage(sum, metricName)), E'\n') FROM (
				SELECT sen1.fkStationID as id, round(SUM(md1.value)::numeric, 0) as sum
				FROM tblMetricData md1
				JOIN tblChannel ch1
					ON ch1.pkChannelID = md1.fkChannelID
					AND NOT ch1."isIgnored"
				JOIN tblSensor sen1
					ON ch1.fkSensorID = sen1.pkSensorID
				WHERE sen1.fkStationID = any(stationIDs)
					AND 
					md1.date >= to_char(startDate, 'J')::INT
					AND md1.date <= to_char(endDate, 'J')::INT
					AND md1.fkMetricID = metricID
				GROUP BY sen1.fkStationID ) stations;
		WHEN 5 THEN
			--Calculate date since last calibration
			SELECT INTO stationData string_agg(CONCAT(id, ',',sum, ',', fnsclGetPercentage(sum, metricName)), E'\n') FROM (
				SELECT sen1.fkStationID as id, round((to_char(endDate, 'J')::INT-max(date))::numeric, 4) as sum
				FROM tblMetricstringData md1
				JOIN tblChannel ch1
					ON ch1.pkChannelID = md1.fkChannelID
					AND NOT ch1."isIgnored"
				JOIN tblSensor sen1
					ON ch1.fkSensorID = sen1.pkSensorID
				WHERE sen1.fkStationID = any(stationIDs)
					AND md1.date <= to_char(endDate, 'J')::INT
					AND md1.fkMetricID = metricID
				GROUP BY sen1.fkStationID ) stations;
		WHEN 6 THEN
			--Average across number of values
			select NULL into stationData;
		ELSE
			--Insert error into error log
			select 'Error' into stationData;
	END CASE;

	
	RETURN stationData;
END;
$_$;


ALTER FUNCTION public.fnsclgetstationdata(integer[], integer, date, date) OWNER TO postgres;

--
-- Name: fnsclgetstationplotdata(integer, integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION fnsclgetstationplotdata(integer, integer, date, date) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
	stationID alias for $1;
	metricID alias for $2;
	startDate alias for $3;
	endDate alias for $4;
	stationPlotData TEXT;
	computeType int;
BEGIN
	
	Select fkComputeTypeID from tblMetric where pkMetricID = metricID INTO computeType;
	CASE computeType
		--Metric Data
		WHEN 1 THEN
			--Average across total number of values
			SELECT INTO stationPlotData string_agg(CONCAT(sdate, ',',avg), E'\n') FROM (
				SELECT to_date(md1.date::text, 'J') as sdate, round((SUM(md1.value)/count(md1.*))::numeric, 4) as avg
				FROM tblMetricData md1
				JOIN tblChannel ch1
					ON ch1.pkChannelID = md1.fkChannelID
					AND NOT ch1."isIgnored"
				JOIN tblSensor sen1
					ON ch1.fkSensorID = sen1.pkSensorID
				WHERE sen1.fkStationID = stationID
					AND 
					md1.date >= to_char(startDate, 'J')::INT
					AND md1.date <= to_char(endDate, 'J')::INT
					AND md1.fkMetricID = metricID
				GROUP BY md1.date ) stations;
		WHEN 2 THEN
			--Average across days NOT ACCURATE
			select '2' into stationPlotData;
		WHEN 3 THEN
			--Count all values, return sum
			SELECT INTO stationPlotData string_agg(CONCAT(sdate, ',',avg), E'\n') FROM (
				SELECT to_date(md1.date::text, 'J') as sdate, round(SUM(md1.value)::numeric, 4) as avg
				FROM tblMetricData md1
				JOIN tblChannel ch1
					ON ch1.pkChannelID = md1.fkChannelID
					AND NOT ch1."isIgnored"
				JOIN tblSensor sen1
					ON ch1.fkSensorID = sen1.pkSensorID
				WHERE sen1.fkStationID = stationID
					AND 
					md1.date >= to_char(startDate, 'J')::INT
					AND md1.date <= to_char(endDate, 'J')::INT
					AND md1.fkMetricID = metricID
				GROUP BY md1.date ) stations;
		--Calibration Data
		WHEN 5 THEN
			--Calculate data between last calibrations
			select '5' into stationPlotData;
		WHEN 6 THEN
			--Average across number of values
			select '6' into stationPlotData;
		ELSE
			--Insert error into error log
			select 'Error' into stationPlotData;
	END CASE;

	
	RETURN stationPlotData;
END;
$_$;


ALTER FUNCTION public.fnsclgetstationplotdata(integer, integer, date, date) OWNER TO postgres;

--
-- Name: fnsclgetstations(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION fnsclgetstations() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
	stationString TEXT;
BEGIN


	
	SELECT 
	INTO stationString
		string_agg(
			CONCAT(
				  'S,'
				, pkstationID
				, ','
				, fkNetworkID
				, ','
				, st1."name"
				, ','
				, groupIDs
			    
			)
			, E'\n' 
		)
	FROM tblStation st1
	JOIN "tblGroup"
		ON st1.fkNetworkID = pkGroupID --to_char('2012-03-01'::date, 'J')::INT  || to_date(2456013::text, 'J')
	JOIN (
		SELECT "fkStationID" as statID, string_agg("fkGroupID"::text, ',') as groupIDs
			FROM "tblStationGroupTie"
			GROUP BY "fkStationID") as gst
		ON st1.pkStationID = gst.statID;

	RETURN stationString;
	
END;
$$;


ALTER FUNCTION public.fnsclgetstations() OWNER TO postgres;

--
-- Name: fnsclisnumeric(text); Type: FUNCTION; Schema: public; Owner: jholland
--

CREATE FUNCTION fnsclisnumeric("inputText" text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
  DECLARE num NUMERIC;
BEGIN
	IF "inputText" = 'NaN' THEN
		RETURN FALSE;
	END IF;

	num = "inputText"::NUMERIC;
	--No exceptions and hasn't returned false yet, so it must be a numeric.
	RETURN TRUE;
	EXCEPTION WHEN invalid_text_representation THEN
	RETURN FALSE;
END;
$$;


ALTER FUNCTION public.fnsclisnumeric("inputText" text) OWNER TO jholland;

--
-- Name: spcomparehash(date, character varying, character varying, character varying, character varying, character varying, bytea); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION spcomparehash(date, character varying, character varying, character varying, character varying, character varying, bytea) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
	nDate alias for $1;
	metricName alias for $2;
	networkName alias for $3;
	stationName alias for $4;
	locationName alias for $5;
	channelName alias for $6;
	hashIN alias for $7;
	hashID int;
	debug text;

BEGIN
--select name from tblStation into debug;
--RAISE NOTICE 'stationID(%)', debug;

	SELECT 
	  tblhash."pkHashID"
	FROM 
	  public.tblhash, 
	  public.tblmetricdata, 
	  public.tblmetric, 
	  public.tblchannel, 
	  public.tblsensor, 
	  public.tblstation, 
	  public."tblGroup"
	WHERE 
	  --JOINS
	  tblhash."pkHashID" = tblmetricdata."fkHashID" AND
	  tblmetricdata.fkmetricid = tblmetric.pkmetricid AND
	  tblmetricdata.fkchannelid = tblchannel.pkchannelid AND
	  tblchannel.fksensorid = tblsensor.pksensorid AND
	  tblsensor.fkstationid = tblstation.pkstationid AND
	  tblstation.fknetworkid = "tblGroup".pkgroupid AND
	  --Criteria
	  tblMetric.name = metricName AND
	  "tblGroup".name = networkName AND
	  tblStation.name = stationName AND
	  tblSensor.location = locationName AND
	  tblChannel.name = channelName
	  
	INTO hashID;

	IF hashID IS NOT NULL THEN
		RETURN 1;
	ELSE
		RETURN 0;
	END IF;
        
    END;
$_$;


ALTER FUNCTION public.spcomparehash(date, character varying, character varying, character varying, character varying, character varying, bytea) OWNER TO postgres;

--
-- Name: spgetmetricvalue(date, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION spgetmetricvalue(date, character varying, character varying, character varying, character varying, character varying) RETURNS double precision
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
	nDate alias for $1;
	metricName alias for $2;
	networkName alias for $3;
	stationName alias for $4;
	locationName alias for $5;
	channelName alias for $6;
	value double precision;
	debug text;

BEGIN
--select name from tblStation into debug;
--RAISE NOTICE 'stationID(%)', debug;

	SELECT 
	  tblMetricData.value
	FROM 
	  
	  public.tblmetricdata, 
	  public.tblmetric, 
	  public.tblchannel, 
	  public.tblsensor, 
	  public.tblstation, 
	  public."tblGroup"
	WHERE 
	  --JOINS
	   tblmetricdata.fkmetricid = tblmetric.pkmetricid AND
	  tblmetricdata.fkchannelid = tblchannel.pkchannelid AND
	  tblchannel.fksensorid = tblsensor.pksensorid AND
	  tblsensor.fkstationid = tblstation.pkstationid AND
	  tblstation.fknetworkid = "tblGroup".pkgroupid AND
	  --Criteria
	  tblMetric.name = metricName AND
	  "tblGroup".name = networkName AND
	  tblStation.name = stationName AND
	  tblSensor.location = locationName AND
	  tblChannel.name = channelName AND
	  tblMetricData.date = to_char(nDate, 'J')::INT
	INTO value;
	RETURN value;
        
    END;
$_$;


ALTER FUNCTION public.spgetmetricvalue(date, character varying, character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: spgetmetricvaluedigest(date, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION spgetmetricvaluedigest(date, character varying, character varying, character varying, character varying, character varying, OUT bytea) RETURNS bytea
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
	nDate alias for $1;
	metricName alias for $2;
	networkName alias for $3;
	stationName alias for $4;
	locationName alias for $5;
	channelName alias for $6;
	hash alias for $7;
	debug text;

BEGIN

--select name from tblStation into debug;
--RAISE NOTICE 'stationID(%)', debug;

--SELECT to_char('2012-06-19'::DATE, 'J')::INT;

	SELECT 
	  tblHash.hash
	FROM 
	  public.tblhash,
	  public.tblmetricdata, 
	  public.tblmetric, 
	  public.tblchannel, 
	  public.tblsensor, 
	  public.tblstation, 
	  public."tblGroup"
	WHERE 
	  --JOINS
	  tblmetricdata."fkHashID" = tblHash."pkHashID" AND
	  tblmetricdata.fkmetricid = tblmetric.pkmetricid AND
	  tblmetricdata.fkchannelid = tblchannel.pkchannelid AND
	  tblchannel.fksensorid = tblsensor.pksensorid AND
	  tblsensor.fkstationid = tblstation.pkstationid AND
	  tblstation.fknetworkid = "tblGroup".pkgroupid AND
	  --Criteria
	  tblMetric.name = metricName AND
	  "tblGroup".name = networkName AND
	  tblStation.name = stationName AND
	  tblSensor.location = locationName AND
	  tblChannel.name = channelName AND
	  tblMetricData.date = to_char(nDate, 'J')::INT
	INTO hash;
	
        
    END;
$_$;


ALTER FUNCTION public.spgetmetricvaluedigest(date, character varying, character varying, character varying, character varying, character varying, OUT bytea) OWNER TO postgres;

--
-- Name: spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, double precision, bytea); Type: FUNCTION; Schema: public; Owner: jholland
--

CREATE FUNCTION spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, double precision, bytea) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
	nDate alias for $1;
	metricName alias for $2;
	networkName alias for $3;
	stationName alias for $4;
	locationName alias for $5;
	channelName alias for $6;
	valueIN alias for $7;
	hashIN alias for $8;
	networkID int;
	stationID int;
	sensorID int;
	channelID int;
	metricID int;
	hashID int;
	debug text;

BEGIN
--INSERT INTO tblerrorlog (errortime, errormessage) values (CURRENT_TIMESTAMP,'It inserted'||nDate||' '||locationName||' '||channelName||' '||stationName||' '||metricName);

    IF fnsclisnumeric(valueIN::TEXT) = FALSE THEN
	INSERT INTO tblerrorlog (errortime, errormessage) 
		VALUES (
			CURRENT_TIMESTAMP,
			'Non Numeric value: Nothing Inserted '||nDate||' '||locationName||' '||channelName||' '||stationName||' '||metricName||' '||valueIN);
	RETURN;
    END IF;

--Insert network if doesn't exist then get ID

    LOCK TABLE "tblGroup" IN SHARE ROW EXCLUSIVE MODE;
    INSERT INTO "tblGroup" (name,"fkGroupTypeID")
	SELECT networkName, 1  --Group Type 1 is Network
	WHERE NOT EXISTS (
	    SELECT * FROM "tblGroup" WHERE name = networkName
	);

    SELECT pkGroupID
        FROM "tblGroup"
        WHERE name = networkName
    INTO networkID;

--Insert station if doesn't exist then get ID
    LOCK TABLE tblStation IN SHARE ROW EXCLUSIVE MODE;
    INSERT INTO tblStation (name,fkNetworkID)
	SELECT stationName, networkID
	WHERE NOT EXISTS (
	    SELECT * FROM tblStation WHERE name = stationName AND fkNetworkID = networkID
	);
    
    SELECT pkStationID
        FROM tblStation
        WHERE name = stationName AND fkNetworkID = networkID
    INTO stationID;

--Ties the Station to its Network for the GUI to use.
    LOCK TABLE "tblStationGroupTie" IN SHARE ROW EXCLUSIVE MODE;
    INSERT INTO "tblStationGroupTie" ("fkGroupID", "fkStationID")
	SELECT networkID, stationID
	WHERE NOT EXISTS (
	    SELECT * FROM "tblStationGroupTie" WHERE "fkGroupID" = networkID AND "fkStationID" = stationID
	);

--Insert sensor if doesn't exist then get ID
    LOCK TABLE tblSensor IN SHARE ROW EXCLUSIVE MODE;
    INSERT INTO tblSensor (location,fkStationID)
	SELECT locationName, stationID
	WHERE NOT EXISTS (
	    SELECT * FROM tblSensor WHERE location = locationName AND fkStationID = stationID
	);
    
    SELECT pkSensorID
        FROM tblSensor
        WHERE location = locationName AND fkStationID = stationID
    INTO sensorID;
    
--Insert channel if doesn't exist then get ID
    LOCK TABLE tblChannel IN SHARE ROW EXCLUSIVE MODE;
    INSERT INTO tblChannel (name, fkSensorID)
	SELECT channelName, sensorID
	WHERE NOT EXISTS (
	    SELECT * FROM tblChannel WHERE name = channelName AND fkSensorID = sensorID
	);
    
    SELECT pkChannelID
        FROM tblChannel
        WHERE name = channelName AND fkSensorID = sensorID
    INTO channelID;
    
--Insert metric if doesn't exist then get ID
    LOCK TABLE tblMetric IN SHARE ROW EXCLUSIVE MODE;
    INSERT INTO tblMetric (name, fkComputeTypeID, displayName)
	SELECT metricName, 1, metricName --Compute Type 1 is averaged over channel and days.
	WHERE NOT EXISTS (
	    SELECT * FROM tblMetric WHERE name = metricName
	);
    
    SELECT pkMetricID
        FROM tblMetric
        WHERE name = metricName
    INTO metricID;

--Insert hash if doesn't exist then get ID
    LOCK TABLE tblHash IN SHARE ROW EXCLUSIVE MODE;
    INSERT INTO tblHash (hash)
	SELECT hashIN
	WHERE NOT EXISTS (
	    SELECT * FROM tblHash WHERE hash = hashIN
	);
    
   --select pkHashID from tblStation into debug;
--RAISE NOTICE 'stationID(%)', debug;
    SELECT "pkHashID"
        FROM tblHash
        WHERE hash = hashIN
    INTO hashID;
    
--Insert date into tblDate
    LOCK TABLE tblDate IN SHARE ROW EXCLUSIVE MODE;
    BEGIN
    INSERT INTO tblDate (pkDateID, date)
	SELECT to_char(nDate, 'J')::INT, nDate
	WHERE NOT EXISTS (
	    SELECT * FROM tblDate WHERE date = nDate
	);
    
        
    EXCEPTION WHEN unique_violation THEN
        INSERT INTO tblErrorLog (errortime, errormessage)
	    VALUES (CURRENT_TIMESTAMP, "tblDate has a date with incorrect pkDateID date:"
	    +to_char(nDate, 'J')::INT);
    END;
--Insert/Update metric value for day
    UPDATE tblMetricData 
	SET value = valueIN, "fkHashID" = hashID 
	WHERE date = to_char(nDate, 'J')::INT AND fkMetricID = metricID AND fkChannelID = channelID;
    IF NOT FOUND THEN
    BEGIN
	INSERT INTO tblMetricData (fkChannelID, date, fkMetricID, value, "fkHashID") 
	    VALUES (channelID, to_char(nDate, 'J')::INT, metricID, valueIN, hashID);
    --We could remove this possibility with a table lock, but I fear locking such a large table.
    EXCEPTION WHEN unique_violation THEN
	INSERT INTO tblErrorLog (errortime, errormessage)
	    VALUES (CURRENT_TIMESTAMP, "Multiple simultaneous data inserts for metric:"+metricID+
	    " date:"+to_char(nDate, 'J')::INT);
    END;
    END IF;
    
        
    END;
$_$;


ALTER FUNCTION public.spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, double precision, bytea) OWNER TO jholland;

--
-- Name: spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea); Type: FUNCTION; Schema: public; Owner: jholland
--

CREATE FUNCTION spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
	nDate alias for $1;
	metricName alias for $2;
	networkName alias for $3;
	stationName alias for $4;
	locationName alias for $5;
	channelName alias for $6;
	valueIN alias for $7;
	hashIN alias for $8;
	networkID int;
	stationID int;
	sensorID int;
	channelID int;
	metricID int;
	hashID int;
	debug text;

BEGIN
INSERT INTO tblerrorlog (errortime, errormessage) values (CURRENT_TIMESTAMP,'It inserted'||nDate||' '||locationName||' '||channelName||' '||stationName||' '||metricName);

--Insert network if doesn't exist then get ID
    BEGIN
        INSERT INTO "tblGroup" (name,"fkGroupTypeID") VALUES (networkName, 1); --Group Type 1 is Network
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkGroupID
        FROM "tblGroup"
        WHERE name = networkName
    INTO networkID;

--Insert station if doesn't exist then get ID
    BEGIN
        INSERT INTO tblStation(name,fkNetworkID) VALUES (stationName, networkID);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkStationID
        FROM tblStation
        WHERE name = stationName AND fkNetworkID = networkID
    INTO stationID;
    
    BEGIN --Ties the Station to its Network for the GUI to use.
        INSERT INTO "tblStationGroupTie" ("fkGroupID", "fkStationID")
		VALUES (networkID, stationID);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;

--Insert sensor if doesn't exist then get ID
    BEGIN
        INSERT INTO tblSensor(location,fkStationID) VALUES (locationName, stationID); 
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkSensorID
        FROM tblSensor
        WHERE location = locationName AND fkStationID = stationID
    INTO sensorID;
--Insert channel if doesn't exist then get ID
    BEGIN
        INSERT INTO tblChannel(name,fkSensorID) VALUES (channelName, sensorID); 
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkChannelID
        FROM tblChannel
        WHERE name = channelName AND fkSensorID = sensorID
    INTO channelID;
--Insert metric if doesn't exist then get ID
    BEGIN
        INSERT INTO tblMetric(name, fkComputeTypeID, displayName) VALUES (metricName, 1, metricName); --Compute Type 1 is averaged over channel and days.
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkMetricID
        FROM tblMetric
        WHERE name = metricName
    INTO metricID;

--Insert hash if doesn't exist then get ID
    BEGIN
        INSERT INTO tblHash(hash) VALUES (hashIN); 
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
   --select pkHashID from tblStation into debug;
--RAISE NOTICE 'stationID(%)', debug;
    SELECT "pkHashID"
        FROM tblHash
        WHERE hash = hashIN
    INTO hashID;
    
--Insert date into tblDate
    BEGIN
        INSERT INTO tblDate (pkDateID, date)
	    VALUES (to_char(nDate, 'J')::INT, nDate);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
--Insert/Update metric value for day
    UPDATE tblmetricstringdata 
	SET value = valueIN, "fkHashID" = hashID 
	WHERE date = to_char(nDate, 'J')::INT AND fkMetricID = metricID AND fkChannelID = channelID;
    IF NOT found THEN
    BEGIN
	INSERT INTO tblmetricstringdata (fkChannelID, date, fkMetricID, value, "fkHashID") 
	    VALUES (channelID, to_char(nDate, 'J')::INT, metricID, valueIN, hashID);
    EXCEPTION WHEN unique_violation THEN
	INSERT INTO tblErrorLog (errortime, errormessage)
	    VALUES (CURRENT_TIMESTAMP, "Multiple simultaneous data inserts for metric:"+metricID+
	    " date:"+to_char(nDate, 'J')::INT);
    END;
    END IF;
    
        
    END;
$_$;


ALTER FUNCTION public.spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) OWNER TO jholland;

--
-- Name: spinsertmetricstringdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea); Type: FUNCTION; Schema: public; Owner: jholland
--

CREATE FUNCTION spinsertmetricstringdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
	nDate alias for $1;
	metricName alias for $2;
	networkName alias for $3;
	stationName alias for $4;
	locationName alias for $5;
	channelName alias for $6;
	valueIN alias for $7;
	hashIN alias for $8;
	networkID int;
	stationID int;
	sensorID int;
	channelID int;
	metricID int;
	hashID int;
	debug text;

BEGIN
INSERT INTO tblerrorlog (errortime, errormessage) values (CURRENT_TIMESTAMP,'It inserted'||nDate||' '||locationName||' '||channelName||' '||stationName||' '||metricName);

--Insert network if doesn't exist then get ID
    BEGIN
        INSERT INTO "tblGroup" (name,"fkGroupTypeID") VALUES (networkName, 1); --Group Type 1 is Network
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkGroupID
        FROM "tblGroup"
        WHERE name = networkName
    INTO networkID;

--Insert station if doesn't exist then get ID
    BEGIN
        INSERT INTO tblStation(name,fkNetworkID) VALUES (stationName, networkID);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkStationID
        FROM tblStation
        WHERE name = stationName AND fkNetworkID = networkID
    INTO stationID;
    
    BEGIN --Ties the Station to its Network for the GUI to use.
        INSERT INTO "tblStationGroupTie" ("fkGroupID", "fkStationID")
		VALUES (networkID, stationID);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;

--Insert sensor if doesn't exist then get ID
    BEGIN
        INSERT INTO tblSensor(location,fkStationID) VALUES (locationName, stationID); 
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkSensorID
        FROM tblSensor
        WHERE location = locationName AND fkStationID = stationID
    INTO sensorID;
--Insert channel if doesn't exist then get ID
    BEGIN
        INSERT INTO tblChannel(name,fkSensorID) VALUES (channelName, sensorID); 
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkChannelID
        FROM tblChannel
        WHERE name = channelName AND fkSensorID = sensorID
    INTO channelID;
--Insert metric if doesn't exist then get ID
    BEGIN
        INSERT INTO tblMetric(name, fkComputeTypeID, displayName) VALUES (metricName, 1, metricName); --Compute Type 1 is averaged over channel and days.
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkMetricID
        FROM tblMetric
        WHERE name = metricName
    INTO metricID;

--Insert hash if doesn't exist then get ID
    BEGIN
        INSERT INTO tblHash(hash) VALUES (hashIN); 
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
   --select pkHashID from tblStation into debug;
--RAISE NOTICE 'stationID(%)', debug;
    SELECT "pkHashID"
        FROM tblHash
        WHERE hash = hashIN
    INTO hashID;
    
--Insert date into tblDate
    BEGIN
        INSERT INTO tblDate (pkDateID, date)
	    VALUES (to_char(nDate, 'J')::INT, nDate);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
--Insert/Update metric value for day
    UPDATE tblmetricstringdata 
	SET value = valueIN, "fkHashID" = hashID 
	WHERE date = to_char(nDate, 'J')::INT AND fkMetricID = metricID AND fkChannelID = channelID;
    IF NOT found THEN
    BEGIN
	INSERT INTO tblmetricstringdata (fkChannelID, date, fkMetricID, value, "fkHashID") 
	    VALUES (channelID, to_char(nDate, 'J')::INT, metricID, valueIN, hashID);
    EXCEPTION WHEN unique_violation THEN
	INSERT INTO tblErrorLog (errortime, errormessage)
	    VALUES (CURRENT_TIMESTAMP, "Multiple simultaneous data inserts for metric:"+metricID+
	    " date:"+to_char(nDate, 'J')::INT);
    END;
    END IF;
    
        
    END;
$_$;


ALTER FUNCTION public.spinsertmetricstringdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) OWNER TO jholland;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: tblGroup; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE "tblGroup" (
    pkgroupid integer NOT NULL,
    name character varying(36) NOT NULL,
    "isIgnored" boolean DEFAULT false NOT NULL,
    "fkGroupTypeID" integer
);


ALTER TABLE public."tblGroup" OWNER TO postgres;

--
-- Name: tblGroupType; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE "tblGroupType" (
    "pkGroupTypeID" integer NOT NULL,
    name character varying(16) NOT NULL
);


ALTER TABLE public."tblGroupType" OWNER TO postgres;

--
-- Name: tblGroupType_pkGroupTypeID_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "tblGroupType_pkGroupTypeID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."tblGroupType_pkGroupTypeID_seq" OWNER TO postgres;

--
-- Name: tblGroupType_pkGroupTypeID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "tblGroupType_pkGroupTypeID_seq" OWNED BY "tblGroupType"."pkGroupTypeID";


--
-- Name: tblStationGroupTie; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE "tblStationGroupTie" (
    "fkGroupID" integer NOT NULL,
    "fkStationID" integer NOT NULL
);


ALTER TABLE public."tblStationGroupTie" OWNER TO postgres;

--
-- Name: tblcalibrationdata; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tblcalibrationdata (
    pkcalibrationdataid integer NOT NULL,
    fkchannelid integer NOT NULL,
    year smallint NOT NULL,
    month smallint NOT NULL,
    day smallint NOT NULL,
    date date NOT NULL,
    calyear integer NOT NULL,
    calmonth smallint NOT NULL,
    calday smallint NOT NULL,
    caldate date NOT NULL,
    fkmetcaltypeid integer NOT NULL,
    value double precision NOT NULL,
    fkmetricid integer NOT NULL
);


ALTER TABLE public.tblcalibrationdata OWNER TO postgres;

--
-- Name: tblcalibrationdata_pkcalibrationdataid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tblcalibrationdata_pkcalibrationdataid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblcalibrationdata_pkcalibrationdataid_seq OWNER TO postgres;

--
-- Name: tblcalibrationdata_pkcalibrationdataid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tblcalibrationdata_pkcalibrationdataid_seq OWNED BY tblcalibrationdata.pkcalibrationdataid;


--
-- Name: tblchannel; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tblchannel (
    pkchannelid integer NOT NULL,
    fksensorid integer NOT NULL,
    name character varying(16) NOT NULL,
    derived integer DEFAULT 0 NOT NULL,
    "isIgnored" boolean DEFAULT false NOT NULL
);


ALTER TABLE public.tblchannel OWNER TO postgres;

--
-- Name: tblchannel_pkchannelid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tblchannel_pkchannelid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblchannel_pkchannelid_seq OWNER TO postgres;

--
-- Name: tblchannel_pkchannelid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tblchannel_pkchannelid_seq OWNED BY tblchannel.pkchannelid;


--
-- Name: tblcomputetype; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tblcomputetype (
    pkcomputetypeid integer NOT NULL,
    name character varying(8) NOT NULL,
    description character varying(2000) DEFAULT NULL::character varying,
    iscalibration boolean DEFAULT false NOT NULL
);


ALTER TABLE public.tblcomputetype OWNER TO postgres;

--
-- Name: tblcomputetype_pkcomputetypeid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tblcomputetype_pkcomputetypeid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblcomputetype_pkcomputetypeid_seq OWNER TO postgres;

--
-- Name: tblcomputetype_pkcomputetypeid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tblcomputetype_pkcomputetypeid_seq OWNED BY tblcomputetype.pkcomputetypeid;


--
-- Name: tbldate; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tbldate (
    pkdateid integer NOT NULL,
    date date NOT NULL
);


ALTER TABLE public.tbldate OWNER TO postgres;

--
-- Name: tblerrorlog; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tblerrorlog (
    pkerrorlogid integer NOT NULL,
    errortime timestamp without time zone,
    errormessage character varying(20480) DEFAULT NULL::character varying
);


ALTER TABLE public.tblerrorlog OWNER TO postgres;

--
-- Name: tblerrorlog_pkerrorlogid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tblerrorlog_pkerrorlogid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblerrorlog_pkerrorlogid_seq OWNER TO postgres;

--
-- Name: tblerrorlog_pkerrorlogid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tblerrorlog_pkerrorlogid_seq OWNED BY tblerrorlog.pkerrorlogid;


--
-- Name: tblhash; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tblhash (
    "pkHashID" bigint NOT NULL,
    hash bytea NOT NULL
);


ALTER TABLE public.tblhash OWNER TO postgres;

--
-- Name: tblhash_pkHashID_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE "tblhash_pkHashID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."tblhash_pkHashID_seq" OWNER TO postgres;

--
-- Name: tblhash_pkHashID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "tblhash_pkHashID_seq" OWNED BY tblhash."pkHashID";


--
-- Name: tblmetadata; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tblmetadata (
    fkchannelid integer NOT NULL,
    epoch timestamp without time zone NOT NULL,
    sensor_info character varying(64) DEFAULT NULL::character varying,
    raw_metadata bytea
);


ALTER TABLE public.tblmetadata OWNER TO postgres;

--
-- Name: tblmetric; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tblmetric (
    pkmetricid integer NOT NULL,
    name character varying(64) NOT NULL,
    fkparentmetricid integer,
    legend character varying(128) DEFAULT NULL::character varying,
    fkcomputetypeid integer NOT NULL,
    displayname character varying(64) DEFAULT NULL::character varying
);


ALTER TABLE public.tblmetric OWNER TO postgres;

--
-- Name: tblmetric_pkmetricid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tblmetric_pkmetricid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblmetric_pkmetricid_seq OWNER TO postgres;

--
-- Name: tblmetric_pkmetricid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tblmetric_pkmetricid_seq OWNED BY tblmetric.pkmetricid;


--
-- Name: tblmetricdata; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tblmetricdata (
    fkchannelid integer NOT NULL,
    date integer NOT NULL,
    fkmetricid integer NOT NULL,
    value double precision NOT NULL,
    "fkHashID" bigint NOT NULL
);


ALTER TABLE public.tblmetricdata OWNER TO postgres;

--
-- Name: COLUMN tblmetricdata.date; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN tblmetricdata.date IS 'Julian date (number of days from Midnight November 4714 BC). This is based on the Gregorian proleptic Julian Day number standard and is natively supported in Postgresql.';


--
-- Name: tblmetricstringdata; Type: TABLE; Schema: public; Owner: jholland; Tablespace: 
--

CREATE TABLE tblmetricstringdata (
    fkchannelid integer NOT NULL,
    date integer NOT NULL,
    fkmetricid integer NOT NULL,
    value text NOT NULL,
    "fkHashID" bigint NOT NULL
);


ALTER TABLE public.tblmetricstringdata OWNER TO jholland;

--
-- Name: COLUMN tblmetricstringdata.date; Type: COMMENT; Schema: public; Owner: jholland
--

COMMENT ON COLUMN tblmetricstringdata.date IS 'Julian date (number of days from Midnight November 4714 BC). This is based on the Gregorian proleptic Julian Day number standard and is natively supported in Postgresql.';


--
-- Name: tblnetwork_pknetworkid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tblnetwork_pknetworkid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblnetwork_pknetworkid_seq OWNER TO postgres;

--
-- Name: tblnetwork_pknetworkid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tblnetwork_pknetworkid_seq OWNED BY "tblGroup".pkgroupid;


--
-- Name: tblsensor; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tblsensor (
    pksensorid integer NOT NULL,
    fkstationid integer NOT NULL,
    location character varying(16) NOT NULL
);


ALTER TABLE public.tblsensor OWNER TO postgres;

--
-- Name: tblsensor_pksensorid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tblsensor_pksensorid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblsensor_pksensorid_seq OWNER TO postgres;

--
-- Name: tblsensor_pksensorid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tblsensor_pksensorid_seq OWNED BY tblsensor.pksensorid;


--
-- Name: tblstation; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tblstation (
    pkstationid integer NOT NULL,
    fknetworkid integer NOT NULL,
    name character varying(16) NOT NULL
);


ALTER TABLE public.tblstation OWNER TO postgres;

--
-- Name: tblstation_pkstationid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tblstation_pkstationid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblstation_pkstationid_seq OWNER TO postgres;

--
-- Name: tblstation_pkstationid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tblstation_pkstationid_seq OWNED BY tblstation.pkstationid;


--
-- Name: pkgroupid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "tblGroup" ALTER COLUMN pkgroupid SET DEFAULT nextval('tblnetwork_pknetworkid_seq'::regclass);


--
-- Name: pkGroupTypeID; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "tblGroupType" ALTER COLUMN "pkGroupTypeID" SET DEFAULT nextval('"tblGroupType_pkGroupTypeID_seq"'::regclass);


--
-- Name: pkcalibrationdataid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblcalibrationdata ALTER COLUMN pkcalibrationdataid SET DEFAULT nextval('tblcalibrationdata_pkcalibrationdataid_seq'::regclass);


--
-- Name: pkchannelid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblchannel ALTER COLUMN pkchannelid SET DEFAULT nextval('tblchannel_pkchannelid_seq'::regclass);


--
-- Name: pkcomputetypeid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblcomputetype ALTER COLUMN pkcomputetypeid SET DEFAULT nextval('tblcomputetype_pkcomputetypeid_seq'::regclass);


--
-- Name: pkerrorlogid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblerrorlog ALTER COLUMN pkerrorlogid SET DEFAULT nextval('tblerrorlog_pkerrorlogid_seq'::regclass);


--
-- Name: pkHashID; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblhash ALTER COLUMN "pkHashID" SET DEFAULT nextval('"tblhash_pkHashID_seq"'::regclass);


--
-- Name: pkmetricid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblmetric ALTER COLUMN pkmetricid SET DEFAULT nextval('tblmetric_pkmetricid_seq'::regclass);


--
-- Name: pksensorid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblsensor ALTER COLUMN pksensorid SET DEFAULT nextval('tblsensor_pksensorid_seq'::regclass);


--
-- Name: pkstationid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblstation ALTER COLUMN pkstationid SET DEFAULT nextval('tblstation_pkstationid_seq'::regclass);


--
-- Data for Name: tblGroup; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "tblGroup" (pkgroupid, name, "isIgnored", "fkGroupTypeID") FROM stdin;
\.


--
-- Data for Name: tblGroupType; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "tblGroupType" ("pkGroupTypeID", name) FROM stdin;
1	Network Code
2	Groups
3	Countries
4	Regions
\.


--
-- Name: tblGroupType_pkGroupTypeID_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"tblGroupType_pkGroupTypeID_seq"', 1, false);


--
-- Data for Name: tblStationGroupTie; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "tblStationGroupTie" ("fkGroupID", "fkStationID") FROM stdin;
\.


--
-- Data for Name: tblcalibrationdata; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tblcalibrationdata (pkcalibrationdataid, fkchannelid, year, month, day, date, calyear, calmonth, calday, caldate, fkmetcaltypeid, value, fkmetricid) FROM stdin;
\.


--
-- Name: tblcalibrationdata_pkcalibrationdataid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tblcalibrationdata_pkcalibrationdataid_seq', 1, false);


--
-- Data for Name: tblchannel; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tblchannel (pkchannelid, fksensorid, name, derived, "isIgnored") FROM stdin;
\.


--
-- Name: tblchannel_pkchannelid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tblchannel_pkchannelid_seq', 1, true);


--
-- Data for Name: tblcomputetype; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tblcomputetype (pkcomputetypeid, name, description, iscalibration) FROM stdin;
1	AVG_CH	Values are averaged over channel and number o	f
2	AVG_DAY	Values are averaged over number of days.	f
3	VALUE_CO	Values are totalled over the window of time.	f
4	PARENT	Not used in computations.	f
5	CAL_DATE	Value is the difference between the Calibrati	t
6	CAL_AVG	Values are averaged over the number of values	t
7	NONE	Values are not computed	f
\.


--
-- Name: tblcomputetype_pkcomputetypeid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tblcomputetype_pkcomputetypeid_seq', 1, false);


--
-- Data for Name: tbldate; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tbldate (pkdateid, date) FROM stdin;
\.


--
-- Data for Name: tblerrorlog; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tblerrorlog (pkerrorlogid, errortime, errormessage) FROM stdin;
\.


--
-- Name: tblerrorlog_pkerrorlogid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tblerrorlog_pkerrorlogid_seq', 1, true);


--
-- Data for Name: tblhash; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tblhash ("pkHashID", hash) FROM stdin;
\.


--
-- Name: tblhash_pkHashID_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"tblhash_pkHashID_seq"', 1, true);


--
-- Data for Name: tblmetadata; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tblmetadata (fkchannelid, epoch, sensor_info, raw_metadata) FROM stdin;
\.


--
-- Data for Name: tblmetric; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tblmetric (pkmetricid, name, fkparentmetricid, legend, fkcomputetypeid, displayname) FROM stdin;
\.


--
-- Name: tblmetric_pkmetricid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tblmetric_pkmetricid_seq', 1, true);


--
-- Data for Name: tblmetricdata; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tblmetricdata (fkchannelid, date, fkmetricid, value, "fkHashID") FROM stdin;
\.


--
-- Data for Name: tblmetricstringdata; Type: TABLE DATA; Schema: public; Owner: jholland
--

COPY tblmetricstringdata (fkchannelid, date, fkmetricid, value, "fkHashID") FROM stdin;
\.


--
-- Name: tblnetwork_pknetworkid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tblnetwork_pknetworkid_seq', 1, true);


--
-- Data for Name: tblsensor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tblsensor (pksensorid, fkstationid, location) FROM stdin;
\.


--
-- Name: tblsensor_pksensorid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tblsensor_pksensorid_seq', 1, true);


--
-- Data for Name: tblstation; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tblstation (pkstationid, fknetworkid, name) FROM stdin;
\.


--
-- Name: tblstation_pkstationid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tblstation_pkstationid_seq', 1, true);


--
-- Name: Primary_tblstationGrouptie; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY "tblStationGroupTie"
    ADD CONSTRAINT "Primary_tblstationGrouptie" PRIMARY KEY ("fkGroupID", "fkStationID");


--
-- Name: pkTblHash; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblhash
    ADD CONSTRAINT "pkTblHash" PRIMARY KEY ("pkHashID");


--
-- Name: pk_metric_date_channel; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblmetricdata
    ADD CONSTRAINT pk_metric_date_channel PRIMARY KEY (fkmetricid, date, fkchannelid);


--
-- Name: pkstring_metric_date_channel; Type: CONSTRAINT; Schema: public; Owner: jholland; Tablespace: 
--

ALTER TABLE ONLY tblmetricstringdata
    ADD CONSTRAINT pkstring_metric_date_channel PRIMARY KEY (fkmetricid, date, fkchannelid);


--
-- Name: primary_tblGroupType; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY "tblGroupType"
    ADD CONSTRAINT "primary_tblGroupType" PRIMARY KEY ("pkGroupTypeID");


--
-- Name: tblcalibrationdata_fkchannelid_fkmetcaltypeid_calday_calmon_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblcalibrationdata
    ADD CONSTRAINT tblcalibrationdata_fkchannelid_fkmetcaltypeid_calday_calmon_key UNIQUE (fkchannelid, fkmetcaltypeid, calday, calmonth, calyear, day, month, year);


--
-- Name: tblcalibrationdata_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblcalibrationdata
    ADD CONSTRAINT tblcalibrationdata_pkey PRIMARY KEY (pkcalibrationdataid);


--
-- Name: tblchannel_fksensorid_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblchannel
    ADD CONSTRAINT tblchannel_fksensorid_name_key UNIQUE (fksensorid, name);


--
-- Name: tblchannel_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblchannel
    ADD CONSTRAINT tblchannel_pkey PRIMARY KEY (pkchannelid);


--
-- Name: tblcomputetype_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblcomputetype
    ADD CONSTRAINT tblcomputetype_name_key UNIQUE (name);


--
-- Name: tblcomputetype_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblcomputetype
    ADD CONSTRAINT tblcomputetype_pkey PRIMARY KEY (pkcomputetypeid);


--
-- Name: tbldate_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tbldate
    ADD CONSTRAINT tbldate_date_key UNIQUE (date);


--
-- Name: tbldate_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tbldate
    ADD CONSTRAINT tbldate_pkey PRIMARY KEY (pkdateid);


--
-- Name: tblerrorlog_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblerrorlog
    ADD CONSTRAINT tblerrorlog_pkey PRIMARY KEY (pkerrorlogid);


--
-- Name: tblmetadata_fkchannelid_epoch_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblmetadata
    ADD CONSTRAINT tblmetadata_fkchannelid_epoch_key UNIQUE (fkchannelid, epoch);


--
-- Name: tblmetric_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblmetric
    ADD CONSTRAINT tblmetric_pkey PRIMARY KEY (pkmetricid);


--
-- Name: tblnetwork_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY "tblGroup"
    ADD CONSTRAINT tblnetwork_pkey PRIMARY KEY (pkgroupid);


--
-- Name: tblsensor_fkstationid_location_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblsensor
    ADD CONSTRAINT tblsensor_fkstationid_location_key UNIQUE (fkstationid, location);


--
-- Name: tblsensor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblsensor
    ADD CONSTRAINT tblsensor_pkey PRIMARY KEY (pksensorid);


--
-- Name: tblstation_fknetworkid_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblstation
    ADD CONSTRAINT tblstation_fknetworkid_name_key UNIQUE (fknetworkid, name);


--
-- Name: tblstation_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblstation
    ADD CONSTRAINT tblstation_pkey PRIMARY KEY (pkstationid);


--
-- Name: un_name; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY "tblGroupType"
    ADD CONSTRAINT un_name UNIQUE (name);


--
-- Name: un_name_fkGroupType; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY "tblGroup"
    ADD CONSTRAINT "un_name_fkGroupType" UNIQUE (name, "fkGroupTypeID");


--
-- Name: un_tblHash_hash; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblhash
    ADD CONSTRAINT "un_tblHash_hash" UNIQUE (hash);


--
-- Name: un_tblMetric_name; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tblmetric
    ADD CONSTRAINT "un_tblMetric_name" UNIQUE (name);


--
-- Name: tblmetricdata_fkmetricid_date_fkchannelid_value_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tblmetricdata_fkmetricid_date_fkchannelid_value_idx ON tblmetricdata USING btree (fkmetricid, date DESC, fkchannelid, value);

ALTER TABLE tblmetricdata CLUSTER ON tblmetricdata_fkmetricid_date_fkchannelid_value_idx;


--
-- Name: tblmetricstringdata_fkmetricid_date_fkchannelid_value_idx; Type: INDEX; Schema: public; Owner: jholland; Tablespace: 
--

CREATE INDEX tblmetricstringdata_fkmetricid_date_fkchannelid_value_idx ON tblmetricstringdata USING btree (fkmetricid, date DESC, fkchannelid, value);


--
-- Name: fk_tblCalibrationData_tblChannel; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblcalibrationdata
    ADD CONSTRAINT "fk_tblCalibrationData_tblChannel" FOREIGN KEY (fkchannelid) REFERENCES tblchannel(pkchannelid);


--
-- Name: fk_tblCalibrationData_tblMetric; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblcalibrationdata
    ADD CONSTRAINT "fk_tblCalibrationData_tblMetric" FOREIGN KEY (fkmetricid) REFERENCES tblmetric(pkmetricid);


--
-- Name: fk_tblChannel; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblmetricdata
    ADD CONSTRAINT "fk_tblChannel" FOREIGN KEY (fkchannelid) REFERENCES tblchannel(pkchannelid) ON DELETE CASCADE;


--
-- Name: fk_tblComputeType; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblmetric
    ADD CONSTRAINT "fk_tblComputeType" FOREIGN KEY (fkcomputetypeid) REFERENCES tblcomputetype(pkcomputetypeid) ON DELETE CASCADE;


--
-- Name: fk_tblGroup; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "tblStationGroupTie"
    ADD CONSTRAINT "fk_tblGroup" FOREIGN KEY ("fkGroupID") REFERENCES "tblGroup"(pkgroupid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: fk_tblMetric; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblmetric
    ADD CONSTRAINT "fk_tblMetric" FOREIGN KEY (fkparentmetricid) REFERENCES tblmetric(pkmetricid) ON DELETE CASCADE;


--
-- Name: fk_tblMetric; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblmetricdata
    ADD CONSTRAINT "fk_tblMetric" FOREIGN KEY (fkmetricid) REFERENCES tblmetric(pkmetricid) ON DELETE CASCADE;


--
-- Name: fk_tblNetwork; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblstation
    ADD CONSTRAINT "fk_tblNetwork" FOREIGN KEY (fknetworkid) REFERENCES "tblGroup"(pkgroupid) ON DELETE CASCADE;


--
-- Name: fk_tblSensor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblchannel
    ADD CONSTRAINT "fk_tblSensor" FOREIGN KEY (fksensorid) REFERENCES tblsensor(pksensorid) ON DELETE CASCADE;


--
-- Name: fk_tblStation; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tblsensor
    ADD CONSTRAINT "fk_tblStation" FOREIGN KEY (fkstationid) REFERENCES tblstation(pkstationid) ON DELETE CASCADE;


--
-- Name: fk_tblStation; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "tblStationGroupTie"
    ADD CONSTRAINT "fk_tblStation" FOREIGN KEY ("fkStationID") REFERENCES tblstation(pkstationid) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_tblgrouptype; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "tblGroup"
    ADD CONSTRAINT fk_tblgrouptype FOREIGN KEY ("fkGroupTypeID") REFERENCES "tblGroupType"("pkGroupTypeID");


--
-- Name: fkstring_tblChannel; Type: FK CONSTRAINT; Schema: public; Owner: jholland
--

ALTER TABLE ONLY tblmetricstringdata
    ADD CONSTRAINT "fkstring_tblChannel" FOREIGN KEY (fkchannelid) REFERENCES tblchannel(pkchannelid) ON DELETE CASCADE;


--
-- Name: fkstring_tblMetric; Type: FK CONSTRAINT; Schema: public; Owner: jholland
--

ALTER TABLE ONLY tblmetricstringdata
    ADD CONSTRAINT "fkstring_tblMetric" FOREIGN KEY (fkmetricid) REFERENCES tblmetric(pkmetricid) ON DELETE CASCADE;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: fnsclgetchanneldata(integer[], integer, date, date); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION fnsclgetchanneldata(integer[], integer, date, date) FROM PUBLIC;
REVOKE ALL ON FUNCTION fnsclgetchanneldata(integer[], integer, date, date) FROM postgres;
GRANT ALL ON FUNCTION fnsclgetchanneldata(integer[], integer, date, date) TO postgres;
GRANT ALL ON FUNCTION fnsclgetchanneldata(integer[], integer, date, date) TO "dataqInsert";
GRANT ALL ON FUNCTION fnsclgetchanneldata(integer[], integer, date, date) TO PUBLIC;


--
-- Name: fnsclgetchannelplotdata(integer, integer, date, date); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION fnsclgetchannelplotdata(integer, integer, date, date) FROM PUBLIC;
REVOKE ALL ON FUNCTION fnsclgetchannelplotdata(integer, integer, date, date) FROM postgres;
GRANT ALL ON FUNCTION fnsclgetchannelplotdata(integer, integer, date, date) TO postgres;
GRANT ALL ON FUNCTION fnsclgetchannelplotdata(integer, integer, date, date) TO "dataqInsert";
GRANT ALL ON FUNCTION fnsclgetchannelplotdata(integer, integer, date, date) TO PUBLIC;


--
-- Name: fnsclgetchannels(integer[]); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION fnsclgetchannels(integer[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION fnsclgetchannels(integer[]) FROM postgres;
GRANT ALL ON FUNCTION fnsclgetchannels(integer[]) TO postgres;
GRANT ALL ON FUNCTION fnsclgetchannels(integer[]) TO "dataqInsert";
GRANT ALL ON FUNCTION fnsclgetchannels(integer[]) TO PUBLIC;


--
-- Name: fnsclgetdates(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION fnsclgetdates() FROM PUBLIC;
REVOKE ALL ON FUNCTION fnsclgetdates() FROM postgres;
GRANT ALL ON FUNCTION fnsclgetdates() TO postgres;
GRANT ALL ON FUNCTION fnsclgetdates() TO "dataqInsert";
GRANT ALL ON FUNCTION fnsclgetdates() TO PUBLIC;


--
-- Name: fnsclgetgroups(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION fnsclgetgroups() FROM PUBLIC;
REVOKE ALL ON FUNCTION fnsclgetgroups() FROM postgres;
GRANT ALL ON FUNCTION fnsclgetgroups() TO postgres;
GRANT ALL ON FUNCTION fnsclgetgroups() TO "dataqInsert";
GRANT ALL ON FUNCTION fnsclgetgroups() TO PUBLIC;


--
-- Name: fnsclgetgrouptypes(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION fnsclgetgrouptypes() FROM PUBLIC;
REVOKE ALL ON FUNCTION fnsclgetgrouptypes() FROM postgres;
GRANT ALL ON FUNCTION fnsclgetgrouptypes() TO postgres;
GRANT ALL ON FUNCTION fnsclgetgrouptypes() TO "dataqInsert";
GRANT ALL ON FUNCTION fnsclgetgrouptypes() TO PUBLIC;


--
-- Name: fnsclgetmetrics(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION fnsclgetmetrics() FROM PUBLIC;
REVOKE ALL ON FUNCTION fnsclgetmetrics() FROM postgres;
GRANT ALL ON FUNCTION fnsclgetmetrics() TO postgres;
GRANT ALL ON FUNCTION fnsclgetmetrics() TO "dataqInsert";
GRANT ALL ON FUNCTION fnsclgetmetrics() TO PUBLIC;


--
-- Name: fnsclgetpercentage(double precision, character varying); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION fnsclgetpercentage(double precision, character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION fnsclgetpercentage(double precision, character varying) FROM postgres;
GRANT ALL ON FUNCTION fnsclgetpercentage(double precision, character varying) TO postgres;
GRANT ALL ON FUNCTION fnsclgetpercentage(double precision, character varying) TO "dataqInsert";
GRANT ALL ON FUNCTION fnsclgetpercentage(double precision, character varying) TO PUBLIC;


--
-- Name: fnsclgetstationdata(integer[], integer, date, date); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION fnsclgetstationdata(integer[], integer, date, date) FROM PUBLIC;
REVOKE ALL ON FUNCTION fnsclgetstationdata(integer[], integer, date, date) FROM postgres;
GRANT ALL ON FUNCTION fnsclgetstationdata(integer[], integer, date, date) TO postgres;
GRANT ALL ON FUNCTION fnsclgetstationdata(integer[], integer, date, date) TO "dataqInsert";
GRANT ALL ON FUNCTION fnsclgetstationdata(integer[], integer, date, date) TO PUBLIC;


--
-- Name: fnsclgetstationplotdata(integer, integer, date, date); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION fnsclgetstationplotdata(integer, integer, date, date) FROM PUBLIC;
REVOKE ALL ON FUNCTION fnsclgetstationplotdata(integer, integer, date, date) FROM postgres;
GRANT ALL ON FUNCTION fnsclgetstationplotdata(integer, integer, date, date) TO postgres;
GRANT ALL ON FUNCTION fnsclgetstationplotdata(integer, integer, date, date) TO "dataqInsert";
GRANT ALL ON FUNCTION fnsclgetstationplotdata(integer, integer, date, date) TO PUBLIC;


--
-- Name: fnsclgetstations(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION fnsclgetstations() FROM PUBLIC;
REVOKE ALL ON FUNCTION fnsclgetstations() FROM postgres;
GRANT ALL ON FUNCTION fnsclgetstations() TO postgres;
GRANT ALL ON FUNCTION fnsclgetstations() TO "dataqInsert";
GRANT ALL ON FUNCTION fnsclgetstations() TO PUBLIC;


--
-- Name: spcomparehash(date, character varying, character varying, character varying, character varying, character varying, bytea); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION spcomparehash(date, character varying, character varying, character varying, character varying, character varying, bytea) FROM PUBLIC;
REVOKE ALL ON FUNCTION spcomparehash(date, character varying, character varying, character varying, character varying, character varying, bytea) FROM postgres;
GRANT ALL ON FUNCTION spcomparehash(date, character varying, character varying, character varying, character varying, character varying, bytea) TO postgres;
GRANT ALL ON FUNCTION spcomparehash(date, character varying, character varying, character varying, character varying, character varying, bytea) TO "dataqInsert";
GRANT ALL ON FUNCTION spcomparehash(date, character varying, character varying, character varying, character varying, character varying, bytea) TO PUBLIC;


--
-- Name: spgetmetricvalue(date, character varying, character varying, character varying, character varying, character varying); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION spgetmetricvalue(date, character varying, character varying, character varying, character varying, character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION spgetmetricvalue(date, character varying, character varying, character varying, character varying, character varying) FROM postgres;
GRANT ALL ON FUNCTION spgetmetricvalue(date, character varying, character varying, character varying, character varying, character varying) TO postgres;
GRANT ALL ON FUNCTION spgetmetricvalue(date, character varying, character varying, character varying, character varying, character varying) TO "dataqInsert";
GRANT ALL ON FUNCTION spgetmetricvalue(date, character varying, character varying, character varying, character varying, character varying) TO PUBLIC;


--
-- Name: spgetmetricvaluedigest(date, character varying, character varying, character varying, character varying, character varying); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION spgetmetricvaluedigest(date, character varying, character varying, character varying, character varying, character varying, OUT bytea) FROM PUBLIC;
REVOKE ALL ON FUNCTION spgetmetricvaluedigest(date, character varying, character varying, character varying, character varying, character varying, OUT bytea) FROM postgres;
GRANT ALL ON FUNCTION spgetmetricvaluedigest(date, character varying, character varying, character varying, character varying, character varying, OUT bytea) TO postgres;
GRANT ALL ON FUNCTION spgetmetricvaluedigest(date, character varying, character varying, character varying, character varying, character varying, OUT bytea) TO "dataqInsert";
GRANT ALL ON FUNCTION spgetmetricvaluedigest(date, character varying, character varying, character varying, character varying, character varying, OUT bytea) TO PUBLIC;


--
-- Name: spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, double precision, bytea); Type: ACL; Schema: public; Owner: jholland
--

REVOKE ALL ON FUNCTION spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, double precision, bytea) FROM PUBLIC;
REVOKE ALL ON FUNCTION spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, double precision, bytea) FROM jholland;
GRANT ALL ON FUNCTION spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, double precision, bytea) TO jholland;
GRANT ALL ON FUNCTION spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, double precision, bytea) TO "dataqInsert";
GRANT ALL ON FUNCTION spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, double precision, bytea) TO PUBLIC;


--
-- Name: spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea); Type: ACL; Schema: public; Owner: jholland
--

REVOKE ALL ON FUNCTION spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) FROM PUBLIC;
REVOKE ALL ON FUNCTION spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) FROM jholland;
GRANT ALL ON FUNCTION spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) TO jholland;
GRANT ALL ON FUNCTION spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) TO PUBLIC;
GRANT ALL ON FUNCTION spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) TO "dataqInsert";


--
-- Name: spinsertmetricstringdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea); Type: ACL; Schema: public; Owner: jholland
--

REVOKE ALL ON FUNCTION spinsertmetricstringdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) FROM PUBLIC;
REVOKE ALL ON FUNCTION spinsertmetricstringdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) FROM jholland;
GRANT ALL ON FUNCTION spinsertmetricstringdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) TO jholland;
GRANT ALL ON FUNCTION spinsertmetricstringdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) TO PUBLIC;
GRANT ALL ON FUNCTION spinsertmetricstringdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) TO "dataqInsert";


--
-- Name: tblGroup; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE "tblGroup" FROM PUBLIC;
REVOKE ALL ON TABLE "tblGroup" FROM postgres;
GRANT ALL ON TABLE "tblGroup" TO postgres;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE "tblGroup" TO PUBLIC;
GRANT ALL ON TABLE "tblGroup" TO "dataqInsert";


--
-- Name: tblGroupType; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE "tblGroupType" FROM PUBLIC;
REVOKE ALL ON TABLE "tblGroupType" FROM postgres;
GRANT ALL ON TABLE "tblGroupType" TO postgres;
GRANT ALL ON TABLE "tblGroupType" TO PUBLIC;
GRANT ALL ON TABLE "tblGroupType" TO "dataqInsert";


--
-- Name: tblGroupType_pkGroupTypeID_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON SEQUENCE "tblGroupType_pkGroupTypeID_seq" FROM PUBLIC;
REVOKE ALL ON SEQUENCE "tblGroupType_pkGroupTypeID_seq" FROM postgres;
GRANT ALL ON SEQUENCE "tblGroupType_pkGroupTypeID_seq" TO postgres;
GRANT ALL ON SEQUENCE "tblGroupType_pkGroupTypeID_seq" TO "dataqInsert";
GRANT SELECT ON SEQUENCE "tblGroupType_pkGroupTypeID_seq" TO PUBLIC;


--
-- Name: tblStationGroupTie; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE "tblStationGroupTie" FROM PUBLIC;
REVOKE ALL ON TABLE "tblStationGroupTie" FROM postgres;
GRANT ALL ON TABLE "tblStationGroupTie" TO postgres;
GRANT ALL ON TABLE "tblStationGroupTie" TO PUBLIC;
GRANT ALL ON TABLE "tblStationGroupTie" TO "dataqInsert";


--
-- Name: tblcalibrationdata; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE tblcalibrationdata FROM PUBLIC;
REVOKE ALL ON TABLE tblcalibrationdata FROM postgres;
GRANT ALL ON TABLE tblcalibrationdata TO postgres;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE tblcalibrationdata TO PUBLIC;
GRANT ALL ON TABLE tblcalibrationdata TO "dataqInsert";


--
-- Name: tblcalibrationdata_pkcalibrationdataid_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON SEQUENCE tblcalibrationdata_pkcalibrationdataid_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE tblcalibrationdata_pkcalibrationdataid_seq FROM postgres;
GRANT ALL ON SEQUENCE tblcalibrationdata_pkcalibrationdataid_seq TO postgres;
GRANT SELECT ON SEQUENCE tblcalibrationdata_pkcalibrationdataid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE tblcalibrationdata_pkcalibrationdataid_seq TO "dataqInsert";


--
-- Name: tblchannel; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE tblchannel FROM PUBLIC;
REVOKE ALL ON TABLE tblchannel FROM postgres;
GRANT ALL ON TABLE tblchannel TO postgres;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE tblchannel TO PUBLIC;
GRANT ALL ON TABLE tblchannel TO "dataqInsert";


--
-- Name: tblchannel_pkchannelid_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON SEQUENCE tblchannel_pkchannelid_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE tblchannel_pkchannelid_seq FROM postgres;
GRANT ALL ON SEQUENCE tblchannel_pkchannelid_seq TO postgres;
GRANT SELECT ON SEQUENCE tblchannel_pkchannelid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE tblchannel_pkchannelid_seq TO "dataqInsert";


--
-- Name: tblcomputetype; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE tblcomputetype FROM PUBLIC;
REVOKE ALL ON TABLE tblcomputetype FROM postgres;
GRANT ALL ON TABLE tblcomputetype TO postgres;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE tblcomputetype TO PUBLIC;
GRANT ALL ON TABLE tblcomputetype TO "dataqInsert";


--
-- Name: tblcomputetype_pkcomputetypeid_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON SEQUENCE tblcomputetype_pkcomputetypeid_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE tblcomputetype_pkcomputetypeid_seq FROM postgres;
GRANT ALL ON SEQUENCE tblcomputetype_pkcomputetypeid_seq TO postgres;
GRANT SELECT ON SEQUENCE tblcomputetype_pkcomputetypeid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE tblcomputetype_pkcomputetypeid_seq TO "dataqInsert";


--
-- Name: tbldate; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE tbldate FROM PUBLIC;
REVOKE ALL ON TABLE tbldate FROM postgres;
GRANT ALL ON TABLE tbldate TO postgres;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE tbldate TO PUBLIC;
GRANT ALL ON TABLE tbldate TO "dataqInsert";


--
-- Name: tblerrorlog; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE tblerrorlog FROM PUBLIC;
REVOKE ALL ON TABLE tblerrorlog FROM postgres;
GRANT ALL ON TABLE tblerrorlog TO postgres;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE tblerrorlog TO PUBLIC;
GRANT ALL ON TABLE tblerrorlog TO "dataqInsert";


--
-- Name: tblerrorlog_pkerrorlogid_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON SEQUENCE tblerrorlog_pkerrorlogid_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE tblerrorlog_pkerrorlogid_seq FROM postgres;
GRANT ALL ON SEQUENCE tblerrorlog_pkerrorlogid_seq TO postgres;
GRANT SELECT ON SEQUENCE tblerrorlog_pkerrorlogid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE tblerrorlog_pkerrorlogid_seq TO "dataqInsert";


--
-- Name: tblhash; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE tblhash FROM PUBLIC;
REVOKE ALL ON TABLE tblhash FROM postgres;
GRANT ALL ON TABLE tblhash TO postgres;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE tblhash TO PUBLIC;
GRANT ALL ON TABLE tblhash TO "dataqInsert";


--
-- Name: tblhash_pkHashID_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON SEQUENCE "tblhash_pkHashID_seq" FROM PUBLIC;
REVOKE ALL ON SEQUENCE "tblhash_pkHashID_seq" FROM postgres;
GRANT ALL ON SEQUENCE "tblhash_pkHashID_seq" TO postgres;
GRANT ALL ON SEQUENCE "tblhash_pkHashID_seq" TO "dataqInsert";
GRANT SELECT ON SEQUENCE "tblhash_pkHashID_seq" TO PUBLIC;


--
-- Name: tblmetadata; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE tblmetadata FROM PUBLIC;
REVOKE ALL ON TABLE tblmetadata FROM postgres;
GRANT ALL ON TABLE tblmetadata TO postgres;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE tblmetadata TO PUBLIC;
GRANT ALL ON TABLE tblmetadata TO "dataqInsert";


--
-- Name: tblmetric; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE tblmetric FROM PUBLIC;
REVOKE ALL ON TABLE tblmetric FROM postgres;
GRANT ALL ON TABLE tblmetric TO postgres;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE tblmetric TO PUBLIC;
GRANT ALL ON TABLE tblmetric TO "dataqInsert";


--
-- Name: tblmetric_pkmetricid_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON SEQUENCE tblmetric_pkmetricid_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE tblmetric_pkmetricid_seq FROM postgres;
GRANT ALL ON SEQUENCE tblmetric_pkmetricid_seq TO postgres;
GRANT SELECT ON SEQUENCE tblmetric_pkmetricid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE tblmetric_pkmetricid_seq TO "dataqInsert";


--
-- Name: tblmetricdata; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE tblmetricdata FROM PUBLIC;
REVOKE ALL ON TABLE tblmetricdata FROM postgres;
GRANT ALL ON TABLE tblmetricdata TO postgres;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE tblmetricdata TO PUBLIC;
GRANT ALL ON TABLE tblmetricdata TO "dataqInsert";


--
-- Name: tblmetricstringdata; Type: ACL; Schema: public; Owner: jholland
--

REVOKE ALL ON TABLE tblmetricstringdata FROM PUBLIC;
REVOKE ALL ON TABLE tblmetricstringdata FROM jholland;
GRANT ALL ON TABLE tblmetricstringdata TO jholland;
GRANT ALL ON TABLE tblmetricstringdata TO "dataqInsert";
GRANT SELECT,REFERENCES,TRIGGER ON TABLE tblmetricstringdata TO PUBLIC;


--
-- Name: tblnetwork_pknetworkid_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON SEQUENCE tblnetwork_pknetworkid_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE tblnetwork_pknetworkid_seq FROM postgres;
GRANT ALL ON SEQUENCE tblnetwork_pknetworkid_seq TO postgres;
GRANT SELECT ON SEQUENCE tblnetwork_pknetworkid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE tblnetwork_pknetworkid_seq TO "dataqInsert";


--
-- Name: tblsensor; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE tblsensor FROM PUBLIC;
REVOKE ALL ON TABLE tblsensor FROM postgres;
GRANT ALL ON TABLE tblsensor TO postgres;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE tblsensor TO PUBLIC;
GRANT ALL ON TABLE tblsensor TO "dataqInsert";


--
-- Name: tblsensor_pksensorid_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON SEQUENCE tblsensor_pksensorid_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE tblsensor_pksensorid_seq FROM postgres;
GRANT ALL ON SEQUENCE tblsensor_pksensorid_seq TO postgres;
GRANT SELECT ON SEQUENCE tblsensor_pksensorid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE tblsensor_pksensorid_seq TO "dataqInsert";


--
-- Name: tblstation; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE tblstation FROM PUBLIC;
REVOKE ALL ON TABLE tblstation FROM postgres;
GRANT ALL ON TABLE tblstation TO postgres;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE tblstation TO PUBLIC;
GRANT ALL ON TABLE tblstation TO "dataqInsert";


--
-- Name: tblstation_pkstationid_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON SEQUENCE tblstation_pkstationid_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE tblstation_pkstationid_seq FROM postgres;
GRANT ALL ON SEQUENCE tblstation_pkstationid_seq TO postgres;
GRANT SELECT ON SEQUENCE tblstation_pkstationid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE tblstation_pkstationid_seq TO "dataqInsert";


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: -; Owner: jholland
--

ALTER DEFAULT PRIVILEGES FOR ROLE jholland REVOKE ALL ON TABLES  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE jholland REVOKE ALL ON TABLES  FROM jholland;
ALTER DEFAULT PRIVILEGES FOR ROLE jholland GRANT ALL ON TABLES  TO jholland;
ALTER DEFAULT PRIVILEGES FOR ROLE jholland GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO "dataqInsert";


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: jholland
--

ALTER DEFAULT PRIVILEGES FOR ROLE jholland IN SCHEMA public REVOKE ALL ON TABLES  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE jholland IN SCHEMA public REVOKE ALL ON TABLES  FROM jholland;
ALTER DEFAULT PRIVILEGES FOR ROLE jholland IN SCHEMA public GRANT ALL ON TABLES  TO "dataqInsert";


--
-- PostgreSQL database dump complete
--

