from google.cloud import storage


def upload_blob_from_file(bucket_name, source_file_name, destination_blob_name):
    """Uploads a file to the bucket."""
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)
    blob.upload_from_filename(
        source_file_name,
    )
    # print(f"File {source_file_name} uploaded to {destination_blob_name}.")


def upload_blob_from_memory(bucket_name, contents, destination_blob_name):
    """Uploads a file to the bucket."""
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)

    blob.upload_from_string(contents)

    # print(
    #     f"{destination_blob_name} with contents {contents} uploaded to {bucket_name}."
    # )


def upload_json(bucket_name, json_data, destination_blob_name):
    """Uploads a JSON object to the bucket."""
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)

    blob.upload_from_string(data=json_data, content_type="application/json")
    # print(f"JSON data uploaded to {destination_blob_name}.")


def read_json(bucket_name, source_blob_name):
    """Reads a JSON object from the bucket."""
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(source_blob_name)

    json_data = blob.download_as_string()
    return json_data


def double(x):
    return 2 * x


def add_one(x):
    return x + 1


def main():
    pass


if __name__ == "__main__":
    print("App started.")
    main()
    print("App finished")
