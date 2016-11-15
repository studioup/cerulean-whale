#! /usr/bin/env bash
#
# Simple script to create a new s3 account and associed credentials.
# Use the aws utility.

set -e

while true; do
    read -e -p "Bucket Prefix (only letters and dashes): " -i "${bucket_prefix}" bucket_prefix
    if [  ! -z "$bucket_prefix" ]; then
        break
    fi
done
uuid=$(uuidgen)
bucket_name=${bucket_prefix}-${uuid}
bucket_name=${bucket_name:0:63}
bucket_name=${bucket_name,,}
bucket_user=${bucket_name,,}
bucket_region="eu-west-1"
while true; do
    read -e -p "Bucket Region: " -i "${bucket_region}" bucket_region
    if [ ! -z "$bucket_region" ]; then
        break
    fi
done

while true; do
    read -e -p "Second level domain (no http://): " -i "${domain_name}" domain_name
    if [ ! -z "$domain_name" ]; then
        break
    fi
done





printf "Creating user '${bucket_user,,}'... "
json_ouput=$(aws iam create-user --user-name $bucket_user)
echo "done."

printf "Creating new access and secret key... "
json_output=$(aws iam create-access-key --user-name $bucket_user)
access_id=$(echo $json_output | jq --raw-output '.AccessKey.AccessKeyId')
secret_key=$(echo $json_output | jq --raw-output '.AccessKey.SecretAccessKey')
echo "done."

printf "Creating new bucket... "
bucket_url="s3://${bucket_name}"
json_ouput=$(aws s3 mb --region $bucket_region $bucket_url)
echo "done."

printf "Generating user policy... "
policy_json_path="/tmp/${bucket_user}.json"
cat << EOF > $policy_json_path
{
  "Statement": [
    {
      "Action": "s3:*",
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${bucket_name}",
        "arn:aws:s3:::${bucket_name}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ses:SendRawEmail"
      ],
      "Resource": [
        "*"
      ]
    }

  ]
}
EOF
json_ouput=$(aws iam put-user-policy --user-name $bucket_user --policy-name s3build --policy-document file://$policy_json_path)

json_ouput=$(aws ses verify-domain-identity --domain $domain_name)
verification_token=$(echo $json_output | jq --raw-output '.VerificationToken')



IAMSECRET="$2";
MSG="SendRawEmail";
VerInBytes="2";
VerInBytes=$(printf \\$(printf '%03o' "$VerInBytes"));

SignInBytes=$(echo -n "$MSG"|openssl dgst -sha256 -hmac "$secret_key" -binary);
SignAndVer=""$VerInBytes""$SignInBytes"";
SmtpPass=$(echo -n "$SignAndVer"|base64);
sender_email=noreply@$domain_name
replyto_email=info@$domain_name

sed -i -e 's@replace_with_s3_bucket@'${bucket_name}'@g' docker-compose.yml
sed -i -e 's@replace_with_s3_key@'${access_id}'@g' docker-compose.yml
sed -i -e 's@replace_with_s3_secret@'${secret_key}'@g' docker-compose.yml
sed -i -e 's@replace_with_s3_region@'${bucket_region}'@g' docker-compose.yml
sed -i -e "s@S3_UPLOADS_AUTOENABLE:\ 'false'@S3_UPLOADS_AUTOENABLE:\ 'true'@g" docker-compose.yml
sed -i -e 's@replace_with_ses_smtp_url@email-smtp.'${bucket_region}'.amazonaws.com@g' docker-compose.yml
sed -i -e 's@replace_with_ses_smtp_user@'${access_id}'@g' docker-compose.yml
sed -i -e 's@replace_with_ses_smtp_password@'${SmtpPass}'@g' docker-compose.yml
sed -i -e 's@SMTP_ENC_TYPE:\ tls@SMTP_ENC_TYPE:\ tls@g' docker-compose.yml
sed -i -e 's@SMTP_PORT:\ 587@SMTP_PORT:\ 587@g' docker-compose.yml
sed -i -e 's#replace_with_sender_email#'${sender_email}'#g' docker-compose.yml
#sed -i -e 's@replace_with_sender_email@noreply'${email_domain_name}'@g' docker-compose.yml
sed -i -e 's#replace_with_replyto_email#'${replyto_email}'#g' docker-compose.yml
if [ -f docker-compose.yml-e ]; then
  rm -f docker-compose.yml-e
fi

echo "done."
echo ""
echo "                IAM user: ${bucket_user}"
echo "             Bucket name: ${bucket_name}"
echo "    Amazon Access Key ID: ${access_id}"
echo "Amazon Secret Access Key: ${secret_key}"
echo "               SMTP Pass: ${SmtpPass}"
echo ""
echo "             Record Type: TXT (Text)"
echo "               TXT Name*: _amazonses.${domain_name}"
echo "               TXT Value: ${verification_token}"
echo ""