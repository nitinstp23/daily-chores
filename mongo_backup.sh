#!/usr/bin/env bash

# Set local time zone
TZ=Asia/Kolkata date

FILE_NAME="app-name-prod-`date +%Y-%m-%d-%H-%M`.tar.gz"
SAVE_DIR="/home/dev/backup"
S3BUCKET="app-name-mongodb"

# Load env settings
source /home/dev/backup/.env

echo "Locking DB for any write operations"
# Lock the DB for any write operations
mongo admin --host ${MONGO_HOST} --eval "printjson(db.fsyncLock())" > /dev/null 2>&1

echo "Taking DB dump..."
mongodump --host ${MONGO_HOST} --quiet -d ${DB_NAME} -o ${SAVE_DIR}/${DB_NAME}.json

echo "Unlocking DB to allow write operations"
# Unlock the DB to allow write operations
mongo admin --host ${MONGO_HOST} --eval "printjson(db.fsyncUnlock())" > /dev/null 2>&1

echo "Compressing DB dump folder"
# Compress the backup folder
tar -zcvf ${SAVE_DIR}/${FILE_NAME} ${SAVE_DIR}/${DB_NAME}.json/ > /dev/null 2>&1

if [ -e ${SAVE_DIR}/${FILE_NAME} ]; then
  echo "Dump file created, starting upload to S3"

  # Upload to AWS
  /usr/local/bin/aws s3 cp ${SAVE_DIR}/${FILE_NAME} s3://${S3BUCKET}/${FILE_NAME}

  # Test result of last command run
  if [ "$?" -ne "0" ]; then
    echo "Upload to AWS failed at - `date +%Y-%m-%d-%H-%M`"
    exit 1
  fi

  # If success, remove backup file and folder
  rm ${SAVE_DIR}/${FILE_NAME}
  rm -rf ${SAVE_DIR}/${DB_NAME}.json/

  echo "Backup file created at - `date +%Y-%m-%d-%H-%M`"

  # Exit with no error
  exit 0
fi

# Exit with error if we reach this point
echo "Backup file not created"
exit 1
