REM  dbdrv:none
REM 
REM $Header: adgrants.sql 120.67.12020000.51 2017/02/22 21:26:05 jwsmith ship $
REM +-------------------------------------------------------------------------+
REM |
REM |  Copyright (c) 2005, 2017 Oracle and/or its affiliates.               
REM |                     All rights reserved.                              
REM |                      Version 12.0.0                                   
REM |
REM | NAME
REM |   adgrants.sql
REM |
REM | DESCRIPTION
REM |
REM |   SQL script to grant necessary privileges on selected SYS
REM |   objects  when the Init.ora parameter O7_DICTIONARY_ACCESSIBILITY
REM |   is set to FALSE.
REM |   Also this script calls profload.sql and proftab.sql which 
REM |   create PL/SQL profiler objects.
REM |
REM |   This script is for Unix only!
REM |
REM | USAGE
REM |
REM |   sqlplus /nolog @adgrants.sql <APPS Schema name>
REM |   
REM | NOTES
REM |
REM |   This SQL script must be run as SYS user, from the ORACLE_HOME 
REM |   on the Database Server.
REM |
REM | ARGUMENTS
REM |   You must pass the following argument.
REM |          APPS schema name. 
REM | CHANGE LOG:
REM |    2/16/2017 jwsmith Bug 25417122 - change grant privs on fnd_diag_dir
REM +-------------------------------------------------------------------------+
set verify off;

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
WHENEVER OSERROR  EXIT FAILURE ROLLBACK;

REM
REM this connect will generate an ORACLE error and cause the
REM script to exit if they don't have privileges to run as SYS
REM

connect / as sysdba

whenever sqlerror continue;

-- Fixed the block of code below as this failed on 12.2.3 during my testing for bug 25417122, jwsmith
REM workaround for RDBMS bug 25151974 (AD bug 24352502) 
declare 
  l_cdb_enabled varchar2(3); 
begin 
  $IF NOT DBMS_DB_VERSION.VER_LE_11_2 $THEN
    select cdb into l_cdb_enabled from v$database; 
    if (l_cdb_enabled='YES') then 
      execute immediate 'alter session set "_fix_control"=''13549808:off'''; 
    end if; 
  $END
  commit;
end;
/

select '--- adgrants.sql started at '||
  to_char(sysdate,'YYYY-MM-DD HH24:MI:SS')||' ---' " "
 from dual;


define appsUserName='&&1';

REM
REM Create PL/SQL profiler objects.
REM Bug: 3448207.CREATE PL/SQL PROFILER OBJECTS IN 11.5.10 RELEASE.
REM

prompt
prompt Creating PL/SQL profiler objects.
prompt


select '--- profload.sql started at '||
  to_char(sysdate,'YYYY-MM-DD HH24:MI:SS')||' ---' " "
 from dual;

@?/rdbms/admin/profload.sql

select '--- profload.sql completed at '||
  to_char(sysdate,'YYYY-MM-DD HH24:MI:SS')||' ---' " "
 from dual;

select '--- proftab.sql started at '||
  to_char(sysdate,'YYYY-MM-DD HH24:MI:SS')||' ---' " "
 from dual;

@?/rdbms/admin/proftab.sql

select '--- profltab.sql completed at '||
  to_char(sysdate,'YYYY-MM-DD HH24:MI:SS')||' ---' " "
 from dual;

REM
REM End of Creating PL/SQL profiler objects.
REM

REM
REM Installing Hierarchical Profiler.
REM Bug 12751455
REM

prompt
prompt Installing Hierarchical Profiler.
prompt

WHENEVER OSERROR continue none;

@?/rdbms/admin/dbmshptab.sql
@?/rdbms/admin/dbmshpro.sql

grant select on dbmshp_runs to &appsUserName;
grant select on dbmshp_function_info to &appsUserName;
grant select on dbmshp_parent_child_info to &appsUserName;
grant execute on DBMS_HPROF to &appsUserName;

WHENEVER OSERROR  EXIT FAILURE ROLLBACK;

REM
REM End of Installing Hierarchical Profiler.
REM

REM Bug 14376891, MKUMANDU, 27-Jul-2012
REM Start of Loading Stylesheets if missing
REM

prompt
prompt Loading Stylesheets if missing
prompt

begin
  if (dbms_metadata_util.are_stylesheets_loaded = false) then
     dbms_metadata_util.load_stylesheets;
  end if;
end;
/

REM
REM End of Loading Stylesheets if missing
REM

prompt
prompt Start of Creating AD_JAR context
prompt

begin
  execute immediate('create or replace context AD_JAR using &appsUserName..AD_JAR');
end;
/

begin
 execute immediate('create or replace context AD_ZD_CTX using &appsUserName..AD_ZD_CTX');
end;
/


prompt
prompt End of Creating AD_JAR context
prompt

prompt
prompt Creating PL/SQL Package AD_DBMS_METADATA.
prompt

Rem    NAME
Rem     Package header for wrapper to DBMS_METADATA.
Rem     
Rem    DESCRIPTION
Rem     This file contains the public interface for the wrapper to Metadata API.
Rem
Rem    PUBLIC FUNCTIONS / PROCEDURES
Rem       (the retrieval interface)
Rem     OPEN            - Establish object parameters
Rem     SET_FILTER      - Specify filters.
Rem     SET_COUNT       - Specify object count.
Rem     GET_QUERY       - Get text of query (for debugging).
Rem     SET_PARSE_ITEM  - Enable output parsing
Rem                       and specify an attribute to be parsed
Rem     ADD_TRANSFORM   - Specify transform.
Rem     SET_TRANSFORM_PARAM - Specify parameter to XSL stylesheet.
Rem     FETCH_XML       - Fetch selected DB objects as XML docs.
Rem     FETCH_DDL       - Fetch selected DB objects as DDL.
Rem                     ***** TEMPORARY API FOR LOGICAL STANDBY *****
Rem     FETCH_DDL_TEXT  - Fetch selected DB objects as DDL in a VARCHAR2
Rem                     ***** TEMPORARY API FOR LOGICAL STANDBY *****
Rem     FETCH_CLOB      - Fetch selected DB objects as CLOBs.
Rem     PROCEDURE FETCH_XML_CLOB - Same as above, but with IN/OUT NOCOPY
Rem                             for perf.
Rem     CLOSE           - Cleanup fetch context established by OPEN.
Rem       (the browsing interface)
Rem     GET_XML         - Simple 1-step method for retrieving a single
Rem                       named object as an XML doc.
Rem     GET_DDL         - Simple 1-step method for retrieving DDL for a single
Rem                       named object.
Rem     GET_DEPENDENT_XML- Simple 1-step method for retrieving objects
Rem                       dependent on a base object as an XML doc.
Rem     GET_DEPENDENT_DDL- Simple 1-step method for retrieving DDL for
Rem                       objects dependent on a base object.
Rem     bhthiaga          11/16/05 -  Creation
Rem



-- Types used by the mdAPI interface:
-------------------------------------
-- SET_PARSE_ITEM specifies that an attribute of an object be parsed from
-- the output and returned separately by FETCH_XML, FETCH_DDL or CONVERT.
-- Since multiple items can be parsed, they are returned in a nested table,
-- ku$_parsed_items.

-- Since public synonym already exists for the types used by MD API the wrapper
-- code can just reuse it with a sys prefix.


CREATE OR REPLACE PACKAGE ad_dbms_metadata AS
/* $Header: adgrants.sql 120.67.12020000.51 2017/02/22 21:26:05 jwsmith ship $ */
---------------------------
-- PROCEDURES AND FUNCTIONS
--
-- OPEN: Specifies the type of object whose metadata is to be retrieved.
-- PARAMETERS:
--      object_type     - Identifies the type of objects to be retrieved; i.e.,
--              TABLE, INDEX, etc. This determines which view is selected.
--      version         - The version of the objects' metadata to be fetched.
--              To be used in downgrade scenarios: Objects in the DB that are
--              incompatible with an older specified version are not returned.
--              Values can be 'COMPATIBLE' (default), 'LATEST' or a specific
--              version number.
--      model           - The view of the metadata, such as Oracle proprietary,
--              ANSI99, etc.  Currently only 'ORACLE' is supported.
--      network_link    - The name of a database link to the database
--              whose data is to be retrieved.  If NULL (default), metadata
--              is retrieved from the database on which the caller is running.
-- 
-- RETURNS:
--      A handle to be used in subsequent calls to SET_FILTER, SET_COUNT,
--      ADD_TRANSFORM, GET_QUERY, SET_PARSE_ITEM, FETCH_xxx and CLOSE.
-- EXCEPTIONS:
--      INVALID_ARGVAL  - a NULL or invalid value was supplied for an input
--              parameter.

  FUNCTION open (
                object_type     IN  VARCHAR2,
                version         IN  VARCHAR2 DEFAULT 'COMPATIBLE',
                model           IN  VARCHAR2 DEFAULT 'ORACLE')
        RETURN NUMBER;

-- SET_FILTER: Specifies restrictions on the objects whose metadata
--      is to be retrieved.
--      This function is overloaded: the filter value can be a varchar2,
--      number or boolean.
-- PARAMETERS:
--      handle          - Context handle from previous OPEN call.
--      name            - Name of the filter.
--      value           - Value of the filter.
--      object_type_path- Path name of object types to which
--                        the filter applies.

  PROCEDURE set_filter (
                handle                  IN  NUMBER,
                name                    IN  VARCHAR2,
                value                   IN  VARCHAR2);

  PROCEDURE set_filter (
                handle                  IN  NUMBER,
                name                    IN  VARCHAR2,
                value                   IN  BOOLEAN DEFAULT TRUE);



-- SET_COUNT: Specifies the number of objects to be returned in a single
--      FETCH_xxx call.
-- PARAMETERS:
--      handle          - Context handle from previous OPEN call.
--      value           - Number of objects to retrieve.

  PROCEDURE set_count ( 
                handle                  IN  NUMBER,
                value                   IN  NUMBER);


-- GET_QUERY:   Return the text of the query (or queries) that will be
--              used by FETCH_xxx.  This function is provided to aid
--              in debugging.
-- PARAMETERS:  handle  - Context handle from previous OPEN call.
-- RETURNS:     Text of the query.

  FUNCTION get_query (
                handle          IN  NUMBER)
        RETURN VARCHAR2;


-- SET_PARSE_ITEM: Enables output parsing and specifies an object attribute
--      to be parsed and returned 
-- PARAMETERS:
--      handle  - Context handle from previous OPEN call.
--      name    - Attribute name.
--      object_type- Object type to which the transform applies.

  PROCEDURE set_parse_item (
                handle          IN  NUMBER,
                name            IN  VARCHAR2);

