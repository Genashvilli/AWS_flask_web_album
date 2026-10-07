import os
from mimetypes import guess_extension
from uuid import uuid4
from urllib.parse import quote_plus
import json

import boto3
from botocore.exceptions import ClientError
from dotenv import load_dotenv
from flask import Flask, render_template, request, redirect, url_for, Response, abort
from sqlalchemy import (
    create_engine,
    MetaData,
    Table,
    Column,
    Integer,
    String,
    select,
    delete,
    insert,
)

load_dotenv()

S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME")
AWS_REGION = os.getenv("AWS_REGION")

SECRET_ID = os.getenv("SECRET_ID")

DB_PRIMARY_ENDPOINT = os.getenv("DB_PRIMARY_HOST")
DB_REPLICA_ENDPOINT = os.getenv("DB_REPLICA_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_SSL_CA = os.getenv("DB_SSL_CA")


def require_env(name, value):
    if not value:
        raise RuntimeError(f"{name} fehlt in der .env")


require_env("S3_BUCKET_NAME", S3_BUCKET_NAME)
require_env("AWS_REGION", AWS_REGION)
require_env("SECRET_ID", SECRET_ID)
require_env("DB_PRIMARY_HOST", DB_PRIMARY_ENDPOINT)
require_env("DB_REPLICA_HOST", DB_REPLICA_ENDPOINT)
require_env("DB_PORT", DB_PORT)
require_env("DB_NAME", DB_NAME)
require_env("DB_SSL_CA", DB_SSL_CA)

s3 = boto3.client("s3", region_name=AWS_REGION)

app = Flask(__name__)

def get_secret(secret_id):
    client = boto3.client("secretsmanager", region_name=AWS_REGION)

    try:
        response = client.get_secret_value(SecretId=secret_id)
    except ClientError as e:
        raise RuntimeError("DB-Secret konnte nicht geladen werden") from e

    return json.loads(response["SecretString"])


secret = get_secret(SECRET_ID)
DB_USER = secret.get("username")
DB_PASSWORD = secret.get("password")

if not isinstance(DB_USER, str) or not DB_USER:
    raise RuntimeError("DB-Secret enthält keinen gültigen String für 'username'")

if not isinstance(DB_PASSWORD, str) or not DB_PASSWORD:
    raise RuntimeError("DB-Secret enthält keinen gültigen String für 'password'")

def db_connect(host):
    db_url = (
        f"mariadb+mariadbconnector://{DB_USER}:"
        f"{quote_plus(DB_PASSWORD)}@{host}:{DB_PORT}/{DB_NAME}"
    )

    return create_engine(
        db_url,
        connect_args={
            "ssl_ca": DB_SSL_CA,
            "ssl_verify_cert": True,
        },
        pool_pre_ping=True,
    )


primary_engine = db_connect(DB_PRIMARY_ENDPOINT)
replica_engine = db_connect(DB_REPLICA_ENDPOINT)


def get_db_connect(operation):
    if operation == "read":
        return replica_engine.connect()

    if operation == "write":
        return primary_engine.connect()

    raise ValueError("Operation must be either 'read' or 'write'.")


meta = MetaData()

photos = Table(
    "photos",
    meta,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("title", String(50)),
    Column("photo_filename", String(255)),
    Column("thumbnail_filename", String(255)),
)

meta.create_all(primary_engine)


def build_photo_url(object_key):
    if not object_key:
        return None

    return url_for("serve_photo", object_key=object_key)


def generate_s3_key(file_storage):
    ext = (
        guess_extension(file_storage.mimetype or "")
        or os.path.splitext(file_storage.filename)[1]
        or ".bin"
    )

    ext = ext.lower()

    return f"photos/original/photo_{uuid4()}{ext}"


@app.route("/")
def homepage():
    with get_db_connect("read") as conn:
        rows = conn.execute(select(photos)).mappings().all()

    prepared_photos = []

    for row in rows:
        photo = dict(row)

        original_key = photo["photo_filename"]
        thumbnail_key = photo["thumbnail_filename"] or original_key

        photo["photo_url"] = build_photo_url(original_key)
        photo["thumbnail_url"] = build_photo_url(thumbnail_key)

        prepared_photos.append(photo)

    return render_template(
        "index.html",
        photos=prepared_photos,
        delete_url=url_for("delete_photo"),
        insert_url=url_for("insert_photo"),
    )


@app.route("/delete")
def delete_photo():
    photo_id = request.args.get("id", type=int)

    if photo_id is None:
        return redirect(url_for("homepage"))

    with get_db_connect("write") as conn:
        photo = conn.execute(
            select(photos).where(photos.c.id == photo_id)
        ).mappings().first()

        if photo and photo["photo_filename"]:
            s3.delete_object(
                Bucket=S3_BUCKET_NAME,
                Key=photo["photo_filename"],
            )

        conn.execute(delete(photos).where(photos.c.id == photo_id))
        conn.commit()

    return redirect(url_for("homepage"))


@app.route("/insert", methods=["POST"])
def insert_photo():
    uploaded_file = request.files.get("photo")
    photo_key = None

    try:
        if uploaded_file and uploaded_file.filename:
            photo_key = generate_s3_key(uploaded_file)

            extra_args = {}

            if uploaded_file.mimetype:
                extra_args["ContentType"] = uploaded_file.mimetype

            s3.upload_fileobj(
                uploaded_file,
                S3_BUCKET_NAME,
                photo_key,
                ExtraArgs=extra_args,
            )

        with get_db_connect("write") as conn:
            conn.execute(
                insert(photos).values(
                    {
                        "title": request.form.get("title", "").strip(),
                        "photo_filename": photo_key,
                        "thumbnail_filename": None,
                    }
                )
            )
            conn.commit()

        return redirect(url_for("homepage"))

    except Exception as e:
        return f"Fehler beim Upload: {e}", 500

@app.route("/photos/<path:object_key>")
def serve_photo(object_key):
    try:
        obj = s3.get_object(
            Bucket=S3_BUCKET_NAME,
            Key=object_key
        )

        return Response(
            obj["Body"].read(),
            content_type=obj.get("ContentType", "application/octet-stream")
        )

    except ClientError:
        abort(404)


@app.route("/health")
def health():
    return "OK", 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)