# AWS RDS to Kinesis database activity stream
Creates an RDS cluster with an activity stream enabled.  This is then used as a source for Kinesis Firehose which uses a Lambda function to decrypt the activity and save it to an S3 bucket.

```sh
# To setup, run the following from the devcontainer
cd terraform
terraform init
terraform apply
```

This is based on the folloing AWS blog post.
- [Part 2: Audit Aurora PostgreSQL databases using Database Activity Streams and pgAudit](https://aws.amazon.com/blogs/database/part-2-audit-aurora-postgresql-databases-using-database-activity-streams-and-pgaudit/)