-- ADD_TRANSFORM : Specify a transform to be applied to the XML representation
--              of objects processed by FETCH_xxx, CONVERT or PUT.
-- PARAMETERS:  handle  - Context handle from previous OPEN or OPENW call.
--              name    - The name of the transform: Can be 'DDL' to generate
--                        creation DDL or a URI pointing to a stylesheet,
--                        either external or internal to the DB (the latter
--                        being an Xpath spec. starting with '/oradb').
--              encoding- If name is a URI, this specifies the encoding of the
--                        target stylesheet. If left NULL, then if uri starts
--                        with  '/oradb', then the database char. set is used;
--                        otherwise, 'UTF-8'. Use 'US-ASCII' for better perf.
--                        if you can. May be any valid NLS char. set name.
--                        Ignored if name is an internal transform name (like
--                        DDL), not a URI.
--              object_type- Object type to which the transform applies.
-- 
-- NOTE: If name is an intra-DB uri (ie, /oradb) that points to an NCLOB
--       column or a CLOB with an encoding different from the database charset,
--       you must explicitly specify the encoding.
-- RETURNS:     An opaque handle to the transform to be used in subsequent
--              calls to SET_TRANSFORM_PARAM.

  FUNCTION add_transform (
                handle          IN NUMBER,
                name            IN VARCHAR2,
                encoding        IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER; 


-- SET_TRANSFORM_PARAM: Specifies a value for a parameter to the XSL-T
--      stylesheet identified by handle.
--      This procedure is overloaded: the parameter value can be a varchar2,
--      a number or a boolean.
-- PARAMETERS:
--      transform_handle - Handle from previous ADD_TRANSFORM call.
--      name             - Name of the parameter.
--      value            - Value for the parameter.
--      object_type      - Object type to which the transform param applies.

  PROCEDURE set_transform_param (
                transform_handle        IN  NUMBER,
                name                    IN  VARCHAR2,
                value                   IN  VARCHAR2);


  PROCEDURE set_transform_param ( 
                transform_handle        IN  NUMBER,
                name                    IN  VARCHAR2,
                value                   IN  BOOLEAN DEFAULT TRUE);
  
-- SET_REMAP_PARAM: Specifies a value for a parameter to the XSL-T
--      stylesheet identified by handle.
-- PARAMETERS:
--      transform_handle - Handle from previous ADD_TRANSFORM call.
--      name             - Name of the parameter.
--      old_value        - Old value for the remapping
--      new_value        - New value for the remapping
--      object_type      - Object type to which the transform param applies.

  PROCEDURE set_remap_param (
                transform_handle        IN  NUMBER,
                name                    IN  VARCHAR2,
                old_value               IN  VARCHAR2, 
                new_value               IN  VARCHAR2);

-- FETCH_XML:   Return metadata for objects as XML documents. This version
--              can return multiple objects per call (when the SET_COUNT
--              'value' parameter > 1).
-- PARAMETERS:  handle  - Context handle from previous OPEN call.
-- RETURNS:     XML metadata for the objects as an XMLType, or NULL if all
--              objects have been fetched.
-- EXCEPTIONS:  Throws an exception if DDL transform has been added

  FUNCTION fetch_xml (handle    IN NUMBER)
        RETURN sys.XMLType;


-- FETCH_DDL:   Return metadata as DDL.
--              More than one DDL statement may be returned.
-- RETURNS:     Metadata for the objects as one or more DDL statements
-- PARAMETERS:  handle  - Context handle from previous OPEN call.

  FUNCTION fetch_ddl (
                handle  IN NUMBER) 
        RETURN sys.ku$_ddls;


-- FETCH_CLOB:  Return metadata for object (transformed or not) as a CLOB.
-- PARAMETERS:  handle  - Context handle from previous OPEN call.
--              cache_lob - TRUE = read LOB into buffer cache
--              lob_duration - either DBMS_LOB.SESSION (default)
--                or DBMS_LOB.CALL, the duration for the termporary lob
-- RETURNS:     XML metadata for the objects as a CLOB, or NULL if all
--              objects have been fetched.

  FUNCTION fetch_clob (handle       IN NUMBER)
        RETURN CLOB;


-- PROCEDURE FETCH_CLOB: Same as above but with IN/OUT NOCOPY CLOB. CLOB
--              must be pre-created prior to call.

  PROCEDURE fetch_clob (
                handle  IN NUMBER,
                xmldoc  IN OUT NOCOPY CLOB);


  PROCEDURE CLOSE (handle IN NUMBER);


-- GET_XML:     Return the metadata for a single object as XML.
--      This interface is meant for casual browsing (e.g., from SQLPlus)
--      vs. the programmatic OPEN / FETCH / CLOSE interfaces above.
-- PARAMETERS:
--      object_type     - The type of object to be retrieved.
--      name            - Name of the object.
--      schema          - Schema containing the object.  Defaults to
--                        the caller's schema.
--      version         - The version of the objects' metadata.
--      model           - The object model for the metadata.
--      transform       - XSL-T transform to be applied.
-- RETURNS:     Metadata for the object as an NCLOB.

  FUNCTION get_xml (
                object_type     IN  VARCHAR2,
                name            IN  VARCHAR2,
                schema          IN  VARCHAR2 DEFAULT NULL,
                version         IN  VARCHAR2 DEFAULT 'COMPATIBLE',
                model           IN  VARCHAR2 DEFAULT 'ORACLE',
                transform       IN  VARCHAR2 DEFAULT NULL)
        RETURN CLOB;


-- GET_DDL:     Return the metadata for a single object as DDL.
--      This interface is meant for casual browsing (e.g., from SQLPlus)
--      vs. the programmatic OPEN / FETCH / CLOSE interfaces above.
-- PARAMETERS:
--      object_type     - The type of object to be retrieved.
--      name            - Name of the object.
--      schema          - Schema containing the object.  Defaults to
--                        the caller's schema.
--      version         - The version of the objects' metadata.
--      model           - The object model for the metadata.
--      transform       - XSL-T transform to be applied.
-- RETURNS:     Metadata for the object transformed to DDL as a CLOB.

  FUNCTION get_ddl (    
                object_type     IN  VARCHAR2,
                name            IN  VARCHAR2,
                schema          IN  VARCHAR2 DEFAULT NULL,
                version         IN  VARCHAR2 DEFAULT 'COMPATIBLE',
                model           IN  VARCHAR2 DEFAULT 'ORACLE',
                transform       IN  VARCHAR2 DEFAULT 'DDL')
        RETURN CLOB;

-- GET_DEPENDENT_XML:   Return the metadata for objects dependent on a
--      base object as XML.
--      This interface is meant for casual browsing (e.g., from SQLPlus)
--      vs. the programmatic OPEN / FETCH / CLOSE interfaces above.
-- PARAMETERS:
--      object_type     - The type of object to be retrieved.
--      base_object_name- Name of the base object.
--      base_object_schema- Schema containing the base object.  Defaults to
--                        the caller's schema.
--      version         - The version of the objects' metadata.
--      model           - The object model for the metadata.
--      transform       - XSL-T transform to be applied.
--      object_count    - maximum number of objects to return
-- RETURNS:     Metadata for the object as a CLOB.

  FUNCTION get_dependent_xml (
                object_type             IN  VARCHAR2,
                base_object_name        IN  VARCHAR2,
                base_object_schema      IN  VARCHAR2 DEFAULT NULL,
                version                 IN  VARCHAR2 DEFAULT 'COMPATIBLE',
                model                   IN  VARCHAR2 DEFAULT 'ORACLE',
                transform               IN  VARCHAR2 DEFAULT NULL,
                object_count            IN  NUMBER   DEFAULT 10000)
        RETURN CLOB;

-- GET_DEPENDENT_DDL:   Return the metadata for objects dependent on a
--      base object as DDL.
--      vs. the programmatic OPEN / FETCH / CLOSE interfaces above.
-- PARAMETERS:
--      object_type     - The type of object to be retrieved.
--      base_object_name- Name of the base object.
--      base_object_schema- Schema containing the base object.  Defaults to
--                        the caller's schema.
--      version         - The version of the objects' metadata.
--      model           - The object model for the metadata.
--      transform       - XSL-T transform to be applied.
--      object_count    - maximum number of objects to return
-- RETURNS:     Metadata for the object as a CLOB.

  FUNCTION get_dependent_ddl (
                object_type             IN  VARCHAR2,
                base_object_name        IN  VARCHAR2,
                base_object_schema      IN  VARCHAR2 DEFAULT NULL,
                version                 IN  VARCHAR2 DEFAULT 'COMPATIBLE',
                 model                   IN  VARCHAR2 DEFAULT 'ORACLE',
                transform               IN  VARCHAR2 DEFAULT 'DDL',
                object_count            IN  NUMBER   DEFAULT 10000)
        RETURN CLOB;


END AD_DBMS_METADATA;
/

Rem    NAME
Rem     Package body for DBMS_METADATA.
Rem     
Rem    DESCRIPTION
Rem     This file contains the PL/SQL implementation of the wrapper 
REm     to DataPump's Metadata API.
Rem
Rem    PUBLIC FUNCTIONS / PROCEDURES
Rem       (the retrieval interface)
Rem     OPEN            - Establish object parameters
Rem     SET_FILTER      - Specify filters.
Rem     SET_COUNT       - Specify object count.
Rem     GET_QUERY       - Get text of query (for debugging).
Rem     SET_PARSE_ITEM  - Enable output parsing
Rem                       and specify an attribute to be parsed
Rem     ADD_TRANSFORM   - Specify transform.
Rem     SET_TRANSFORM_PARAM - Specify parameter to XSL stylesheet.
Rem     FETCH_XML       - Fetch selected DB objects as XML docs.
Rem     FETCH_DDL       - Fetch selected DB objects as DDL.
Rem                     ***** TEMPORARY API FOR LOGICAL STANDBY *****
Rem     FETCH_DDL_TEXT  - Fetch selected DB objects as DDL in a VARCHAR2
Rem                     ***** TEMPORARY API FOR LOGICAL STANDBY *****
Rem     FETCH_CLOB      - Fetch selected DB objects as CLOBs.
Rem     CLOSE           - Cleanup fetch context established by OPEN.
Rem       (the browsing interface)
Rem     GET_XML         - Simple 1-step method for retrieving a single
Rem                       named object as an XML doc.
Rem     GET_DDL         - Simple 1-step method for retrieving DDL for a single
Rem                       named object.
Rem     GET_DEPENDENT_XML- Simple 1-step method for retrieving objects
Rem                       dependent on a base object as an XML doc.
Rem     GET_DEPENDENT_DDL- Simple 1-step method for retrieving DDL for
Rem                       objects dependent on a base object.
Rem     bhthiaga          11/16/05 -  Creation
Rem



CREATE OR REPLACE PACKAGE BODY ad_dbms_metadata AS
/* $Header: adgrants.sql 120.67.12020000.51 2017/02/22 21:26:05 jwsmith ship $ */
-- OPEN: Specifies the type of object whose metadata is to be retrieved.

FUNCTION open (
		object_type	IN  VARCHAR2,
		version		IN  VARCHAR2 DEFAULT 'COMPATIBLE',
		model		IN  VARCHAR2 DEFAULT 'ORACLE')
	RETURN NUMBER IS
BEGIN
  -- call the call dbms_metadata function
  RETURN dbms_metadata.open(object_type, version, model);
END;



---------------------------------------------------------------------
-- SET_FILTER: Specifies restrictions on the objects whose metadata 
--	is to be retrieved.
--	This function is overloaded: the filter value can be a varchar2,
--	number or boolean.  This is the varchar2 variant.
-- PARAMETERS:
-- 	handle		- Context handle from previous OPEN call.
--	name		- Name of the filter.
--	value		- Value of the filter.

  PROCEDURE set_filter (
		handle			IN  NUMBER,
		name			IN  VARCHAR2,
		value			IN  VARCHAR2) IS
BEGIN

   dbms_metadata.set_filter(handle,name,value);       

END;


---------------------------------------------------------------------
-- SET_FILTER: Specifies restrictions on the objects whose metadata 
--	is to be retrieved.
--	This function is overloaded: the filter value can be a varchar2,
--	number or boolean.  This is the number variant.
-- PARAMETERS:
-- 	handle		- Context handle from previous OPEN call.
--	name		- Name of the filter.
--	value		- Value of the filter.
--	object_type_path- Path name of object types to which
--			  the filter applies.

  PROCEDURE set_filter (
		handle			IN  NUMBER,
		name			IN  VARCHAR2,
		value			IN  BOOLEAN DEFAULT TRUE) IS
  BEGIN
       dbms_metadata.set_filter(handle,name,value);
  END;



---------------------------------------------------------------------
-- SET_COUNT: Specifies the number of objects to be returned in a single
--	FETCH_xxx call.
-- PARAMETERS:
-- 	handle		- Context handle from previous OPEN call.
--	value		- Number of objects to retrieve.
--	object_type_path- Path name of object types to which
--			  the count applies.

  PROCEDURE set_count (
		handle			IN  NUMBER,
		value			IN  NUMBER ) IS
BEGIN
   dbms_metadata.set_count(handle,value);
END;



---------------------------------------------------------------------
-- GET_QUERY:	Return the text of the query (or queries) that will be
-- 		used by FETCH_xxx.  Ths function is provided to aid
-- 		in debugging.
-- PARAMETERS:	handle	- Context handle from previous OPEN call.
-- RETURNS:	Text of the query.

  FUNCTION get_query (
		handle		IN  NUMBER)
	RETURN VARCHAR2 IS
BEGIN
    RETURN dbms_metadata.get_query(handle);
END;


---------------------------------------------------------------------
-- SET_PARSE_ITEM: Enables output parsing and specifies an object attribute
--	to be parsed and returned
-- PARAMETERS:
-- 	handle	- Context handle from previous OPEN call.
--	name	- Attribute name.
--	object_type- Object type to which the transform applies.

  PROCEDURE set_parse_item (
		handle		IN  NUMBER,
		name		IN  VARCHAR2) IS
BEGIN
    dbms_metadata.set_parse_item(handle,name);
END;


---------------------------------------------------------------------
-- ADD_TRANSFORM : Specify a transform to be applied to the XML representation
-- 		of objects returned by FETCH_xxx.
-- PARAMETERS:	handle	- Context handle from previous OPEN call.
--		name	- The name of the transform: Internal name like 'DDL'
--                        or a URI pointing to a stylesheet
--              encoding- If name is a URI, specifies encoding of the target
--                        stylesheet.
-- RETURNS:	An opaque handle to the transform to be used in subsequent
--		calls to SET_TRANSFORM_PARAM.

  FUNCTION add_transform (
		handle		IN NUMBER,
		name		IN VARCHAR2,
		encoding        IN VARCHAR2 DEFAULT NULL)
	RETURN NUMBER IS
BEGIN
    return dbms_metadata.add_transform(handle,name,encoding);
END;


---------------------------------------------------------------------
-- SET_TRANSFORM_PARAM: Specifies a value for a parameter to the XSL-T
--	stylesheet identified by handle.
--	This procedure is overloaded: the parameter value can be varchar2,
--	boolean or numeric.
-- PARAMETERS:
-- 	transform_handle - Handle from previous ADD_TRANSFORM call.
--	name		 - Name of the parameter.
--	value		 - Boolean value for the parameter.
--	object_type	 - Object type to which the transform param applies.

  PROCEDURE set_transform_param (
		transform_handle	IN  NUMBER,
		name			IN  VARCHAR2,
		value			IN  VARCHAR2) IS
BEGIN
      dbms_metadata.set_transform_param(transform_handle,name,value);
END;



---------------------------------------------------------------------
-- SET_TRANSFORM_PARAM: Specifies a value for a parameter to the XSL-T
--	stylesheet identified by handle.
--	This procedure is overloaded: the parameter value can be varchar2,
--	boolean or numeric.
-- PARAMETERS:
-- 	transform_handle - Handle from previous ADD_TRANSFORM call.
--	name		 - Name of the parameter.
--	value		 - Boolean value for the parameter.
--	object_type	 - Object type to which the transform param applies.

  PROCEDURE set_transform_param (
		transform_handle	IN  NUMBER,
		name			IN  VARCHAR2,
		value			IN  BOOLEAN DEFAULT TRUE) IS
BEGIN
      dbms_metadata.set_transform_param(transform_handle,name,value);
END;




---------------------------------------------------------------------
-- SET_REMAP_PARAM: Specifies a value for a parameter to the XSL-T
--	stylesheet identified by handle.
-- PARAMETERS:
-- 	transform_handle - Handle from previous ADD_TRANSFORM call.
--	name		 - Name of the parameter.
--	old_value	 - Old value for the remapping
--	new_value	 - New value for the remapping
--	object_type	 - Object type to which the transform param applies.

  PROCEDURE set_remap_param (
		transform_handle	IN  NUMBER,
		name			IN  VARCHAR2,
		old_value		IN  VARCHAR2,
		new_value		IN  VARCHAR2) IS
BEGIN
     NULL;
--   dbms_metadata.set_remap_param(transform_handle,name,old_value,new_value);
 
END;



---------------------------------------------------------------------
-- FETCH_XML:	Return metadata for objects as XML documents. This version
--		can return multiple objects per call (when the SET_COUNT
--		'value' parameter > 1).
-- PARAMETERS:	handle	- Context handle from previous OPEN call.
-- RETURNS:	XML metadata for the objects as an XMLType, or NULL if all
--		objects have been fetched.
-- EXCEPTIONS:	Throws an exception if DDL transform has been added

  FUNCTION fetch_xml (handle	IN NUMBER)
	RETURN sys.XMLType IS
BEGIN

   return dbms_metadata.fetch_xml(handle);
END;



---------------------------------------------------------------------
-- FETCH_DDL:	Return metadata for one object as DDL.
--		More than one DDL statement may be returned.
-- PARAMETERS:	handle	- Context handle from previous OPEN call.
-- RETURNS:	Metadata for the object as one or more DDL statements
-- IMPLICIT PARAMETER: FETCH_DDL$_out - converted output
-- EXCEPTIONS:	Throws an exception if DDL transform was not added.

  FUNCTION fetch_ddl (
		handle	IN NUMBER)
	RETURN sys.ku$_ddls IS
BEGIN

      return dbms_metadata.fetch_ddl(handle);
END;



---------------------------------------------------------------------
-- FETCH_CLOB:	Return metadata for object (transformed or not) as a CLOB.
-- PARAMETERS:	handle	- Context handle from previous OPEN call.
-- RETURNS:	XML metadata for the objects as a CLOB, or NULL if all
--		objects have been fetched.

  FUNCTION fetch_clob (handle	IN NUMBER)
	RETURN CLOB IS
BEGIN
  RETURN dbms_metadata.fetch_clob(handle);
END;


---------------------------------------------------------------------
-- PROCEDURE FETCH_CLOB: Same as above but with IN/OUT NOCOPY CLOB. CLOB
--		must be pre-created prior to call.

  PROCEDURE fetch_clob (
		handle	IN NUMBER,
		xmldoc	IN OUT NOCOPY CLOB) IS
BEGIN
        dbms_metadata.fetch_clob(handle,xmldoc);
END;


---------------------------------------------------------------------
-- CLOSE:	Cleanup all context associated with handle.
-- PARAMETERS:	handle	- Context handle from previous OPEN call.

  PROCEDURE CLOSE (handle IN NUMBER) IS
BEGIN
      dbms_metadata.close(handle);
END;

---------------------------------------------------------------------
-- GET_XML:	Return the metadata for a single object as XML.
--	This interface is meant for casual browsing (e.g., from SQLPlus)
--	vs. the programmatic OPEN / FETCH / CLOSE interfaces above.
-- PARAMETERS:
--	object_type	- The type of object to be retrieved.
--	name		- Name of the object.
--	schema		- Schema containing the object.  Defaults to
--			  the caller's schema.
--	version		- The version of the objects' metadata.
--	model		- The object model for the metadata.
--	transform	- XSL-T transform to be applied.
-- RETURNS:	Metadata for the object as an NCLOB.

  FUNCTION get_xml (
		object_type	IN  VARCHAR2,
		name		IN  VARCHAR2,
		schema		IN  VARCHAR2 DEFAULT NULL,
		version		IN  VARCHAR2 DEFAULT 'COMPATIBLE',
		model		IN  VARCHAR2 DEFAULT 'ORACLE',
		transform	IN  VARCHAR2 DEFAULT NULL)
	RETURN CLOB IS
BEGIN
  RETURN dbms_metadata.get_xml(object_type,name,schema,version,model,transform);
END;

---------------------------------------------------------------------
-- GET_DDL:	Return the metadata for a single object as DDL.
--	This interface is meant for casual browsing (e.g., from SQLPlus)
--	vs. the programmatic OPEN / FETCH / CLOSE interfaces above.
-- PARAMETERS:
--	object_type	- The type of object to be retrieved.
--	name		- Name of the object.
--	schema		- Schema containing the object.  Defaults to
--			  the caller's schema.
--	version		- The version of the objects' metadata.
--	model		- The object model for the metadata.
--	transform	- XSL-T transform to be applied.
-- RETURNS:	Metadata for the object transformed to DDL as a CLOB.

  FUNCTION get_ddl (
		object_type	IN  VARCHAR2,
		name		IN  VARCHAR2,
		schema		IN  VARCHAR2 DEFAULT NULL,
		version		IN  VARCHAR2 DEFAULT 'COMPATIBLE',
		model		IN  VARCHAR2 DEFAULT 'ORACLE',
		transform	IN  VARCHAR2 DEFAULT 'DDL')
	RETURN CLOB IS
BEGIN
  RETURN dbms_metadata.get_ddl(object_type,name,schema,version,model,transform);
END;

---------------------------------------------------------------------
-- GET_DEPENDENT_XML:	Return the metadata for objects dependent on a
--	base object as XML.
--	This interface is meant for casual browsing (e.g., from SQLPlus)
--	vs. the programmatic OPEN / FETCH / CLOSE interfaces above.
-- PARAMETERS:
--	object_type	- The type of object to be retrieved.
--	base_object_name- Name of the base object.
--	base_object_schema- Schema containing the base object.  Defaults to
--			  the caller's schema.
--	version		- The version of the objects' metadata.
--	model		- The object model for the metadata.
--	transform	- XSL-T transform to be applied.
--	object_count	- maximum number of objects to return
-- RETURNS:	Metadata for the object as a CLOB.

  FUNCTION get_dependent_xml (
		object_type		IN  VARCHAR2,
		base_object_name	IN  VARCHAR2,
		base_object_schema	IN  VARCHAR2 DEFAULT NULL,
		version			IN  VARCHAR2 DEFAULT 'COMPATIBLE',
		model			IN  VARCHAR2 DEFAULT 'ORACLE',
		transform		IN  VARCHAR2 DEFAULT NULL,
		object_count		IN  NUMBER   DEFAULT 10000)
	RETURN CLOB IS
BEGIN
  RETURN  dbms_metadata.get_dependent_xml( object_type,
                                           base_object_name,base_object_schema,
                                           version,model,transform,
                                           object_count);
END;

---------------------------------------------------------------------
-- GET_DEPENDENT_DDL:	Return the metadata for objects dependent on a
--	base object as DDL.
--	This interface is meant for casual browsing (e.g., from SQLPlus)
--	vs. the programmatic OPEN / FETCH / CLOSE interfaces above.
-- PARAMETERS:
--	object_type	- The type of object to be retrieved.
--	base_object_name- Name of the base object.
--	base_object_schema- Schema containing the base object.  Defaults to
--			  the caller's schema.
--	version		- The version of the objects' metadata.
--	model		- The object model for the metadata.
--	transform	- XSL-T transform to be applied.
--	object_count	- maximum number of objects to return
-- RETURNS:	Metadata for the object as a CLOB.

  FUNCTION get_dependent_ddl (
		object_type		IN  VARCHAR2,
		base_object_name	IN  VARCHAR2,
		base_object_schema	IN  VARCHAR2 DEFAULT NULL,
		version			IN  VARCHAR2 DEFAULT 'COMPATIBLE',
		model			IN  VARCHAR2 DEFAULT 'ORACLE',
		transform		IN  VARCHAR2 DEFAULT 'DDL',
		object_count		IN  NUMBER   DEFAULT 10000)
	RETURN CLOB IS
BEGIN
  RETURN dbms_metadata.get_dependent_ddl(object_type,base_object_name,
                                         base_object_schema, version,
                                         model, transform, object_count);
END;


END AD_DBMS_METADATA;
/

prompt
prompt End of Creating PL/SQL Package AD_DBMS_METADATA.
prompt

commit

prompt
prompt Creating PL/SQL Package AD_ZD_SYS.
prompt

create or replace package AD_ZD_SYS AUTHID DEFINER as
/* $Header: adgrants.sql 120.67.12020000.51 2017/02/22 21:26:05 jwsmith ship $ */
function LITERAL(X_VALUE varchar2) return varchar2;

procedure RETIRE_EDITION(X_EDITION_NAME in varchar2); /* obsolete */
procedure RETIRE_OLD_EDITIONS; /* obsolete */
procedure DROP_EDITION(x_edition_name in varchar2); 

procedure DROP_COVERED_OBJECT(
  X_OWNER        varchar2, 
  X_OBJECT_NAME  varchar2,
  X_OBJECT_TYPE  varchar2,
  X_EDITION_NAME varchar2);
procedure DROP_COVERED_OBJECTS(X_EXECUTE in boolean default true); /* obsolete */

procedure ACTUALIZE_OBJECT(
  X_OWNER        varchar2,
  X_OBJECT_NAME  varchar2,
  X_OBJECT_TYPE  varchar2);
procedure ACTUALIZE_ALL(X_EXECUTE in boolean default true);

procedure ALTER_LOGON_TRIGGER(X_STATUS in varchar2);

procedure FIX_SYSUSER;

procedure COPY_GRANTS(
  X_TABLE_OWNER in varchar2,
  X_TABLE_NAME  in varchar2,
  X_EV_NAME     in varchar2) ;

END AD_ZD_SYS;
/


CREATE OR REPLACE PACKAGE BODY AD_ZD_SYS AS
/* $Header: adgrants.sql 120.67.12020000.51 2017/02/22 21:26:05 jwsmith ship $ */

C_PACKAGE constant varchar2(80) := 'ad.plsql.ad_zd_sys.';

/*
** Exceptions we handle
*/
SUCCESS_WITH_COMPILE_ERR exception;
  pragma exception_init(success_with_compile_err, -24344);

OBJECT_DOES_NOT_EXIST  exception;
  pragma exception_init(object_does_not_exist, -4043);

TRIGGER_DOES_NOT_EXIST  exception;
  pragma exception_init(trigger_does_not_exist, -4080);

OBJECT_MARKED_FOR_DELETE  exception;
  pragma exception_init(object_marked_for_delete, -21700);

TYPE_NOT_FOUND  exception;
  pragma exception_init(type_not_found, -22303);

SYNONYM_DOES_NOT_EXIST exception;
  pragma exception_init(synonym_does_not_exist, -1434);

/*
** Write Log Message
*/
procedure LOG(X_MODULE varchar2, X_LEVEL varchar2, X_MESSAGE varchar2)
is
  L_APPLSYS varchar2(30);
  L_MODULE  varchar2(80) := c_package||x_module;
  L_CURSOR  int;
  L_STATUS  int;
begin
  -- get applsys schema
  select oracle_username into l_applsys 
  from system.fnd_oracle_userid
  where read_only_flag = 'E';

  -- insert log message
  l_cursor := dbms_sql.open_cursor;
  dbms_sql.parse(l_cursor,
     'insert into '||l_applsys||'.ad_zd_logs '||
     '  (log_sequence,  module, message_text, session_id, type, timestamp) '||
     '  values ('||l_applsys||'.ad_zd_logs_s.nextval, '||
                ':x_module, '||
                'substrb(:x_message,1,3900), '||
                'sys_context(''USERENV'',''SESSIONID''), '||
                ':x_level, '||
                'SYSDATE) ', dbms_sql.native);
  dbms_sql.bind_variable(l_cursor, ':x_module', l_module);
  dbms_sql.bind_variable(l_cursor, ':x_message', x_message);
  dbms_sql.bind_variable(l_cursor, ':x_level', x_level);
  l_status := dbms_sql.execute(l_cursor);
  dbms_sql.close_cursor(l_cursor);
  commit;

exception
  when others then
    null;    
end;

/*
** Log and raise error message
*/
procedure ERROR(X_MODULE varchar2, X_MESSAGE varchar2) is
begin
  log(x_module, 'ERROR', x_message);
  raise_application_error(-20001, x_message);
end;

/* 
Converts single quote to double quotes 
Bug 24494551
*/
function LITERAL(X_VALUE varchar2) return varchar2 is
begin 
    return replace(x_value,'''',''''''); 
end; 

/*
** Update LOGON trigger status.
**   - X_STATUS: ENABLE | DISABLE 
** 
** This is being called from ad_zd.alter_logon_trigger API.
*/
procedure ALTER_LOGON_TRIGGER(X_STATUS varchar2)
is
  C_MODULE  varchar2(80) := 'alter_logon_trigger';
begin  
  log(c_module, 'EVENT', 'Alter logon trigger: '||x_status);
  
  -- validate inputs
  if (upper(x_status) not in ('ENABLE', 'DISABLE')) then
    error(c_module, 'Invalid logon trigger status: '||x_status);
  end if;

  -- execute
  execute immediate 'alter trigger SYSTEM.EBS_LOGON '||x_status; 
end; 


/* Retire Edition - obsolete */
procedure RETIRE_EDITION(x_edition_name in varchar2) /* obsolete */
is
  C_MODULE  varchar2(80) := 'retire_edition';
begin
  log(c_module, 'WARNING', 'Call to obsolete procedure');
end;


/* Retire old editions - obsolete */
procedure RETIRE_OLD_EDITIONS /* obsolete */
is
  C_MODULE  varchar2(80) := 'retire_old_editions';
begin
  log(c_module, 'WARNING', 'Call to obsolete procedure');
end;


/*
** Drop unwanted database edition
**   x_edition_name - name of the edition to drop
*/
procedure DROP_EDITION(x_edition_name in varchar2) is
  C_MODULE      varchar2(80) := 'drop_edition';
  L_EDITION     varchar2(30) := x_edition_name;
  L_DEFAULT     varchar2(30);
  L_STMT        varchar2(1000);
begin
  log(c_module, 'PROCEDURE', 'begin: '||x_edition_name);

  -- validate edition name
  begin
    select edition_name into l_edition
    from   dba_editions
    where  edition_name = x_edition_name;
  exception
    when no_data_found then 
      error(c_module, 'Edition "'||x_edition_name||'" does not exist');
  end;

  -- we cannot drop the run edition 
  select property_value into l_default
  from   database_properties
  where  property_name = 'DEFAULT_EDITION';

  if (l_edition = l_default) then
    error(c_module, 'Cannot drop RUN edition');
  end if;

  -- drop the edition
  log(c_module, 'EVENT', 'Drop Edition: '||l_edition);
  begin
    l_stmt := 'drop edition '||l_edition||' cascade';
    execute immediate l_stmt;
  exception 
    when others then
      log(c_module, 'ERROR', SQLERRM||', SQL: '||l_stmt);
      raise;
  end;

  log(c_module, 'PROCEDURE', 'end');
end;


/*
** Drop covered object 
**
** Before droppping an object, it checks if the edition is really a retired edition.
** The above check is done to ensure that nobody can use this api to drop an object
** in a RUN edition
**
** x_old_edition - Edition not in usable state
*/
procedure DROP_COVERED_OBJECT(
  X_OWNER          varchar2,
  X_OBJECT_NAME    varchar2,
  X_OBJECT_TYPE    varchar2,
  X_EDITION_NAME   varchar2)
is
  C_MODULE          varchar2(80) := 'drop_covered_object';
  L_DEFAULT         varchar2(30);
  L_EXISTS          varchar2(1);
  L_STMT            varchar2(1000);
  L_CURSOR          integer;
  L_ERRMSG          varchar2(2000);
begin
  
  -- get run edition
  select property_value into l_default
  from   database_properties
  where  property_name = 'DEFAULT_EDITION';

  -- validate edition name is an old edition
  begin
    select 'Y' into l_exists
    from   dba_editions
    where  edition_name = x_edition_name
    and    edition_name < l_default;
  exception
    when no_data_found then 
      error(c_module, 'Edition "'||x_edition_name||'" is not an old edition');
  end;

  -- validate covered object exists
  -- note: object object may be in an older edition if we are
  --       in fact dropping a stub object that leads up to the
  --       covered object.
  begin
    select 'Y' into l_exists
    from   dba_objects_ae obj
    where  obj.owner        = x_owner
      and  obj.object_name  = x_object_name
      and  obj.object_type  = x_object_type
      and  obj.edition_name < l_default
      and  rownum = 1;
  exception
    when no_data_found then 
      -- object must be gone already
      return;
  end;

  -- Construct drop statement
  l_stmt := 'drop '||x_object_type||' '||'"'||x_owner||'"."'||x_object_name||'"';
  if x_object_type = 'TYPE' or x_object_type = 'SYNONYM' then
    l_stmt := l_stmt||' force';
  elsif x_object_type = 'VIEW' then
    l_stmt := l_stmt||' cascade constraints';
  end if;  
    
  -- Execute drop statement
  -- log(c_module, 'STATEMENT', 'SQL['||x_edition_name||': '||l_stmt;
  begin
    l_cursor :=  dbms_sql.open_cursor(security_level=>2);  
    dbms_sql.parse(l_cursor, l_stmt, dbms_sql.native, x_edition_name, null, false);
    dbms_sql.close_cursor(l_cursor); 
  exception
    when success_with_compile_err or 
         object_does_not_exist or 
         trigger_does_not_exist or 
         object_marked_for_delete or 
         type_not_found or
         synonym_does_not_exist then
      if dbms_sql.is_open(l_cursor) then
        dbms_sql.close_cursor(l_cursor);
      end if;
    when others then
      if dbms_sql.is_open(l_cursor) then
        dbms_sql.close_cursor(l_cursor);
      end if;
      log(c_module, 'ERROR', SQLERRM||', SQL['||x_edition_name||']: '||l_stmt);
      raise;
  end;
end;


/* Drop Covered Objects - obsolete */
procedure DROP_COVERED_OBJECTS(X_EXECUTE in boolean default true) /* obsolete */
IS
  C_MODULE          varchar2(80) := 'drop_covered_objects';
begin
  log(c_module, 'WARNING', 'Call to obsolete procedure: ad_zd_sys.drop_covered_objects');
end;


function CONSTRUCT_ACTUALIZE_DDL(
  X_OWNER          in varchar2,
  X_OBJECT_NAME    in varchar2,
  X_OBJECT_TYPE    in varchar2) return varchar2
is
  L_STMT_OBJECT_TYPE    varchar2(30);
  L_STMT                varchar2(2000) := '';
begin
  --  compute alter <type> for spec/body types
  if x_object_type = 'PACKAGE BODY' then
    l_stmt_object_type := 'PACKAGE';
  elsif x_object_type = 'TYPE BODY' then
    l_stmt_object_type := 'TYPE';
  else
    l_stmt_object_type := x_object_type;
  end if;

  l_stmt := 'alter '||l_stmt_object_type||' "'||x_owner||'"."'||x_object_name||'"'||' compile';

  -- add type-specific compile parameters
  l_stmt := case x_object_type
                when 'PROCEDURE'    then l_stmt||' reuse settings'
                when 'PACKAGE'      then l_stmt||' SPECIFICATION reuse settings'
                when 'PACKAGE BODY' then l_stmt||' BODY reuse settings'
                when 'FUNCTION'     then l_stmt||' reuse settings'
                when 'TRIGGER'      then l_stmt||' reuse settings'
                when 'TYPE'         then l_stmt||' SPECIFICATION reuse settings'
                when 'TYPE BODY'    then l_stmt||' BODY reuse settings'
                else                     l_stmt
            end;

  return l_stmt;
end;


/*
** Actualize an object in patch edition
*/
procedure ACTUALIZE_OBJECT(
  X_OWNER               varchar2,
  X_OBJECT_NAME         varchar2,
  X_OBJECT_TYPE         varchar2)
is
  C_MODULE              varchar2(80) := 'actualize_object';
  L_COUNT               number := 0;
  L_STMT_OBJECT_TYPE    varchar2(30);
  L_STMT                varchar2(2000);
  L_CURSOR              integer;
  L_DEFAULT_EDITION     varchar2(30);
  L_LATEST_EDITION      varchar2(30);
  L_PATCH_EDITION       varchar2(30);
begin
  
  -- Get run edition
  select property_value into l_default_edition
  from   database_properties
  where  property_name = 'DEFAULT_EDITION';

  -- Get patch edition (or fallback to run edition)
  begin
    select aed.edition_name into l_patch_edition
    from   all_editions AED
    where  aed.parent_edition_name = l_default_edition;
  exception
     when no_data_found then
       l_patch_edition := l_default_edition;
  end;

  -- Validate editioned object exists
  select max(obj.edition_name) into l_latest_edition
  from   dba_objects_ae obj
  where  owner = x_owner 
    and  object_name = x_object_name
    and  object_type = x_object_type;

  if (l_latest_edition is null) then
    error(c_module, x_owner||'.'||x_object_name||' ('||x_object_type||') is not an editioned object');
  end if;

  -- Actualize object if needed
  if (l_latest_edition < l_patch_edition) then 
    l_stmt := construct_actualize_ddl(x_owner,x_object_name,x_object_type);
    l_cursor :=  dbms_sql.open_cursor(security_level=>2);  
    dbms_sql.parse(l_cursor, l_stmt, 
                   DBMS_SQL.NATIVE, l_patch_edition, null, false);	 
    dbms_sql.close_cursor(l_cursor); 
  end if;

exception
 when success_with_compile_err then
    if dbms_sql.is_open(l_cursor) then
       dbms_sql.close_cursor(l_cursor);
    end if;
 when others then
    if dbms_sql.is_open(l_cursor) then
       dbms_sql.close_cursor(l_cursor);
    end if;
    -- the caller (ad_zd_parallel_exec.execute) will log any errors
    -- log(c_module, 'ERROR', SQLERRM||', SQL: '||l_stmt); 
    raise;
end;


/*
** Two pass approach for less conflict with parallel workers
**   pass 1: ACTUALIZE_PARENT_OBJS - objects that DO NOT depend on other objects
**   pass 2: ACTUALIZE_CHILD_OBJS  - objeccts that depend on other objects
*/
procedure PROCESS_INHERITED_OBJS(X_PHASE   in varchar2,
                                 X_EDITION in varchar2)
is
  C_MODULE            varchar2(80) := 'process_inerited_objs';
  L_APPLSYS           varchar2(30);
  L_OWNER             varchar2(30);
  L_OBJECT_NAME       varchar2(128);
  L_OBJECT_TYPE       varchar2(30);
  L_SQL               varchar2(2000);
  L_OBJ_NAME          varchar2(128);

  -- Inherited objects that do not depend on other editioned objects,
  cursor C_INHERITED_OBJECTS_PARENT(x_edition varchar2) is
    select owner, object_name, object_type
    from dba_objects obj
    where obj.edition_name is not null
      and obj.edition_name <> x_edition
      and obj.owner in 
            ( select username from dba_users where editions_enabled = 'Y' )
      and not exists 
            ( select null from dba_dependencies d
              where d.owner = obj.owner
                and d.name  = obj.object_name
                and d.type  = obj.object_type
                and d.referenced_owner in 
                      ( select username from dba_users where editions_enabled = 'Y' )
                and d.referenced_type in 
                      ('TYPE','SYNONYM','PACKAGE','VIEW','TYPE BODY','PACKAGE BODY','FUNCTION','PROCEDURE','TRIGGER') );

  -- Inherited objects that depend on other editioned objects,
  cursor C_INHERITED_OBJECTS_CHILD(x_edition varchar2) is
  select * from (
    select owner, object_name, object_type
    from dba_objects obj
    where obj.edition_name is not null
      and (obj.edition_name <> x_edition or obj.status = 'INVALID')
      and obj.owner in 
            ( select username from dba_users where editions_enabled = 'Y' )
    minus
    select owner, object_name, object_type
    from dba_objects obj
    where obj.edition_name is not null
      and obj.edition_name <> x_edition
      and obj.owner in 
            ( select username from dba_users where editions_enabled = 'Y' )
      and not exists 
            ( select null from dba_dependencies d
              where d.owner = obj.owner
                and d.name  = obj.object_name
                and d.type  = obj.object_type
                and d.referenced_owner in 
                      ( select username from dba_users where editions_enabled = 'Y' )
                and d.referenced_type in 
                      ('TYPE','SYNONYM','PACKAGE','VIEW','TYPE BODY','PACKAGE BODY','FUNCTION','PROCEDURE','TRIGGER') ) )
  order by decode(object_type,
                  'TYPE',         1, /* most types depend on native or other types */
                  'SYNONYM',      2, /* synonyms point to EVs and types */
                  'PACKAGE',      3, /* packages can depend on types */
                  'VIEW',         4, /* views depend on packages and synonyms */
                  'TYPE BODY',    5,
                  'PACKAGE BODY', 6,
                                  7), object_name;

begin
  -- get applsys schema name
  select oracle_username into L_APPLSYS 
  from system.fnd_oracle_userid
  where read_only_flag = 'E';
 
  -- open correct cursor
  if (x_phase = 'ACTUALIZE_PARENT_OBJS') then
    open c_inherited_objects_parent(x_edition);
  elsif (x_phase = 'ACTUALIZE_CHILD_OBJS') then
    open c_inherited_objects_child(x_edition);
  end if;

  -- fetch and execute or load
  loop
    if (x_phase = 'ACTUALIZE_PARENT_OBJS') then
      fetch c_inherited_objects_parent into l_owner, l_object_name,l_object_type;
      exit when (c_inherited_objects_parent%NOTFOUND or (c_inherited_objects_parent%NOTFOUND is null));
    elsif (x_phase = 'ACTUALIZE_CHILD_OBJS') then
      fetch c_inherited_objects_child into l_owner, l_object_name,l_object_type;
      exit when (c_inherited_objects_child%NOTFOUND or (c_inherited_objects_child%NOTFOUND is null));
    end if;
    
    l_obj_name := literal(l_object_name);
    l_obj_name := literal(l_obj_name);

    l_sql := 'insert into '||l_applsys||'.ad_zd_ddl_handler '||
             '(phase, ddl_id, sql_lob, executed, status) values ('''||x_phase||
             q'[',]' || l_applsys ||'.ad_zd_ddl_handler_ddl_s.nextval, ' ||
             q'['begin sys.ad_zd_sys.actualize_object('']' || l_owner||
             q'['','']' || l_obj_name  || 
             q'['','']' || l_object_type  ||
             q'[''); end;', 'N', 'NOT-EXEC')]' ;  
            
    execute immediate l_sql; 
  end loop;

  -- close correct cursor
  if (x_phase = 'ACTUALIZE_PARENT_OBJS') then
    close c_inherited_objects_parent;
  elsif (x_phase = 'ACTUALIZE_CHILD_OBJS') then
    close c_inherited_objects_child;
  end if;
