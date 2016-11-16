#! /usr/bin/env bash
#
# Simple script to create a new s3 account and associed credentials.
# Use the aws utility.

set -e
uuid=$(uuidgen)
while true; do
    read -e -p "Site name: " -i "${site_name}" site_name
    if [  ! -z "$site_name" ]; then
        break
    fi
done
sed -i -e 's@replace_with_sitename@'"$(echo $site_name | sed 's/ /\\ /g')"'@g' docker-compose.yml

server_prefix=${site_name// /-}
server_prefix=${server_prefix,,}

wordpress_url=http://localhost/
while true; do
    read -e -p "Wordpress url with trailing slash (local or remote): " -i "${wordpress_url}" wordpress_url
    if [  ! -z "$wordpress_url" ]; then
        break
    fi
done
sed -i -e 's@http://localhost/@'${wordpress_url}'@g' docker-compose.yml

read -e -p "Would you like to create a digital ocean droplet? (y/n): " -i "n" run
if [ "$run" == y ] ; then


    while true; do
        read -e -p "Server prefix (only letters and dashes): " -i "${server_prefix}" server_prefix
        if [  ! -z "$server_prefix" ]; then
            break
        fi
    done
    

    server_name=${server_prefix}-${uuid}
    server_name=${server_name:0:63}
    ssh_key_path=~/.ssh/studioup_clients

    while true; do
        read -e -p "Private ssh key path: " -i "$ssh_key_path" ssh_key_path
        if [  ! -z "$ssh_key_path" ]; then
            break
        fi
    done
    ssh_public_key=$(ssh-keygen -E md5 -lf $ssh_key_path'.pub')
    ssh_public_key=$(echo $ssh_public_key | sed 's#[0-9]\{4\} MD5:##g' | sed 's#\ .\{1,\}$##g')
    echo "ssh public key: " ${ssh_public_key}
    echo "server name:" ${server_name}
    #set -x;
    json_ouput="$(doctl compute droplet create ${server_name} --size 512mb --image docker --region fra1 --ssh-keys ${ssh_public_key} --enable-backups --output json)"

    echo $json_output

    server_id=$(echo ${json_output} | jq --raw-output '.[0].id')
    #server_name=$(echo ${json_output} | jq --raw-output '.[0].name')
    echo "server id : "$server_id
    #echo $server_name
    #secs=$(( 60))
    #echo "Waiting for droplet creation"
    #while [ $secs -gt 0 ]; do
        
    #    echo -ne "Waiting for droplet creation... $secs\033[0K\r"
    #    sleep 1
    #    : $((secs--))
    #done

    #json_output=$(doctl compute droplet get ${server_id} --output json)
    #server_ip=$(echo $json_output | jq --raw-output '.[0].networks.v4[0].ip_address')
    #sed -i -e 's@replace_with_droplet_id@'${server_id}'@g' ssh.sh
    sed -i -e 's@replace_with_droplet_id@'${server_name}'@g' ssh.sh
    sed -i -e 's@replace_with_ssh_private_key_path@'${ssh_key_path}'@g' ssh.sh
    #~/.ssh/studioup_clients
    #doctl compute ssh 32189244 --ssh-key-path ~/.ssh/studioup_clients --output json 

    #set +x;
fi

read -e -p "Would you like to configure the db? (y/n): " -i "n" run
if [ "$run" == y ] ; then
    RANDOM_SEED=$( uuidgen | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    dbname=${server_prefix}-${RANDOM_SEED}
    dbname=${dbname:0:15}
    while true; do
        read -e -p "DB name: " -i "${dbname}" dbname
        dbname=${dbname:0:15}
        if [  ! -z "$dbname" ]; then
            break
        fi
    done
    sed -i -e 's@replace_with_wp_db_name@'${dbname}'@g' docker-compose.yml

    RANDOM_SEED=$( uuidgen | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    dbuser=${server_prefix}-${RANDOM_SEED}
    dbuser=${dbuser:0:15}
    while true; do
        read -e -p "DB user: " -i "${dbuser}" dbuser
        dbuser=${dbuser:0:15}
        if [  ! -z "$dbuser" ]; then
            break
        fi
    done
    sed -i -e 's@replace_with_wp_db_user@'${dbuser}'@g' docker-compose.yml

    RANDOM_SEED=$( uuidgen | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    dbpassw=${RANDOM_SEED}
    while true; do
        read -e -p "DB password: " -i "${dbpassw}" dbpassw
        dbpassw=${dbpassw:0:15}
        if [  ! -z "$dbpassw" ]; then
            break
        fi
    done
    sed -i -e 's@replace_with_wp_db_password@'${dbpassw}'@g' docker-compose.yml

    RANDOM_SEED=$( uuidgen | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    dbpassw=${RANDOM_SEED}
    while true; do
        read -e -p "DB root password: " -i "${dbpassw}" dbpassw
        dbpassw=${dbpassw:0:15}
        if [  ! -z "$dbpassw" ]; then
            break
        fi
    done
    sed -i -e 's@replace_with_root_db_password@'${dbpassw}'@g' docker-compose.yml

    RANDOM_SEED=$( uuidgen | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)
    table_prefix=${RANDOM_SEED}
    while true; do
        read -e -p "Table prefix: " -i "${table_prefix}" table_prefix
        dbpassw=${table_prefix:0:15}
        if [  ! -z "$table_prefix" ]; then
            break
        fi
    done
    sed -i -e 's@replace_with_wp_table_prefix@'${table_prefix}'_@g' docker-compose.yml
fi

read -e -p "Would you like to configure the admin user? (y/n): " -i "n" run
if [ "$run" == y ] ; then
    adminuser=studioup
    while true; do
        read -e -p "Admin user: " -i "${adminuser}" adminuser
        if [  ! -z "$adminuser" ]; then
            break
        fi
    done
    sed -i -e 's@replace_with_wp_admin_user@'${adminuser}'@g' docker-compose.yml

    adminemail=info@studioup.it
    while true; do
        read -e -p "Admin email: " -i "${adminemail}" adminemail
        if [  ! -z "$adminemail" ]; then
            break
        fi
    done
    sed -i -e 's#replace_with_wp_admin_email#'${adminemail}'#g' docker-compose.yml

    adminpassw=$( uuidgen | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    while true; do
        read -e -p "Admin password: " -i "${adminpassw}" adminpassw
        adminpassw=${adminpassw:0:15}
        if [  ! -z "$adminpassw" ]; then
            break
        fi
    done
    sed -i -e 's@replace_with_wp_admin_pass@'${adminpassw}'@g' docker-compose.yml

fi

read -e -p "Would you like to set up amazon S3 and SES? (y/n): " -i "n" run
if [ "$run" == y ] ; then
    ./aws.sh
fi


if [ -f docker-compose.yml-e ]; then
  rm -f docker-compose.yml-e
fi
if [ -f ssh.sh-e ]; then
  rm -f ssh.sh-e
fi