import uuid
import datetime

profiles = [
    "92a0ce98-f0bc-492b-bfd4-8a644cab9b7f",
    "0fd2e969-6c0f-49a5-ad0f-878e27376a2f",
    "32295c5a-a838-40b7-92b2-7d2102d7d044",
    "da0d75a9-08c7-49f8-9b72-7dda5f96e625",
    "2f31f6ea-9297-4fc0-ae7a-26ed417b8cfc",
    "71343a12-fa99-4f3a-a57c-378d0940ccf5"
]

dates = [
    "2026-08-11T00:00:00Z",
    "2026-08-12T00:00:00Z",
    "2026-08-13T00:00:00Z",
    "2026-08-14T00:00:00Z",
    "2026-08-15T00:00:00Z"
]

activity_types = [
    ("steps", 8000),
    ("calories", 400),
    ("distance", 5000)
]

vitals = [
    ("heartRate", 60, 75, 120),
    ("hrv", 30, 45, 60)
]

sql_statements = []

for profile in profiles:
    for d in dates:
        for a_type, val in activity_types:
            id_val = str(uuid.uuid4())
            sql = f'INSERT INTO "Health_ActivityDaily" ("id", "profileId", "type", "value", "date", "createdAt", "lastUpdatedAt", "isSynced") VALUES (\'{id_val}\', \'{profile}\', \'{a_type}\', {val}, \'{d}\', \'{d}\', \'{d}\', 1);'
            sql_statements.append(sql)
            
        for v_type, min_v, avg_v, max_v in vitals:
            id_val = str(uuid.uuid4())
            sql = f'INSERT INTO "Health_VitalsDaily" ("id", "profileId", "type", "date", "minValue", "avgValue", "maxValue", "createdAt", "lastUpdatedAt", "isSynced") VALUES (\'{id_val}\', \'{profile}\', \'{v_type}\', \'{d}\', {min_v}, {avg_v}, {max_v}, \'{d}\', \'{d}\', 1);'
            sql_statements.append(sql)
            
        # Sleep
        id_val = str(uuid.uuid4())
        sql = f'INSERT INTO "Health_SleepDaily" ("id", "profileId", "date", "totalSleep", "deepSleep", "remSleep", "lightSleep", "sleepStart", "sleepEnd", "createdAt", "lastUpdatedAt", "isSynced") VALUES (\'{id_val}\', \'{profile}\', \'{d}\', 8.0, 2.0, 2.0, 4.0, \'{d}\', \'{d}\', \'{d}\', \'{d}\', 1);'
        sql_statements.append(sql)

with open("mock_insert.sql", "w") as f:
    f.write("\n".join(sql_statements))