end;


/*
**  Actualize all
**     - Actualize All Objects in the PATCH edition
**
**  x_execute - Default value, True means Execute the DDLs immediately
**            - False means, use the parallel workers architecture
*/
procedure ACTUALIZE_ALL(X_EXECUTE in boolean default true) 
is
  C_MODULE           varchar2(80) := 'actualize_all';
  L_DEFAULT_EDITION  varchar2(30);
  L_CURRENT_EDITION  varchar2(30);
  L_PATCH_EDITION    varchar2(30);
  L_APPS_SCHEMA      varchar2(30);

  cursor C_ADZD_OBJECTS(x_edition varchar2) is
    select o.owner, o.object_name, o.object_type
    from dba_objects o
    where o.edition_name  <>  x_edition
      and o.owner         in  ( select username from dba_users where editions_enabled = 'Y')
      and o.object_name   like 'AD_ZD%'
      and o.object_type   in ('PACKAGE','PACKAGE BODY') 
    order by o.owner, o.object_type, o.object_name;

begin
  log(c_module, 'PROCEDURE', 'begin');

  if (x_execute) then
    error(c_module, 'execute mode is currently not supported');
  end if;

  l_current_edition :=  sys_context('userenv', 'current_edition_name');

  -- run edition
  select property_value into l_default_edition
  from   database_properties
  where  property_name = 'DEFAULT_EDITION';

  -- patch edition (if any)
  begin
    select aed.edition_name into l_patch_edition
    from   all_editions AED
    where  aed.parent_edition_name = l_default_edition;
  exception
    when no_data_found then
      l_patch_edition := NULL;
  end;

  -- validate proper execution edition
  if (l_patch_edition is null) then
    -- must be in run edition 
    if (l_current_edition <> l_default_edition) then
      error(c_module, 'Actualize All can only be run in the RUN edition when there is no patch edition');
    end if;
  else
    -- must be in patch edition 
    if (l_current_edition <> l_patch_edition) then
      error(c_module, 'Actualize All can only be run in the PATCH edition');
    end if;
  end if;

  select oracle_username into l_apps_schema
  from   system.fnd_oracle_userid
  where  read_only_flag ='U';

  /* 
  ** Bug#14469886
  ** ALL AD_ZD packages are compiled before itself to
  ** avoid errors while running acutalize all in parallel workers mode.
  */
  log(c_module, 'EVENT', 'Actualize AD_ZD% packages');
  for objrec in c_adzd_objects(l_current_edition) loop
    actualize_object(objrec.owner, objrec.object_name, objrec.object_type);
  end loop;

  log(c_module, 'EVENT', 'Actualize all editioned objects');
  process_inherited_objs('ACTUALIZE_PARENT_OBJS', l_current_edition);
  process_inherited_objs('ACTUALIZE_CHILD_OBJS', l_current_edition);
  commit;

