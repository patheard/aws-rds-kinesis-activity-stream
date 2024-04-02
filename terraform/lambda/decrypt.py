# https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/DBActivityStreams.Monitoring.html#DBActivityStreams.CodeExample
import base64
import json
import logging
import os
import zlib

import boto3
import aws_encryption_sdk
from aws_encryption_sdk import CommitmentPolicy
from aws_encryption_sdk.internal.crypto import WrappingKey
from aws_encryption_sdk.key_providers.raw import RawMasterKeyProvider
from aws_encryption_sdk.identifiers import WrappingAlgorithm, EncryptionKeyType

AWS_REGION = os.environ.get("AWS_REGION")
RDS_ACTIVITY_STREAM_NAME = os.environ.get("RDS_ACTIVITY_STREAM_NAME")
RDS_ACTIVITY_STREAM_ID = RDS_ACTIVITY_STREAM_NAME[len("aws-rds-das-") :]

enc_client = aws_encryption_sdk.EncryptionSDKClient(
    commitment_policy=CommitmentPolicy.FORBID_ENCRYPT_ALLOW_DECRYPT
)
kms = boto3.client("kms", region_name=AWS_REGION)
logging.getLogger().setLevel(logging.ERROR)


def handler(event, context):
    output = []
    logging.info(f"Received {len(event['records'])} Kinesis records to process...")

    for record in event["records"]:
        record_data = base64.b64decode(record["data"])
        record_data = json.loads(record_data)
        payload_decoded = base64.b64decode(record_data["databaseActivityEvents"])
        data_key_decoded = base64.b64decode(record_data["key"])
        data_key_decrypt_result = kms.decrypt(
            CiphertextBlob=data_key_decoded,
            EncryptionContext={"aws:rds:dbc-id": RDS_ACTIVITY_STREAM_ID},
        )
        plain_text = decrypt_decompress(
            payload_decoded, data_key_decrypt_result["Plaintext"]
        )

        output_record = {
            "recordId": record["recordId"],
            "result": "Ok",
            "data": base64.b64encode(plain_text).decode("utf-8"),
        }
        output.append(output_record)

    return {"records": output}


class MyRawMasterKeyProvider(RawMasterKeyProvider):
    provider_id = "BC"

    def __new__(cls, *args, **kwargs):
        obj = super(RawMasterKeyProvider, cls).__new__(cls)
        return obj

    def __init__(self, plain_key):
        RawMasterKeyProvider.__init__(self)
        self.wrapping_key = WrappingKey(
            wrapping_algorithm=WrappingAlgorithm.AES_256_GCM_IV12_TAG16_NO_PADDING,
            wrapping_key=plain_key,
            wrapping_key_type=EncryptionKeyType.SYMMETRIC,
        )

    def _get_raw_key(self, key_id):
        return self.wrapping_key


def decrypt_payload(payload, data_key):
    my_key_provider = MyRawMasterKeyProvider(data_key)
    my_key_provider.add_master_key("DataKey")
    decrypted_plaintext, header = enc_client.decrypt(
        source=payload,
        materials_manager=aws_encryption_sdk.materials_managers.default.DefaultCryptoMaterialsManager(
            master_key_provider=my_key_provider
        ),
    )
    return decrypted_plaintext


def decrypt_decompress(payload, key):
    decrypted = decrypt_payload(payload, key)
    return zlib.decompress(decrypted, zlib.MAX_WBITS + 16)
