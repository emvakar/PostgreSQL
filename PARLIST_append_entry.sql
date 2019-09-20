select * from func_append_item('c5da1624-911f-4337-bd6b-8867f67a2317',48,2);

create function public.func_append_item(p_itemid uuid, p_listid bigint, p_ownerid bigint)
    returns TABLE(id bigint, title text, "ownerId" bigint, items jsonb[], members jsonb[], "createdAt" timestamp without time zone, "updatedAt" timestamp without time zone)
    language plpgsql
as
$$

DECLARE
	i_id uuid;
	i_title text;
	i_currencyId bigint;
	i_calories bigint;
	i_price bigint;
	i_isBase boolean;
	i_createdAt timestamp without time zone;
	i_updatedAt timestamp without time zone;
	i_categorytitle text;
	i_categoryid uuid;
	i_categoryColor1 text;
	i_categoryColor2 text;
	i_categorysort bigint;

begin

DROP TABLE IF EXISTS temp_categoryentry;
CREATE TEMPORARY TABLE temp_categoryentry(
	id uuid,
	title text,
	"colorId" bigint,
	sort bigint,
	"isBase" boolean,
	"ownerId" bigint,
	"canChange" boolean,
	"baseCategoryId" uuid,
	"createdAt" timestamp without time zone,
	"updatedAt" timestamp without time zone);

insert into temp_categoryentry (id, title, "colorId", sort, "isBase", "ownerId", "canChange", "baseCategoryId", "createdAt", "updatedAt")
SELECT

	CASE WHEN b.id is null then c."id" ELSE CASE WHEN c."baseCategoryId" IS NULL THEN b.id ELSE c.id END END AS id,
	CASE WHEN b.id is null then c.title ELSE CASE WHEN c."baseCategoryId" IS NULL THEN b.title ELSE c.title END END AS title,
	CASE WHEN b.id is null then c."colorId" ELSE CASE WHEN c."baseCategoryId" IS NULL THEN b."colorId" ELSE c."colorId" END END AS "colorId",
	CASE WHEN b.id is null then c.sort ELSE CASE WHEN c."baseCategoryId" IS NULL THEN b.sort ELSE c.sort END END AS sort,
	CASE WHEN b.id is null then c."isBase" ELSE CASE WHEN c."baseCategoryId" IS NULL THEN TRUE ELSE FALSE END END AS "isBase",
	CASE WHEN b."ownerId" is null then p_ownerid ELSE c."ownerId" END AS "ownerId",
	CASE WHEN b.id is null then c."canChange" ELSE CASE WHEN c."baseCategoryId" IS NULL THEN NULL ELSE c."canChange" END END AS "canChange",
	CASE WHEN b.id is null then c."baseCategoryId" ELSE CASE WHEN c."baseCategoryId" IS NULL THEN null ELSE c."baseCategoryId" END END AS "baseCategoryId",
    CASE WHEN b.id is null then c."createdAt" ELSE CASE WHEN c."baseCategoryId" IS NULL THEN b."createdAt" ELSE c."createdAt" END END AS "createdAt",
    CASE WHEN b.id is null then c."updatedAt" ELSE CASE WHEN c."baseCategoryId" IS NULL THEN b."updatedAt" ELSE c."updatedAt" END END AS "updatedAt"

FROM "BaseCategory" as b
	FULL JOIN "Category" as c
	ON b.id = c."baseCategoryId"
	AND c."ownerId" = p_ownerid
where c."ownerId" = p_ownerid or c."ownerId" is null;

SELECT p.id,
       p."title",
       (SELECT "_category_"."title" as "categorytitle"),
       (SELECT "_category_"."id" as "categoryid"),
       (SELECT col."startHex" as "categorycolor1"),
       (SELECT col."endHex" as "categorycolor2"),
       (SELECT "_category_"."sort" as "categorysort"),
       p."currencyId",
       p."calories",
       p."price",
       p."isBase",
       p."createdAt",
       p."updatedAt"
FROM (
    select tempi.id,
       tempi."userItemId",
       tempi.title,
       tempi."categoryId",
       tempi."userId",
       tempi."currencyId",
       tempi.calories,
       tempi.price,
       tempi."isBase",
       tempi."createdAt",
       tempi."updatedAt"
FROM public.func_get_product_inner(p_ownerid, p_itemid) as tempi
         ) as "p"
         LEFT OUTER JOIN temp_categoryentry as "_category_" ON p."categoryId" = "_category_"."id"
         LEFT OUTER JOIN "public"."Color" as col on "_category_"."colorId" = col."id"
WHERE
	p.id = p_itemid AND p."userId" = p_ownerid
LIMIT 1
INTO
	i_id,
	i_title,
	i_categorytitle,
	i_categoryid,
	i_categoryColor1,
	i_categoryColor2,
	i_categorysort,
	i_currencyId,
	i_calories,
	i_price,
	i_isBase,
	i_createdAt,
	i_updatedAt;

INSERT INTO public."Entry"(
	"id",
	"ownerId",
	"title",
	"listId",
	"calories",
	"categoryName",
	"categoryColor1",
	"categoryColor2",
	"isImportant",
	"isPurchased",
	"categoryId",
	"price",
	"categorySort",
	"currencyId",
	"createdAt",
	"updatedAt"
)
VALUES (
	uuid_generate_v4(),
	p_ownerid,
	i_title,
	p_listid,
	i_calories,
	i_categorytitle,
	i_categoryColor1,
	i_categoryColor2,
	false,
	false,
	i_categoryid,
	i_price,
	i_categorysort,
	i_currencyid,
	clock_timestamp(),
	clock_timestamp()
);

RETURN query
SELECT
            "l"."id",
            "l"."title",
            "l"."ownerId",
            (SELECT COALESCE(array_agg(to_jsonb("_entry_")) FILTER (WHERE to_jsonb("_entry_") IS NOT NULL), '{}'::jsonb[])
            FROM "Entry" as "_entry_" WHERE "_entry_"."listId" = "l"."id") as "items",

            (SELECT COALESCE(array_agg(to_jsonb("_u_")) FILTER (WHERE to_jsonb("_u_") IS NOT NULL), '{}'::jsonb[])
            FROM "List"
            LEFT OUTER JOIN "User" as "_u_"
            ON "l"."members" @> ARRAY["_u_"."id"]::bigint[] WHERE "List".id = "l".id) as "members",

            "l"."createdAt",
            "l"."updatedAt"
            FROM "List" as "l"
            WHERE ("l"."members" @> ARRAY[p_ownerid]::bigint[] OR "l"."ownerId" = p_ownerid)
            AND ("l".id = p_listid)
            GROUP BY "l"."id"
            ORDER BY "l"."createdAt" ASC;
            END;
$$;