end ACTUALIZE_ALL;

/* 
** FIX_SYSUSER : This procedure will query the dba_tab_privs to get the 
** unnecessary privileges on sys.dual given by SYS and revoke all of 
** those privileges. This procedure will be called from ADFIXUSER.sql
*/
procedure FIX_SYSUSER is
   C_MODULE    varchar2(80) := 'fix_sys_user';
   L_SYS_USER  varchar2(20) := 'SYS';
   L_STMT      varchar2(400);
   cursor SYS_USER is
     select grantee, privilege
     from dba_tab_privs
     where table_name = 'DUAL'
       and owner      = l_sys_user
       and grantor    = l_sys_user
       and privilege  <> 'SELECT';
begin
  log(c_module, 'EVENT', 'Revoke permission on DUAL');
  for user in sys_user loop
    l_stmt := 'revoke '||user.privilege||' on DUAL from '||user.grantee;
    log(c_module, 'STATEMENT', 'SQL: '||l_stmt);
    execute immediate l_stmt;
  end loop;
end fix_sysuser;

--
-- This procedure copies the Object grants from Table to EV. 
-- 
-- NOTE: All grants can NOT be copied because some grants may not 
--       be applicable on a VIEW while same may be applicable on 
--       a table. 
-- 
--   View PRIVILEGES
--   ==============
--   DEBUG, DELETE, INSERT, MERGE, REFERENCES, SELECT, UNDER, UPDATE 
--
--   TABLE PRIVILEGES : 
--   ==================
--    ALTER, DELETE, DEBUG, INDEX, INSERT, REFERENCES,  SELECT,  UPDATE 
-- 
procedure COPY_GRANTS(
  X_TABLE_OWNER in varchar2,
  X_TABLE_NAME  in varchar2,
  X_EV_NAME     in varchar2) 
