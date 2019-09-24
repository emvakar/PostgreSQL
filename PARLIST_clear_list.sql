create or replace function func_clearList(p_listid bigint, p_ownerid bigint, p_ispurchased boolean default null::bool)
    returns TABLE
            (
                id          bigint,
                title       text,
                "ownerId"   bigint,
                items       jsonb[],
                members     jsonb[],
                "createdAt" timestamp without time zone,
                "updatedAt" timestamp without time zone
            )
    language plpgsql
as
$$
BEGIN

    DELETE
    FROM "Entry" AS e
    WHERE e."listId" = p_listid
      AND e."isPurchased" = p_ispurchased;

    RETURN query
        SELECT "l"."id",
               "l"."title",
               "l"."ownerId",
               (SELECT COALESCE(array_agg(to_jsonb("_entry_")) FILTER (WHERE to_jsonb("_entry_") IS NOT NULL),
                                '{}'::jsonb[])
                FROM "Entry" as "_entry_"
                WHERE "_entry_"."listId" = "l"."id") as "items",

               (SELECT COALESCE(array_agg(to_jsonb("_u_")) FILTER (WHERE to_jsonb("_u_") IS NOT NULL), '{}'::jsonb[])
                FROM "List"
                         LEFT OUTER JOIN "User" as "_u_"
                                         ON "l"."members" @> ARRAY ["_u_"."id"]::bigint[]
                WHERE "List".id = "l".id)            as "members",

               "l"."createdAt",
               "l"."updatedAt"
        FROM "List" as "l"
        WHERE
              ("l"."members" @> ARRAY [p_ownerid]::bigint[]
                   OR "l"."ownerId" = p_ownerid)
          AND ("l".id = p_listid)
        GROUP BY "l"."id"
        ORDER BY "l"."createdAt" ASC
    limit 1;
end;
$$;