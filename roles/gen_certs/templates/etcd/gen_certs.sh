{{ cfssl_bin }} gencert -initca json_file/ca-csr.json | {{ cfssl_json_bin }} -bare ca -
{{ cfssl_bin }} gencert -ca=ca.pem -ca-key=ca-key.pem -config=json_file/ca-config.json -profile=www json_file/server-csr.json | {{ cfssl_json_bin }} -bare server
{% if ansible_distribution == 'Ubuntu' %}chown {{ exec_user }}.{{ exec_user }} *.pem{% endif %}