is
  C_MODULE           varchar2(127) := 'copy_grants';
  L_STR              varchar2(1026);
  L_EV_STR_PRIVILEGE varchar2(1024);

cursor C_GRANTS(P_TABLE_OWNER varchar2, 
                P_TABLE_NAME varchar2, 
                P_VIEW_NAME varchar2) is
      select distinct
          tpt.grantee
        , tpt.privilege
        , tpt.grantable
        , tpt.hierarchy 
      from
          dba_tab_privs tpt
      where tpt.owner = p_table_owner
        and tpt.table_name  = p_table_name 
        and tpt.privilege in ('SELECT', 'UPDATE', 'INSERT', 'REFERENCES',
                              'DELETE', 'DEBUG', 'READ')
        and tpt.grantee <> 'SYS' /* To avoid: ORA-01749, ORA-01031: */ 
        and not exists
            ( select 'x'
              from   dba_tab_privs tpv
              where  tpv.owner      = tpt.owner
                and  tpv.table_name = p_view_name
                and  tpv.grantee    = tpt.grantee
                and  tpv.privilege  = tpt.privilege 
             )
       order by grantee; 

begin

  l_ev_str_privilege := 'GRANT '; 
  
  begin   
    for grant_rec in c_grants (x_table_owner, x_table_name, x_ev_name) 
    loop 
    
      l_ev_str_privilege := l_ev_str_privilege || grant_rec.privilege || ' ON "' || 
                            x_table_owner || '"."'||x_ev_name || '" TO "' || 
                            grant_rec.grantee || '" ' ; 
      
      if (nvl(grant_rec.grantable, 'NO') = 'YES' ) then
       l_ev_str_privilege := l_ev_str_privilege || ' WITH GRANT OPTION ';    
      end if;
        
      if (nvl(grant_rec.hierarchy, 'NO') = 'YES' and grant_rec.privilege='SELECT' ) then
       l_ev_str_privilege := l_ev_str_privilege || ' WITH HIERARCHY OPTION '; 
      end if;      
     
      -- Ignore if any error 
      --  ad_zd.exec(l_ev_str_privilege, c_module, true);   
      log(c_module, 'STATEMENT', 'SQL: '||l_ev_str_privilege );
      begin
        execute immediate l_ev_str_privilege;
        exception
         when others then
            log(c_module, 'ERROR', SQLERRM||', SQL: '||l_ev_str_privilege);
            raise;
      end;
      l_ev_str_privilege := 'GRANT '; 

   end loop;    
  exception
   when others then
     log(c_module, 'ERROR', SQLERRM);
     raise;   
  end;
  
end COPY_GRANTS; 
END AD_ZD_SYS;
/

prompt
prompt End of Creating PL/SQL Package AD_ZD_SYS.
prompt

commit

prompt
prompt Start of Creating PL/SQL Package AD_GRANTS.
prompt

create or replace package AD_GRANTS AUTHID DEFINER as
/* $Header: adgrants.sql 120.67.12020000.51 2017/02/22 21:26:05 jwsmith ship $ */

procedure REVOKE_GRANT(X_DEP_USER varchar2,
                       X_REFERENCED_OBJ   varchar2,
                       X_GRANT varchar2);

procedure CLEANUP;

END AD_GRANTS;
/

CREATE OR REPLACE PACKAGE BODY AD_GRANTS AS
/* $Header: adgrants.sql 120.67.12020000.51 2017/02/22 21:26:05 jwsmith ship $ */

C_PACKAGE constant varchar2(80) := 'ad.plsql.ad_grants.';

CANNOT_REVOKE_PRIVS_GRANTED exception;
  pragma exception_init(cannot_revoke_privs_granted, -01927);

/*
** CLEANUP unwanted grants
*
*  Description:
*    - Check if any of the EBS objects depend upon X_REFERENCED_OBJ
*       - If any do not revoke
*    - Check if the privilege actually exist
*       - If exist, then only revoke
*/
procedure REVOKE_GRANT(X_DEP_USER varchar2, 
                       X_REFERENCED_OBJ   varchar2,
                       X_GRANT varchar2)
is
  L_COUNT   number;
  L_STMT    varchar2(2000);
begin

  select count(1) into l_count from dba_dependencies dd
   where dd.referenced_name=upper(x_referenced_obj)
     and dd.referenced_owner='SYS'
     and dd.owner=upper(x_dep_user)
     and exists (select 'X' from system.fnd_oracle_userid
                    where oracle_username=upper(x_dep_user)
                    and read_only_flag in ('A','B', 'E', 'U', 'C'));

  if (l_count < 1) then

    l_stmt := 'select count(1) from dba_tab_privs ' ||
              'where table_name=:x_referenced_obj and privilege=:x_grant ' ||
              'and   grantee=:x_dep_user';

    execute immediate l_stmt into l_count 
        using upper(x_referenced_obj), upper(x_grant), upper(x_dep_user);

    if(l_count > 0) then
      l_stmt := 'revoke ' || 
           upper(x_grant) ||
           ' on SYS.' || upper(x_referenced_obj) || ' from ' || 
           upper(x_dep_user);

      execute immediate l_stmt;  
    end if;
  end if;

exception
  when cannot_revoke_privs_granted then
    null;
  when others then
    raise;
end REVOKE_GRANT;

procedure CLEANUP 
is
begin

  revoke_grant('&appsUserName', 'DBMS_SYS_SQL', 'EXECUTE');

end CLEANUP;

end AD_GRANTS;
/

commit;

prompt
prompt End of Creating PL/SQL Package AD_GRANTS.
prompt


prompt Start of giving grants. This may take few minutes.

set termout on
set serveroutput on

DECLARE 

type TableNameType is table of varchar2(100)
  index by binary_integer;

object_list TableNameType;
grant_type_list TableNameType;

TYPE PrivligeRec IS RECORD (
  object_name        VARCHAR2(30),
  privilege          VARCHAR2(30), 
  grantee            VARCHAR2(30),
  admin_option       boolean,
  grant_type         number
  );
type PrivilegeObjType is table of PrivligeRec;
privarray PrivilegeObjType := PrivilegeObjType();
missing_privarray PrivilegeObjType := PrivilegeObjType();
list_count number;
missing_list_count number;

vdir varchar2(20) :='FND_DIAG_DIR';
vexists varchar2(1) := 'N';
vpath        varchar2(300);
vstmt varchar2(500);

role_list varchar2(4000);
db_role_list varchar2(4000);
--
-- Function 
--   get_udump_dir 
--
-- Purpose
--   Fetches the path pointed by user_dump_test parameter.
--
-- Arguments
--
-- Returns
--   The Directory path pointed by user_dump_test 
--   if no such path, then the path pointed by diagnostic_dest
-- Example
--   none


function get_udump_dir return varchar2 is
         vpath varchar2(200);

begin

  select substr(value,1,decode(instr(value,',')-1,-1,length(value),instr(value,',')-1))
         into vpath from v$parameter where name = 'user_dump_dest';

  return (vpath);

exception

  when no_data_found then
    begin
      select substr(value,1,decode(instr(value,',')-1,-1,length(value),instr(value,',')-1))
             into vpath from v$parameter where name = 'diagnostic_dest';
    exception
      when others then
        raise; -- Should not come here.
    end;

end get_udump_dir; 

--
-- Procedure
--   add_list
--
-- Purpose
--   Create tables which are used later by the procedure give_grants.
--
-- Arguments
--   X_sys_object         name of SYS object
--   X_grant_type         type of grants such as select , execute etc.
--
-- Example
--   none

-- grant_type:-
--   0 Normal user privileges on objects
--   1 System defined privileges
--   2 Roles
procedure add_list
       ( X_sys_object   in varchar2 default null,
         X_privilege   in varchar2,
         X_grantee      in varchar2 default null,
         x_admin_option in boolean default false,
         x_grant_type     in number  default 0,
         x_add_to_missing in boolean default false)
is
l_privrec PrivligeRec;
begin

  privarray.extend();
  l_privrec.object_name     :=  upper(X_sys_object);
  l_privrec.privilege       :=  upper(X_privilege);
  l_privrec.grantee         :=  upper(X_grantee);
  l_privrec.admin_option    :=  x_admin_option;
  l_privrec.grant_type      :=  x_grant_type;
  if (x_add_to_missing)
  then
     missing_list_count := missing_list_count + 1 ;
     missing_privarray.extend();
     missing_privarray(missing_list_count)  :=  l_privrec;   
  else
     list_count := list_count + 1;
     privarray(list_count)     :=  l_privrec;
  end if;
  -- if grant type is role add to role list
  if (x_grant_type = 2 and upper(X_grantee) = upper('&&appsUserName') )
  then
     if role_list is null
     then
        role_list := '''' ||  upper(X_privilege) || '''';
     else 
        role_list := role_list || ',' || '''' ||  upper(X_privilege) || '''';
     end if;  -- end role_list empty
  end if;  -- end role adding
exception
    when others then
        raise_application_error(-20000, sqlerrm || 'Error in ad_grants.add_list');
end add_list;

procedure load_table_list
is
  cursor C_RETIRED_EDITIONS is
         select edition_name 
         from   dba_editions
         where  edition_name not in
               (select edition_name 
                  from dba_editions, dba_tab_privs
                 where owner='SYS'
                   and edition_name=table_name
                   and grantee='PUBLIC'
                   and privilege='USE')
         order by 1 desc;
begin

  list_count := 0;
  missing_list_count := 0;
  role_list := null;
