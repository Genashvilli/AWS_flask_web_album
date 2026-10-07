import json
import logging
import os
import posixpath
import time
from io import BytesIO
from urllib.parse import unquote_plus

import boto3
import mysql.connector
from PIL import Image, ImageOps, UnidentifiedImageError


logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")

SUPPORTED_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp")


def should_skip_key(key):
    key_lower = key.lower()

    if ".small." in key_lower:
        return True

    if not key_lower.startswith(os.environ["ORIGINAL_PREFIX"].lower()):
        return True

    if not key_lower.endswith(SUPPORTED_EXTENSIONS):
        return True

    return False


def build_thumbnail_key(original_key):
    basename = posixpath.basename(original_key)
    name, ext = posixpath.splitext(basename)

    return f"{os.environ['THUMBNAIL_PREFIX']}{name}.small{ext.lower()}"


def output_format_for_key(key):
    key_lower = key.lower()

    if key_lower.endswith((".jpg", ".jpeg")):
        return "JPEG", "image/jpeg"

    if key_lower.endswith(".png"):
        return "PNG", "image/png"

    if key_lower.endswith(".webp"):
        return "WEBP", "image/webp"

    raise ValueError(f"Nicht unterstütztes Bildformat: {key}")


def create_thumbnail(bucket, original_key, thumbnail_key):
    response = s3.get_object(
        Bucket=bucket,
        Key=original_key,
    )

    original_bytes = response["Body"].read()
    thumbnail_size = int(os.environ.get("THUMBNAIL_MAX_SIZE", "100"))

    with Image.open(BytesIO(original_bytes)) as image:
        image = ImageOps.exif_transpose(image)

        image.thumbnail(
            (thumbnail_size, thumbnail_size),
            Image.Resampling.LANCZOS,
        )

        image_format, content_type = output_format_for_key(original_key)

        if image_format == "JPEG" and image.mode not in ("RGB", "L"):
            image = image.convert("RGB")

        output = BytesIO()

        save_args = {
            "format": image_format,
        }

        if image_format == "JPEG":
            save_args["quality"] = 85
            save_args["optimize"] = True

        image.save(output, **save_args)
        output.seek(0)

    s3.put_object(
        Bucket=bucket,
        Key=thumbnail_key,
        Body=output.getvalue(),
        ContentType=content_type,
    )


def update_database(original_key, thumbnail_key):
    connection = mysql.connector.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ["DB_PORT"]),
        database=os.environ["DB_NAME"],
        user=os.environ["DB_USERNAME"],
        password=os.environ["DB_PASSWORD"],
        connection_timeout=5,
    )

    try:
        cursor = connection.cursor()
        cursor.execute(
            """
            UPDATE photos
            SET thumbnail_filename = %s
            WHERE photo_filename = %s
            """,
            (thumbnail_key, original_key),
        )
        connection.commit()

        return cursor.rowcount

    finally:
        connection.close()


def update_database_with_retry(original_key, thumbnail_key):
    for attempt in range(1, 11):
        updated_rows = update_database(original_key, thumbnail_key)

        if updated_rows > 0:
            logger.info(
                "thumbnail_filename gesetzt: %s -> %s",
                original_key,
                thumbnail_key,
            )
            return

        logger.info(
            "DB-Zeile noch nicht vorhanden, Versuch %s/10: %s",
            attempt,
            original_key,
        )
        time.sleep(1)

    logger.warning("Kein DB-Eintrag für Original gefunden: %s", original_key)


def handle_record(record):
    bucket = record["s3"]["bucket"]["name"]
    original_key = unquote_plus(record["s3"]["object"]["key"])

    if should_skip_key(original_key):
        logger.info("Überspringe Objekt: %s", original_key)
        return

    thumbnail_key = build_thumbnail_key(original_key)

    try:
        create_thumbnail(bucket, original_key, thumbnail_key)
        update_database_with_retry(original_key, thumbnail_key)

    except UnidentifiedImageError:
        logger.warning("Datei ist kein lesbares Bild: %s", original_key)


def lambda_handler(event, context):
    for record in event.get("Records", []):
        handle_record(record)

    return {
        "statusCode": 200,
        "body": json.dumps({"ok": True}),
    }