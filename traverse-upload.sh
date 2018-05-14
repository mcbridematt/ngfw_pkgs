#!/bin/sh

if [ "${SSH_UPLOAD_PORT}" -eq 22 ] || [ -z "${SSH_UPLOAD_PORT+x}" ]; then
	echo "${SSH_UPLOAD_HOST} ${SSH_UPLOAD_HOST_KEY}" > upload_host_key
else
	echo "[${SSH_UPLOAD_HOST}]:${SSH_UPLOAD_PORT} ${SSH_UPLOAD_HOST_KEY}" > upload_host_key
fi

echo "${SSH_UPLOAD_KEY}" > upload_user_key
chmod 0600 upload_user_key
#scp -o 'HashKnownHosts no' -o 'UserKnownHostsFile upload_host_key' -P "${SSH_UPLOAD_PORT}" -i upload_user_key -r repo "${SSH_UPLOAD_USER}@${SSH_UPLOAD_HOST}:${SSH_UPLOAD_DIR}"
rsync --delete -e "ssh -o 'HashKnownHosts no' -o 'UserKnownHostsFile upload_host_key' -p ${SSH_UPLOAD_PORT} -i upload_user_key" -r repo/ -v "${SSH_UPLOAD_USER}@${SSH_UPLOAD_HOST}:${SSH_UPLOAD_DIR}"