--
-- SYS tables on which Apps needs privileges 
--
-- (please keep in alphabetical order)
--
  add_list('AD_EXTENTS','SELECT');
  add_list('ALL_COL_COMMENTS','SELECT');
  add_list('ALL_IND_COLUMNS','SELECT');
  add_list('ALL_OBJECTS','SELECT');
  add_list('ALL_SEQUENCES','SELECT');
  add_list('ALL_SOURCE','SELECT');
  add_list('ALL_TABLES','SELECT');
  add_list('ALL_TAB_COLUMNS','SELECT');
  add_list('ARGUMENT$','SELECT');
  add_list('AW$','SELECT');  
  add_list('DBA_AWS','SELECT');
  add_list('DBA_COL_COMMENTS','SELECT');
  add_list('DBA_CONSTRAINTS','SELECT');
  add_list('DBA_CONS_COLUMNS','SELECT');
  add_list('DBA_CONTEXT','SELECT');
  add_list('DBA_DATA_FILES','SELECT');
  add_list('DBA_DEPENDENCIES','SELECT');
  add_list('DBA_EDITIONING_VIEWS', 'SELECT');
  add_list('DBA_EDITIONING_VIEWS_AE', 'SELECT');
  add_list('DBA_EDITIONING_VIEW_COLS_AE', 'SELECT');
  add_list('DBA_ERRORS','SELECT');
  add_list('DBA_EXTENTS','SELECT');
  --Bug 4748813, VPALAKUR, 22-Nov-2005
  add_list('DBA_EXTERNAL_TABLES','SELECT');
  add_list('DBA_FREE_SPACE','SELECT');
  add_list('DBA_INDEXES','SELECT');
  add_list('DBA_IND_COLUMNS','SELECT');
  add_list('DBA_IND_EXPRESSIONS','SELECT');
  add_list('DBA_IND_PARTITIONS','SELECT');
  add_list('DBA_JOBS','SELECT');
  add_list('DBA_LOB_PARTITIONS','SELECT');
  add_list('DBA_LOBS','SELECT');
  add_list('DBA_METHOD_PARAMS','SELECT');
  add_list('DBA_METHOD_RESULTS','SELECT');
  add_list('DBA_MVIEWS','SELECT');
  add_list('DBA_MVIEW_DETAIL_RELATIONS','SELECT');
  add_list('DBA_MVIEW_LOG_FILTER_COLS','SELECT');
  add_list('DBA_MVIEW_LOGS','SELECT');
  add_list('DBA_OBJECTS','SELECT');
  --Bug 23125014, SEETSING, 29-APR-16
  add_list('DBA_PARALLEL_EXECUTE_CHUNKS','SELECT');
  add_list('DBA_PART_INDEXES','SELECT');
  --Bug 3696123, CBHATI, 17-JUN-04
  add_list('DBA_PART_KEY_COLUMNS','SELECT');
  add_list('DBA_PART_TABLES','SELECT');
  add_list('DBA_POLICIES','SELECT');
  --Bug 4997702, VPALAKUR, 25-JAN-06
  add_list('DBA_POLICY_GROUPS','SELECT');
  --Bug 5497816 schinni 30 AUG 06
  add_list('DBA_PROCEDURES','SELECT');
  --Bug 5438644 SCHINNI 14-AUG-06
  add_list('DBA_PROFILES','SELECT');
  add_list('DBA_QUEUES','SELECT');
  add_list('DBA_QUEUE_TABLES','SELECT');
  --Bug 3651346, HXUE, 08-JUN-04
  add_list('DBA_QUEUE_SCHEDULES','SELECT');
  add_list('DBA_REGISTERED_SNAPSHOTS','SELECT');
  add_list('DBA_REGISTERED_MVIEWS','SELECT');
  add_list('DBA_REGISTRY','SELECT');
  add_list('DBA_ROLE_PRIVS','SELECT');
  add_list('DBA_ROLLBACK_SEGS','SELECT');
  add_list('DBA_RSRC_CONSUMER_GROUPS','SELECT');
  add_list('DBA_RSRC_CONSUMER_GROUP_PRIVS','SELECT');
  add_list('DBA_RSRC_MANAGER_SYSTEM_PRIVS','SELECT');
  add_list('DBA_RSRC_PLANS','SELECT');
  add_list('DBA_RSRC_PLAN_DIRECTIVES','SELECT');
  add_list('DBA_SEGMENTS','SELECT');
  add_list('DBA_SEQUENCES','SELECT');
  add_list('DBA_SNAPSHOTS','SELECT');
  add_list('DBA_SNAPSHOT_LOGS','SELECT');
  add_list('DBA_SOURCE','SELECT');
  add_list('DBA_SYNONYMS','SELECT');
  add_list('DBA_SYS_PRIVS','SELECT');
  add_list('DBA_TABLES','SELECT');
  add_list('DBA_TABLESPACES','SELECT');
  add_list('DBA_TAB_COLS','SELECT');
  add_list('DBA_TAB_COLUMNS','SELECT');
  add_list('DBA_TAB_COMMENTS','SELECT');
  add_list('DBA_TAB_HISTOGRAMS','SELECT'); 
  add_list('DBA_TAB_MODIFICATIONS','SELECT');
  add_list('DBA_TAB_PARTITIONS','SELECT');
  add_list('DBA_TAB_PRIVS','SELECT');
  add_list('DBA_TAB_STATISTICS','SELECT');
  add_list('DBA_TEMP_FILES','SELECT');
  add_list('DBA_TRIGGER_ORDERING','SELECT');
  add_list('DBA_TRIGGER_COLS','SELECT');
  add_list('DBA_TRIGGERS','SELECT');
  add_list('DBA_TS_QUOTAS','SELECT');
  add_list('DBA_TYPES','SELECT');
  add_list('DBA_TYPE_ATTRS','SELECT');
  add_list('DBA_TYPE_METHODS','SELECT');
  add_list('DBA_TYPE_VERSIONS','SELECT');  
  add_list('DBA_USERS','SELECT');
  add_list('DBA_VIEWS','SELECT');
  --Bug 3777732, HXUE, 19-JUL-04
  add_list('DBMS_UPG_CURRENT_STATUS','SELECT');
  add_list('DBMS_UPG_DEBUG','SELECT');
  add_list('DBMS_UPG_STATUS','SELECT');
  add_list('DBMS_UPG_STATUS$','SELECT');
  add_list('DEPENDENCY$','SELECT');
  -- Bug 16670260: 16-Apr-2013 MKUMANDU
  add_list('"_ACTUAL_EDITION_OBJ"','SELECT');
  add_list('ERROR$','SELECT');
  add_list('EXPDEPOBJ$','SELECT');
  add_list('GV_$INSTANCE','SELECT');
  add_list('GV_$PARAMETER','SELECT');
  add_list('GV_$PROCESS','SELECT');
  add_list('GV_$SESSION','SELECT');
  add_list('GV_$SESSION_EVENT','SELECT');
  add_list('GV_$SYSTEM_PARAMETER','SELECT');
  add_list('GV_$AQ','SELECT');
  add_list('GV_$LOGFILE','SELECT');
  -- Bug 17295356, asutrala, 19-AUG-2014
  add_list('GV_$TRANSACTION', 'SELECT');
  add_list('GV_$LOCK', 'SELECT');
  --Bug 11879053
  add_list('DBA_EDITIONS','SELECT');
  add_list('DBA_OBJECTS_AE','SELECT');
  add_list('DBA_REDEFINITION_ERRORS','SELECT');
  add_list('DBA_TAB_PRIVS','SELECT');
  add_list('DBA_INVALID_OBJECTS','SELECT');
  add_list('DBA_SERVICES','SELECT');
  add_list('V_$ACTIVE_SERVICES','SELECT');
  add_list('DBA_EDITIONS','SELECT');
  --Bug 5383112, VLIM, 24-JUL-06, start
  add_list('GV_$SYSSTAT','SELECT');
  --Bug 5383112, VLIM, 24-JUL-06, end
  --Bug 7026771 DIVERMA 02 JUNE 2008
  add_list('GV_$SESSTAT','SELECT');
  add_list('IND$','SELECT');
  add_list('OBJ$','SELECT');
  add_list('OBJAUTH$','SELECT');
  add_list('PLSQL_PROFILER_DATA','SELECT');
  add_list('PLSQL_PROFILER_DATA','INSERT');
  add_list('PLSQL_PROFILER_DATA','UPDATE');
  add_list('PLSQL_PROFILER_DATA','DELETE');
  add_list('PLSQL_PROFILER_RUNS','SELECT');
  add_list('PLSQL_PROFILER_RUNS','INSERT');
  add_list('PLSQL_PROFILER_RUNS','UPDATE');
  add_list('PLSQL_PROFILER_RUNS','DELETE');
  add_list('PLSQL_PROFILER_RUNNUMBER','SELECT');
  add_list('PLSQL_PROFILER_UNITS','SELECT');
  add_list('PLSQL_PROFILER_UNITS','INSERT');
  add_list('PLSQL_PROFILER_UNITS','UPDATE');
  add_list('PLSQL_PROFILER_UNITS','DELETE');
  add_list('PROCEDURE$','SELECT');
  add_list('PRODUCT_COMPONENT_VERSION','SELECT');
  
  add_list('REDEF_DEP_ERROR$','SELECT');
  add_list('REDEF_DEP_ERROR$','DELETE');

  add_list('SEG$','SELECT');
  add_list('SOURCE$','SELECT');
  add_list('SUM$','SELECT');
  add_list('SUMDEP$','SELECT');
  --Bug 4878753, VPALAKUR 12-DEC-05
  add_list('SYS_DBA_SEGS','SELECT');
  add_list('TAB$','SELECT');
  add_list('TRIGGER$','SELECT');
  add_list('TS$','SELECT');
  add_list('UNDO$','SELECT');
  add_list('USER$','SELECT');  


  -- sstomar bug:13987339
  add_list('REGISTRY$','SELECT');
  add_list('REGISTRY$SCHEMAS','SELECT');  

  add_list('USER_OBJECTS','SELECT');
  add_list('USER_TAB_COLUMNS','SELECT');
  add_list('V_$DATABASE','SELECT');
  add_list('V_$DATAFILE','SELECT');
  add_list('V_$INSTANCE','SELECT');
  add_list('V_$LOCK','SELECT');
 --Bug4925737, VPALAKUR, 04-JAN-06
  add_list('V_$LOCKED_OBJECT','SELECT');
  add_list('V_$MVREFRESH','SELECT');
  add_list('V_$MYSTAT','SELECT');
  add_list('V_$NLS_PARAMETERS','SELECT');
  add_list('V_$PARAMETER','SELECT');
  add_list('V_$PARAMETER2','SELECT');
  add_list('V_$PQ_SYSSTAT','SELECT');
  add_list('V_$PROCESS','SELECT');
  add_list('V_$ROLLSTAT','SELECT');
  add_list('V_$ROWCACHE','SELECT');
  add_list('V_$SESSION','SELECT');
  --Bug4925737, VPALAKUR, 04-JAN-06
  add_list('V_$SESSION_WAIT','SELECT');
  add_list('V_$SESSTAT','SELECT');
  add_list('V_$STATNAME','SELECT');
  add_list('V_$SQL','SELECT'); 
  add_list('V_$SQLAREA','SELECT');
  add_list('V_$SQLTEXT','SELECT');
  add_list('V_$SYSTEM_PARAMETER','SELECT');
  add_list('V_$THREAD','SELECT');
  add_list('V_$TRANSACTION','SELECT');
  add_list('V_$TYPE_SIZE','SELECT');
  add_list('V_$VERSION','SELECT');
  add_list('V_$LOG','SELECT');
  add_list('V_$LOGFILE','SELECT');
  add_list('V_$CONTROLFILE_RECORD_SECTION','SELECT');
  add_list('V_$TEMPFILE','SELECT');
  add_list('V_$TABLESPACE','SELECT');
  --Bug 5383112, VLIM, 24-JUL-06, start
  --SELECT on V_$ROLLSTAT was already added by VPALAKUR on 04-JAN-06
  add_list('V_$ROLLNAME','SELECT');
  add_list('V_$SYSSTAT','SELECT');
  --Bug 5383112, VLIM, 24-JUL-06, end

  add_list('V_$AW_OLAP','SELECT');

  --Bug 18811975 , shivaaga
  add_list('V_$CELL','SELECT');
  --Updated by nissubra for Bug 6342059 on 9th-Oct-07
  
--
-- SYS packages on which Apps needs privileges
--
-- (please keep in alphabetical order)
--
  
  add_list('AD_DBMS_METADATA','EXECUTE');
  add_list('AD_ZD_SYS','EXECUTE');

  -- Bug 22160447
  add_list('AD_GRANTS', 'EXECUTE');

  add_list('DBMS_ALERT','EXECUTE');
  add_list('DBMS_APPLICATION_INFO','EXECUTE');
  add_list('DBMS_AQ','EXECUTE');
  add_list('DBMS_AQADM','EXECUTE');
  add_list('DBMS_AW','EXECUTE');
  add_list('DBMS_DESCRIBE','EXECUTE');
  add_list('DBMS_JAVA','EXECUTE');
  add_list('DBMS_JOB','EXECUTE');
  add_list('DBMS_LOB','EXECUTE');
  add_list('DBMS_LOCK','EXECUTE');
  add_list('DBMS_MVIEW','EXECUTE');
  add_list('DBMS_OBFUSCATION_TOOLKIT','EXECUTE');
  add_list('DBMS_OUTPUT','EXECUTE');
  add_list('DBMS_PIPE','EXECUTE');
  add_list('DBMS_PROFILER','EXECUTE');
  add_list('DBMS_REDEFINITION','EXECUTE');
  add_list('DBMS_RANDOM','EXECUTE');
  add_list('DBMS_REPCAT','EXECUTE');
  add_list('DBMS_RLS','EXECUTE');
  --Bug 3777732, HXUE, 19-JUL-04  
  add_list('DBMS_SCHEMA_COPY','EXECUTE');
  add_list('DBMS_SESSION','EXECUTE');
  add_list('DBMS_SQL','EXECUTE');
  add_list('DBMS_SPACE','EXECUTE');
  add_list('DBMS_SPACE_ADMIN','EXECUTE');
  add_list('DBMS_STATS','EXECUTE');
  add_list('DBMS_SYSTEM','EXECUTE');
  add_list('DBMS_TRANSACTION','EXECUTE');
  add_list('DBMS_UTILITY','EXECUTE');
  add_list('DBMS_XMLGEN','EXECUTE');
  add_list('DBMS_XMLQUERY','EXECUTE');
  add_list('DBMS_XMLSAVE','EXECUTE');
  add_list('UTL_RECOMP','EXECUTE');
  --bug 6802608 diverma 15-feb-2007
  add_list('DBA_RULES','SELECT');
  -- sstomar : 14-Apr-2011: added for nzdt. 
  add_list('DBMS_OBJECTS_UTILS','EXECUTE');
  add_list('DBMS_OBJECTS_UTILS_TSOURCE','EXECUTE');
  -- sstomar : 24-aug-2011 
  add_list('DBMS_OBJECTS_UTILS_TNAMEARR','EXECUTE');
  add_list('DBMS_OBJECTS_UTILS_TNAME','EXECUTE');
  add_list('DBMS_OBJECTS_APPS_UTILS','EXECUTE');  

-- zdt additions
  add_list('dbms_service','EXECUTE');
  add_list('dbms_prvtaqim','EXECUTE');
  add_list('dbms_aqadm_sys','EXECUTE');

