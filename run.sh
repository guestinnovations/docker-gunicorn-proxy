#!/bin/sh

if [ $SCHEME ]; then
	SCHEME_LINE="http-request set-header X-Forwarded-Proto ${SCHEME:-https}"
fi

HEADERS=$(env | awk -F '=' '{
	if(index($1, "HEADER_") > 0) {
		name=substr($1, 8);
		gsub("_", "-", name);
		st=index($0, "=");
		printf("http-response set-header %s \"%s\"\n", name, substr($0, st+1))
	}
}')

cat <<EOF > /usr/local/etc/haproxy/haproxy.cfg

global
	maxconn 256

defaults
	mode http
	timeout connect 5s
	timeout client 30s
	timeout server 30s
	timeout queue ${QUEUE_TIMEOUT:-3s}

frontend http
	bind *:80
	acl is_healthcheck path ${HEALTHCHECK_PATH:-/healthcheck}
	use_backend healthcheck if is_healthcheck
	default_backend app

backend app
	server main $SERVER maxconn $CONCURRENCY
	$SCHEME_LINE
	$HEADERS

backend healthcheck
	server main $SERVER

EOF

haproxy -f /usr/local/etc/haproxy/haproxy.cfg
