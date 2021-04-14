-- This is a lame attempt to write a thin wrapper over
-- pgTAP https://github.com/theory/pgtap functions so
-- that I can write a test that answers the following
-- question: Do any of the statements in array A have
-- results that match any of the statements in array B.
-- The reason I want such a thing is for grading homework.
-- Often times I need to accept multiple correct solutions.

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.boolean_results_eq (refcursor, refcursor)
    RETURNS boolean
    AS $$
DECLARE
    have ALIAS FOR $1;
    want ALIAS FOR $2;
    have_rec RECORD;
    want_rec RECORD;
    have_found boolean;
    want_found boolean;
    rownum integer := 1;
BEGIN
    FETCH have INTO have_rec;
    have_found := FOUND;
    FETCH want INTO want_rec;
    want_found := FOUND;
    WHILE have_found
        OR want_found LOOP
            IF have_rec IS DISTINCT FROM want_rec OR have_found <> want_found THEN
                RETURN FALSE;
            END IF;
            rownum = rownum + 1;
            FETCH have INTO have_rec;
            have_found := FOUND;
            FETCH want INTO want_rec;
            want_found := FOUND;
        END LOOP;
    RETURN TRUE;
    EXCEPTION
        WHEN datatype_mismatch THEN
            RETURN FALSE;
        WHEN others THEN
            RETURN FALSE;
    END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pg_temp.boolean_results_eq (text, text)
    RETURNS boolean
    AS $$
DECLARE
    have REFCURSOR;
    want REFCURSOR;
    res text;
BEGIN
    OPEN have FOR EXECUTE _query ($1);
    OPEN want FOR EXECUTE _query ($2);
    res := pg_temp.boolean_results_eq (have, want);
    CLOSE have;
    CLOSE want;
    RETURN res;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pg_temp.any_results_eq (text[], text[], text)
    RETURNS text
    AS $$
    SELECT
        ok (bool_or(pg_temp.boolean_results_eq(query_a, query_b)), $3)
    FROM
        unnest($1) query_a
    CROSS JOIN unnest($2) query_b;
$$
LANGUAGE sql;


-- Clone of _docomp from pgtap, but returns boolean instead of text
CREATE OR REPLACE FUNCTION pg_temp.boolean_docomp( TEXT, TEXT )
RETURNS BOOLEAN AS $$
DECLARE
    have    ALIAS FOR $1;
    want    ALIAS FOR $2;
    extras  TEXT[]  := '{}';
    missing TEXT[]  := '{}';
    res     BOOLEAN := TRUE;
    msg     TEXT    := '';
    rec     RECORD;
BEGIN
    BEGIN
        -- Find extra records.
        FOR rec in EXECUTE 'SELECT * FROM ' || have || ' EXCEPT ' 
                        || 'SELECT * FROM ' || want LOOP
            extras := extras || rec::text;
        END LOOP;

        -- Find missing records.
        FOR rec in EXECUTE 'SELECT * FROM ' || want || ' EXCEPT ' 
                        || 'SELECT * FROM ' || have LOOP
            missing := missing || rec::text;
        END LOOP;

        -- Drop the temporary tables.
        EXECUTE 'DROP TABLE ' || have;
        EXECUTE 'DROP TABLE ' || want;
    EXCEPTION WHEN syntax_error OR datatype_mismatch THEN
        msg := E'\n' || diag(
            E'    Columns differ between queries:\n'
            || '        have: (' || _temptypes(have) || E')\n'
            || '        want: (' || _temptypes(want) || ')'
        );
        EXECUTE 'DROP TABLE ' || have;
        EXECUTE 'DROP TABLE ' || want;
        RETURN FALSE;
    END;

    -- What extra records do we have?
    IF extras[1] IS NOT NULL THEN
        res := FALSE;
        msg := E'\n' || diag(
            E'    Extra records:\n        '
            ||  array_to_string( extras, E'\n        ' )
        );
    END IF;

    -- What missing records do we have?
    IF missing[1] IS NOT NULL THEN
        res := FALSE;
        msg := msg || E'\n' || diag(
            E'    Missing records:\n        '
            ||  array_to_string( missing, E'\n        ' )
        );
    END IF;

    RETURN res;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pg_temp.boolean_relcomp( TEXT, TEXT )
RETURNS BOOLEAN AS $$
    SELECT pg_temp.boolean_docomp(
        _temptable( $1, '__taphave__' ),
        _temptable( $2, '__tapwant__' )
    );
$$ LANGUAGE sql;

-- set_eq( sql, sql, description )
CREATE OR REPLACE FUNCTION pg_temp.boolean_set_eq( TEXT, TEXT )
RETURNS BOOLEAN AS $$
    SELECT pg_temp.boolean_relcomp( $1, $2 );
$$ LANGUAGE sql;


CREATE OR REPLACE FUNCTION pg_temp.any_set_eq (text[], text[], text)
    RETURNS text
    AS $$
    SELECT
        ok (bool_or(pg_temp.boolean_set_eq(query_a, query_b)), $3)
    FROM
        unnest($1) query_a
    CROSS JOIN unnest($2) query_b;
$$
LANGUAGE sql;

SET search_path = pgtap;

SELECT pgtap.plan (6);

SELECT pg_temp.any_results_eq(
    array[
        'select true',
        'select true'
    ],
    array[
        'select false',
        'select false',
        'select false'
    ],
    'None of these match...this test will fail, but that is a good thing'
);

SELECT pg_temp.any_results_eq (
    array[
        'select 3',
        'select 4'
    ],
    array[
        'select 1',
        'select 3',
        $$select 'example string'$$
    ],
    'This should pass!'
);

SELECT pg_temp.any_results_eq (
    array[
        'select * from (values (1), (2), (3)) v(a)',
        'select 4'
    ],
    array[
        'select 3',
        'select * from (values (1), (2), (3)) v(a)',
        $$select 'example string'$$
    ],
    'This should pass!'
);

SELECT pg_temp.any_set_eq (
    array[
        'select * from (values (1), (2), (3)) v(a)',
        'select 4'
    ],
    array[
        'select 3',
        'select * from (values (1), (2), (3)) v(a)',
        $$select 'example string'$$
    ],
    'This should pass!'
);

SELECT pg_temp.any_set_eq (
    array[
        'select * from (values (1), (2), (3)) v(a)',
        'select 4'
    ],
    array[
        'select 3',
        'select * from (values (1), (2), (3)) v(a)',
        $$select 'example string'$$
    ],
    'This should pass!'
);

SELECT pg_temp.any_set_eq (
    array[
        'select * from (values (2), (1), (3)) v(a)',
        'select 4'
    ],
    array[
        'select 3',
        'select * from (values (1), (2), (3)) v(a)',
        $$select 'example string'$$
    ],
    'This should pass!'
);

SELECT
    *
FROM
    finish ();
ROLLBACK;