-- Bug 12334833, 12-APR-2011, ASUTRALA
  add_list('DBA_DIRECTORIES','SELECT');
  add_list('DBA_SCHEDULER_JOBS','SELECT');
  add_list('DBA_SCHEDULER_JOB_LOG','SELECT');
  add_list('DBA_SCHEDULER_RUNNING_JOBS','SELECT');
  add_list('V_$LATCH','SELECT');
  add_list('V_$SQL_MONITOR','SELECT');
  add_list('V_$SQL_PLAN','SELECT');
  add_list('DBA_HIST_SQL_PLAN','SELECT');
  add_list('GV_$SQL_MONITOR','SELECT');
  add_list('GV_$SQL_PLAN_MONITOR','SELECT');
  add_list('GV_$SQL_PLAN','SELECT');
  add_list('GV_$ACTIVE_SESSION_HISTORY','SELECT');
  add_list('GV_$SESSION_LONGOPS','SELECT');
  add_list('GV_$SQL','SELECT');
  add_list('V_$SQL_PLAN_MONITOR','SELECT');
  add_list('V_$ACTIVE_SESSION_HISTORY','SELECT');
  add_list('V_$SESSION_LONGOPS','SELECT');
  add_list('V_$ASH_INFO','SELECT');
  add_list('V_$SQL_OPTIMIZER_ENV','SELECT');
  add_list('GV_$ASH_INFO','SELECT');
  add_list('GV_$SQL_OPTIMIZER_ENV','SELECT');
  add_list('DBA_PROCEDURES','SELECT');
  add_list('GV_$DATABASE','SELECT');
  add_list('V_$DATABASE','SELECT');
  add_list('GV_$INSTANCE','SELECT');
  add_list('V_$INSTANCE','SELECT');
  add_list('GV_$TIMER','SELECT');
  add_list('V_$TIMER','SELECT');
  add_list('GV_$SYS_OPTIMIZER_ENV','SELECT');
  add_list('V_$SYS_OPTIMIZER_ENV','SELECT');
  add_list('DBA_DATAPUMP_JOBS','SELECT');
  add_list('DBA_DATAPUMP_SESSIONS','SELECT');
  add_list('DBMS_DATAPUMP','EXECUTE');
  add_list('V_$VPD_POLICY','SELECT');
  add_list('V_$OBJECT_DEPENDENCY','SELECT');
 
  -- Bug 12588906, 25-May-2011 By ASUTRALA 
  add_list('DBA_TRIGGER_ORDERING', 'SELECT');
  add_list('DBA_UNUSED_COL_TABS', 'SELECT');
  -- End Bug 12588906

-- Bug 12751455, 18-Aug-2011, ASUTRALA
  add_list('DBMS_SQLDIAG', 'EXECUTE');
  add_list('DBMS_METADATA', 'EXECUTE');
--Bug 18670864
  add_list('DBMS_METADATA_UTIL', 'EXECUTE'); 
--end bug 18670864 
  add_list('DBA_HIST_SQLSTAT', 'SELECT'); 
  add_list('DBA_HIST_SQLTEXT', 'SELECT');
  add_list('V_$PX_PROCESS', 'SELECT');
  add_list('V_$PQ_TQSTAT', 'SELECT');
  
-- End Bug 12751455

-- bug 17810137 
  add_list('DBMS_WORKLOAD_REPOSITORY', 'EXECUTE');
-- End bug 17810137

-- bug 18356549
  add_list('DBA_USERS_WITH_DEFPWD', 'SELECT');
-- End bug 18356549

-- bug 19792670
  add_list('SNAP$', 'SELECT');
-- End bug 19792670

-- Bug 25417122 jwsmith. Removed the line to grant ALL priv to fnd_diag_dir
-- and replaced with READ and WRITE
  declare
    already_revoked EXCEPTION;
    PRAGMA
     EXCEPTION_INIT (already_revoked, -01927);
  Begin
    execute immediate 'revoke EXECUTE on directory fnd_diag_dir from ' || '&appsUserName';
  EXCEPTION
    WHEN already_revoked
    THEN
        null;
  end;

  add_list(X_sys_object => 'directory FND_DIAG_DIR', X_privilege => 'WRITE', x_grantee => '&appsUserName');
  add_list(X_sys_object => 'directory FND_DIAG_DIR', X_privilege => 'READ', x_grantee => '&appsUserName');

  add_list(X_sys_object => 'DBA_XML_SCHEMAS', X_privilege => 'SELECT', x_grantee => 'SYSTEM');
 
  -- Bug 10258533: XML schema migration 	
  add_list(X_sys_object => 'DBA_XML_SCHEMAS', X_privilege => 'SELECT', x_grantee => '&appsUserName');
  add_list(X_sys_object => 'XDB_MIGRATESCHEMA', X_privilege => 'EXECUTE', x_grantee => '&appsUserName');
  add_list(X_sys_object => 'XDB$MOVESCHEMATAB', X_privilege => 'SELECT', x_grantee => '&appsUserName');
  add_list(X_sys_object => 'XDB$MOVESCHEMATAB', X_privilege => 'INSERT', x_grantee => '&appsUserName');
  add_list(X_sys_object => 'XDB$MOVESCHEMATAB', X_privilege => 'UPDATE', x_grantee => '&appsUserName');
  add_list(X_sys_object => 'XDB$MOVESCHEMATAB', X_privilege => 'DELETE', x_grantee => '&appsUserName');
  add_list(X_sys_object => 'XDB$MOVESCHEMATAB', X_privilege => 'SELECT', x_grantee => 'SYSTEM');
  add_list(X_sys_object => 'XDB$MOVESCHEMATAB', X_privilege => 'INSERT', x_grantee => 'SYSTEM');
  add_list(X_sys_object => 'XDB$MOVESCHEMATAB', X_privilege => 'UPDATE', x_grantee => 'SYSTEM');
  add_list(X_sys_object => 'XDB$MOVESCHEMATAB', X_privilege => 'DELETE', x_grantee => 'SYSTEM');

  add_list(X_sys_object => 'DBMS_LOCK', X_privilege => 'EXECUTE', x_grantee => 'CTXSYS');
  add_list(X_sys_object => 'DBMS_PIPE', X_privilege => 'EXECUTE', x_grantee => 'CTXSYS');
  add_list(X_sys_object => 'DBMS_REGISTRY', X_privilege => 'EXECUTE', x_grantee => 'CTXSYS');

  -- Bug 22160447
  add_list(X_sys_object => 'DBMS_CRYPTO', X_privilege => 'EXECUTE', x_grantee => '&appsUserName');
  
  add_list(X_privilege => 'create any edition', x_grantee => '&appsUserName', x_grant_type => 1);
  add_list(X_privilege => 'drop any edition', x_grantee => '&appsUserName', x_grant_type => 1);
  add_list(X_privilege => 'alter database', x_grantee => '&appsUserName', x_grant_type => 1);
  add_list(X_privilege => 'create any type', x_grantee => '&appsUserName', x_grant_type => 1);
  add_list(X_privilege => 'alter any type', x_grantee => '&appsUserName', x_grant_type => 1);
  add_list(X_privilege => 'analyze any dictionary', x_grantee => '&appsUserName', x_grant_type => 1);
  add_list(X_privilege => 'execute any type', x_grantee => '&appsUserName', X_admin_option => true, x_grant_type => 1); 
  add_list(X_privilege => 'drop any synonym', x_grantee => '&appsUserName', x_grant_type => 1);
  add_list(X_privilege => 'create job', x_grantee => '&appsUserName', x_grant_type => 1);
  add_list(X_privilege => 'create external job', x_grantee => '&appsUserName', x_grant_type => 1);
  add_list(X_privilege => 'create public database link', x_grantee => '&appsUserName', x_grant_type => 1); 
  add_list(X_privilege => 'XDBADMIN', x_grantee => '&appsUserName', x_grant_type => 2);                
  add_list(X_privilege => 'SELECT_CATALOG_ROLE', x_grantee => '&appsUserName', x_grant_type => 2);
  add_list(X_privilege => 'ADMINISTER DATABASE TRIGGER', x_grantee => 'SYSTEM', x_grant_type => 1);
  add_list(X_privilege => 'ALTER USER', x_grantee => 'SYSTEM', x_grant_type => 1);
  
--- Bug 19674458 -  Grant use privileges on older editions if
--- not already done

  for ret_edn in C_RETIRED_EDITIONS loop
    add_list('EDITION '||ret_edn.EDITION_NAME,'USE','PUBLIC');
  end loop;

 exception
   when others then
      raise;
end load_table_list;

procedure give_privilege(x_schema_name varchar2, x_obj_name varchar2, x_grant_type varchar2)
is
  object_exists exception;
  object_not_exists exception;
  plsql_not_exists exception;

  pragma exception_init(object_exists, -955); 
  pragma exception_init(plsql_not_exists, -4042); 
  pragma exception_init(object_not_exists, -942); 
begin
  begin
    if(x_schema_name = 'SYSTEM' ) or (x_obj_name in ('DBA_USERS', 'GV_$SESSION'))
    then
        execute immediate 'grant ' || x_grant_type || ' on ' ||x_obj_name || ' to ' || x_schema_name || ' with grant option ' ;
    else
        execute immediate 'grant ' || x_grant_type || ' on ' ||x_obj_name || ' to ' || x_schema_name  ;
    end if;
  exception
    when object_exists then null;
    when object_not_exists then null;
    when plsql_not_exists then null;
    when others then
    raise_application_error(-20000, sqlerrm ||'Error in ad_grants.give_privilege');
  end;
  
--Verify  
  declare
  v_cnt number;
  v_sys_schema varchar2(5) := 'SYS';
  begin
    execute immediate 'SELECT count(1) from dba_Tab_privs where table_name=upper(:x_obj_name) and privilege=upper(:privilege) and grantee=upper(:grantee)' into v_cnt using x_obj_name, x_grant_type, x_schema_name;
    if (v_cnt = 0)
    then
	-- Check for object existence.
	   execute immediate 'SELECT count(1) from dba_objects where object_name=upper(:x_obj_name) and owner=upper(:v_sys_schema)' into v_cnt using x_obj_name, v_sys_schema;
	   if (v_cnt > 0)
	   then
	      add_list(X_sys_object => x_obj_name, X_privilege => x_grant_type, x_grantee => x_schema_name, x_add_to_missing=>true);
	   end if;
     end if;
  end;
end;

procedure give_role(x_schema_name varchar2, x_role_name varchar2, x_admin_option boolean default false, x_grant_type number default 1)
is
begin
  begin
   if (x_admin_option = false)
   then
     execute immediate 'grant ' || x_role_name ||' to '|| x_schema_name;     
   else
     execute immediate 'grant ' || x_role_name ||' to '|| x_schema_name || ' with admin option';     
   end if;
  exception
  when others then
    raise_application_error(-20000, sqlerrm ||'Error in ad_grants.give_role');
  end;
  
--Verify  
  declare
  v_cnt number;
  begin
    if (x_grant_type = 2)
	then
       execute immediate 'SELECT count(1) from DBA_ROLE_PRIVS where granted_role=upper(:role_name) and grantee=upper(:grantee)' into v_cnt using x_role_name, x_schema_name;
	   if (v_cnt = 0)
	   then
	      add_list(X_privilege => x_role_name, x_grantee => x_schema_name, x_add_to_missing=>true);
	   end if;
	elsif (x_grant_type = 1)
	then
	   execute immediate 'SELECT count(1) from DBA_SYS_PRIVS where privilege=upper(:role_name) and grantee=upper(:grantee)' into v_cnt using x_role_name, x_schema_name;
	   if (v_cnt = 0)
	   then
	      add_list(X_privilege => x_role_name, x_grantee => x_schema_name, x_add_to_missing => true);
	   end if;
	end if;
  end;  
end;

--
-- Procedure
--   give_grants.
--
-- Purpose
--   Grants necessary preveliges on sys objects by using the data stored in
--   the tables schema_list , object_list , grant_type_list and
--   with_grant_option_list
--
-- Arguments
--   none
-- Example
--   none
--

procedure give_grants
is
  i number;
  --Bug:3457610:sshivara.
  cursor schema_list is
       select '&appsUserName' ORACLE_USERNAME from dual
       union 
       select 'SYSTEM' ORACLE_USERNAME from  dual;
begin
  load_table_list;
 
 for ctr in privarray.FIRST .. privarray.LAST
 loop
  if (privarray(ctr).grant_type = 0)
  then
    if (privarray(ctr).grantee is null)
	then
      for c_schema in schema_list  
      loop
        give_privilege(c_schema.ORACLE_USERNAME, privarray(ctr).object_name, privarray(ctr).privilege);
      end loop;  --  End Schema loop
	else -- grantee is not null
	  give_privilege(privarray(ctr).grantee, privarray(ctr).object_name, privarray(ctr).privilege);
	end if;
  elsif (privarray(ctr).grant_type in (1, 2))
  then
     give_role(privarray(ctr).grantee, privarray(ctr).privilege, privarray(ctr).admin_option, privarray(ctr).grant_type);
  end if;
 end loop; -- End object_list loop
end give_grants;

--
-- Procedure
--   give_inherit_grants.
--
-- Purpose
--   Grants necessary inherit preveliges from User System to APPS.
--   This grant is only needed in 12C Database
--
-- Arguments
--   x_grantor_name ( For ex- 'SYSTEM'), x_grantee_name (For Ex-'APPS')
-- Example
--   none
--

procedure give_inherit_grants(x_grantor_name varchar2, x_grantee_name varchar2)
is
v_cnt number := 0;
v_privilege varchar2(30) := 'INHERIT PRIVILEGES';
Begin
  begin
   execute immediate 'grant inherit privileges on user ' || x_grantor_name ||' to '|| x_grantee_name;    
  exception
   when others then
   raise_application_error(-20000, sqlerrm ||'Error in ad_grants.give_inherit_grants');
  end;

--Verify
  begin
   select 1 into v_cnt from dual where exists (select 1 from DBA_TAB_PRIVS where grantor=upper(x_grantor_name) and grantee=upper(x_grantee_name) and privilege=v_privilege);  
   if (v_cnt = 0) then
      add_list(X_privilege => v_privilege, x_grantee => x_grantee_name, x_add_to_missing=>true); 
   end if;
  end;

end give_inherit_grants;

procedure display_missing_grants
is
  i number;
begin
 dbms_output.put_line('List of Missing grants or roles');
 for ctr in missing_privarray.FIRST .. missing_privarray.LAST
 loop
  if (missing_privarray(ctr).grant_type = 0)
  then
      dbms_output.put_line(missing_privarray(ctr).privilege||'  '||
                           missing_privarray(ctr).object_name||'  '||
                           missing_privarray(ctr).grantee);
  elsif (privarray(ctr).grant_type in (1, 2))
  then
      dbms_output.put_line(missing_privarray(ctr).privilege||'  '||
                           missing_privarray(ctr).grantee);
  end if;
 end loop; -- End Schema loop
end display_missing_grants;

--
-- For bug 3447980, create a view using the huge select tested by
-- APPS Performance team. This is one of the steps in replacing the
-- Rule optimization in ad_parallel_updates_pkg() package. 
-- 

procedure create_ad_extents
is

l_stmt varchar2(20000);

begin

l_stmt := 'create or replace view ad_extents as 
 SELECT      owner, 
            segment_name, 
            partition_name, 
            segment_type, 
            data_object_id, 
            relative_fno, block_id, blocks 
 from 
  (select 
  ds.owner, ds.segment_name, ds.partition_name, ds.segment_type, 
  e.block#  BLOCK_ID, 
  e.length  BLOCKS, e.file# RELATIVE_FNO, 
  ds.DATA_OBJECT_ID 
  from sys.uet$ e, 
 (    select 
      u.name OWNER, o.name SEGMENT_NAME, o.subname PARTITION_NAME, 
      so.object_type SEGMENT_TYPE, ts.ts# TABLESPACE_ID, s.block# 
 HEADER_BLOCK, s.file# RELATIVE_FNO, 
      NVL(s.spare1,0)  SEGMENT_FLAGS, 
        o.dataobj#  DATA_OBJECT_ID  
      from 
        sys.user$ u, 
        sys.obj$  o, 
        sys.ts$  ts, 
        sys.seg$  s, 
        sys.file$ f, 
        ( 
        select 
        ''TABLE'' OBJECT_TYPE, 
        2 OBJECT_TYPE_ID, 
        5 SEGMENT_TYPE_ID, 
        t.obj#  OBJECT_ID, 
        t.file# HEADER_FILE, 
        t.block# HEADER_BLOCK, 
        t.ts# TS_NUMBER 
        from sys.tab$ t 
        where bitand(t.property, 1024) = 0    
        and  bitand(t.property, 8192) <> 8192 
        ) so 
      where s.file# = so.header_file 
      and s.block# = so.header_block 
      and s.ts# = so.ts_number 
      and s.ts# = ts.ts# 
      and o.obj# = so.object_id 
      and o.owner# = u.user# 
      and s.type# = so.segment_type_id 
      and o.type# = so.object_type_id 
      and s.ts# = f.ts# 
      and s.file# = f.relfile# 
      UNION ALL 
      select /*+ USE_NL(U O SO) */ 
      u.name OWNER, o.name SEGMENT_NAME, o.subname PARTITION_NAME, 
      so.object_type SEGMENT_TYPE, ts.ts# TABLESPACE_ID, s.block# 
 HEADER_BLOCK, s.file# RELATIVE_FNO, 
      NVL(s.spare1,0)  SEGMENT_FLAGS, 
        o.dataobj#  DATA_OBJECT_ID  
      from 
        sys.user$ u, 
        sys.obj$  o, 
        sys.ts$  ts, 
        sys.seg$  s, 
        sys.file$ f, 
        ( 
        select /*+ INDEX(TP) */ 
        ''TABLE PARTITION'' OBJECT_TYPE, 
        19 OBJECT_TYPE_ID, 
        5 SEGMENT_TYPE_ID, 
        tp.obj# OBJECT_ID, 
        tp.file# HEADER_FILE, 
        tp.block# HEADER_BLOCK, 
        tp.ts# TS_NUMBER 
        from sys.tabpart$ tp 
        ) so 
      where s.file# = so.header_file 
      and s.block# = so.header_block 
      and s.ts# = so.ts_number 
      and s.ts# = ts.ts# 
      and o.obj# = so.object_id 
      and o.owner# = u.user# 
      and s.type# = so.segment_type_id 
      and o.type# = so.object_type_id 
      and s.ts# = f.ts# 
      and s.file# = f.relfile# 
      UNION ALL 
      select 
      u.name OWNER, o.name SEGMENT_NAME, o.subname PARTITION_NAME, 
      so.object_type SEGMENT_TYPE, ts.ts# TABLESPACE_ID, s.block# 
 HEADER_BLOCK, s.file# RELATIVE_FNO, 
      NVL(s.spare1,0)  SEGMENT_FLAGS, 
        o.dataobj#  DATA_OBJECT_ID  
      from 
        sys.user$ u, 
        sys.obj$  o, 
        sys.ts$  ts, 
        sys.seg$  s, 
        sys.file$ f, 
        ( 
        select /*+ INDEX(TSP) */ 
        ''TABLE SUBPARTITION'' OBJECT_TYPE, 
        34 OBJECT_TYPE_ID, 
        5 SEGMENT_TYPE_ID, 
        tsp.obj# OBJECT_ID, 
        tsp.file# HEADER_FILE, 
        tsp.block# HEADER_BLOCK, 
        tsp.ts# TS_NUMBER 
        from sys.tabsubpart$ tsp  
        ) so 
      where s.file# = so.header_file 
      and s.block# = so.header_block 
      and s.ts# = so.ts_number 
      and s.ts# = ts.ts# 
      and o.obj# = so.object_id 
      and o.owner# = u.user# 
      and s.type# = so.segment_type_id 
      and o.type# = so.object_type_id 
      and s.ts# = f.ts# 
      and s.file# = f.relfile# 
      ) ds, sys.file$ f 
  where e.segfile# = ds.relative_fno 
  and e.segblock# = ds.header_block 
  and e.ts# = ds.tablespace_id 
  and e.ts# = f.ts# 
  and e.file# = f.relfile# 
  and bitand(NVL(ds.segment_flags,0), 1) = 0 
  union all 
  select /*+ ordered use_nl(e) use_nl(f) */ 
  ds.owner, ds.segment_name, ds.partition_name, ds.segment_type, 
  e.ktfbuebno BLOCK_ID, 
  e.ktfbueblks BLOCKS, e.ktfbuefno RELATIVE_FNO, 
  ds.DATA_OBJECT_ID 
  from ( 
      select 
      u.name OWNER, o.name SEGMENT_NAME, o.subname PARTITION_NAME, 
      so.object_type SEGMENT_TYPE, ts.ts# TABLESPACE_ID, s.block# 
 HEADER_BLOCK, s.file# RELATIVE_FNO, 
      NVL(s.spare1,0)  SEGMENT_FLAGS, 
        o.dataobj#  DATA_OBJECT_ID  
      from 
        sys.user$ u, 
        sys.obj$  o, 
        sys.ts$  ts, 
        sys.seg$  s, 
        sys.file$ f, 
        ( 
        select 
        ''TABLE'' OBJECT_TYPE, 
        2 OBJECT_TYPE_ID, 
        5 SEGMENT_TYPE_ID, 
        t.obj#  OBJECT_ID, 
        t.file# HEADER_FILE, 
        t.block# HEADER_BLOCK, 
        t.ts# TS_NUMBER 
        from sys.tab$ t 
        where bitand(t.property, 1024) = 0
        and  bitand(t.property, 8192) <> 8192 
        ) so 
      where s.file# = so.header_file 
      and s.block# = so.header_block 
      and s.ts# = so.ts_number 
      and s.ts# = ts.ts# 
      and o.obj# = so.object_id 
      and o.owner# = u.user# 
      and s.type# = so.segment_type_id 
      and o.type# = so.object_type_id 
      and s.ts# = f.ts# 
      and s.file# = f.relfile# 
      UNION ALL 
      select /*+ USE_NL(U O SO) */ 
      u.name OWNER, o.name SEGMENT_NAME, o.subname PARTITION_NAME, 
      so.object_type SEGMENT_TYPE, ts.ts# TABLESPACE_ID, s.block# 
 HEADER_BLOCK, s.file# RELATIVE_FNO, 
      NVL(s.spare1,0)  SEGMENT_FLAGS, 
        o.dataobj#  DATA_OBJECT_ID  
      from 
        sys.user$ u, 
        sys.obj$  o, 
        sys.ts$  ts, 
        sys.seg$  s, 
        sys.file$ f, 
        ( 
        select /*+ INDEX(TP) */ 
        ''TABLE PARTITION'' OBJECT_TYPE, 
        19 OBJECT_TYPE_ID, 
        5 SEGMENT_TYPE_ID, 
        tp.obj# OBJECT_ID, 
        tp.file# HEADER_FILE, 
        tp.block# HEADER_BLOCK, 
        tp.ts# TS_NUMBER 
        from sys.tabpart$ tp 
        ) so 
      where s.file# = so.header_file 
      and s.block# = so.header_block 
      and s.ts# = so.ts_number 
      and s.ts# = ts.ts# 
      and o.obj# = so.object_id 
      and o.owner# = u.user# 
      and s.type# = so.segment_type_id 
      and o.type# = so.object_type_id 
      and s.ts# = f.ts# 
      and s.file# = f.relfile# 
      UNION ALL 
      select 
      u.name OWNER, o.name SEGMENT_NAME, o.subname PARTITION_NAME, 
      so.object_type SEGMENT_TYPE, ts.ts# TABLESPACE_ID, s.block# 
 HEADER_BLOCK, s.file# RELATIVE_FNO, 
      NVL(s.spare1,0)  SEGMENT_FLAGS, 
        o.dataobj#  DATA_OBJECT_ID  
      from 
        sys.user$ u, 
        sys.obj$  o, 
        sys.ts$  ts, 
        sys.seg$  s, 
        sys.file$ f, 
        ( 
        select /*+ INDEX(TSP) */ 
        ''TABLE SUBPARTITION'' OBJECT_TYPE, 
        34 OBJECT_TYPE_ID, 
        5 SEGMENT_TYPE_ID, 
        tsp.obj# OBJECT_ID, 
        tsp.file# HEADER_FILE, 
        tsp.block# HEADER_BLOCK, 
        tsp.ts# TS_NUMBER 
        from sys.tabsubpart$ tsp  
        ) so 
      where s.file# = so.header_file 
     and s.block# = so.header_block 
      and s.ts# = so.ts_number 
      and s.ts# = ts.ts# 
      and o.obj# = so.object_id 
      and o.owner# = u.user# 
      and s.type# = so.segment_type_id 
      and o.type# = so.object_type_id 
      and s.ts# = f.ts# 
      and s.file# = f.relfile# 
      ) ds, 
    sys.x$ktfbue e, 
    sys.file$ f 
  where e.ktfbuesegfno = ds.relative_fno 
  and e.ktfbuesegbno = ds.header_block 
  and e.ktfbuesegtsn = ds.tablespace_id 
  and e.ktfbuesegtsn = f.ts# 
  and e.ktfbuefno = f.relfile# 
  and bitand(NVL(ds.segment_flags, 0), 1) = 1 )'; 

execute immediate l_stmt;

exception
    when others then
        raise_application_error(-20000, sqlerrm ||':  ' ||
                                'Error in creating view');

end create_ad_extents;

BEGIN
  begin
    create_ad_extents;
    commit;
    exception
     when others then
     raise;
  end;

  begin
    -- Check if Directory FND_DIAG_DIR is present or not.
    select 'Y' into vexists from dba_directories where directory_name = vdir;
    exception
      when no_data_found then
      -- Create directory
      vpath := get_udump_dir;
      vstmt := 'CREATE OR REPLACE DIRECTORY ' || vdir || ' as ''' || vpath || '''';
       
      execute immediate vstmt;
  end;

  begin
    give_grants;
    $IF NOT DBMS_DB_VERSION.VER_LE_11 $THEN
      give_inherit_grants(x_grantor_name => 'SYSTEM',x_grantee_name => '&appsUserName'); 
      give_inherit_grants(x_grantor_name => 'SYS',x_grantee_name => '&appsUserName'); 
    $END
    commit;
    if (missing_privarray.COUNT > 0)
	then
	  display_missing_grants;
	end if;
    exception
     when others then
     raise;
  end;
-- Adding the below block for fixing bug13003582.  
-- (Temporary Fix needs to be removed after ST fix)
  begin
    update mlog$ set flag=flag-32
      where (mod(flag,32)>=16 and mod(flag,64)>=32);
    commit;
  end;
-- start setting roles as default role  
-- Bug25303697 Should not execute this grant to PUBLIC
  begin
    execute immediate 'select listagg(GRANTED_ROLE,'','') within group'    ||
                      ' (order by GRANTED_ROLE) from dba_role_privs where' ||
                      ' grantee = ''' || upper('&&appsUserName') || ''''   ||
                      ' and granted_role<>''PUBLIC'' and '                 ||
                      ' (default_role=''YES'' or granted_role in ('    ||
                       role_list || '))' into db_role_list ;
    execute immediate 'alter user ' || upper('&&appsUserName') || ' default role ' || db_role_list;
  end;

END;
/

prompt
prompt Start of PURGE DBA_RECYCLEBIN.
prompt

BEGIN
   execute immediate 'PURGE DBA_RECYCLEBIN';
   exception
     when others then
     raise;  
END;
/

prompt
prompt End of PURGE DBA_RECYCLEBIN.
prompt

--
-- commenting out the code snippet below
-- until the solution is finalized.
--
-- begin 
--    execute immediate 'revoke all on sys.dual from public';
--    execute immediate 'grant select on sys.dual to public';
-- exception 
--    when others then
--       raise;
-- end; 
-- /
COMMIT
/
EXIT;


