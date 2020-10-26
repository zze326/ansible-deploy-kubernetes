cfssl gencert -initca json_file/ca-csr.json | cfssl-json -bare ca -
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=json_file/ca-config.json -profile=kubernetes json_file/server-csr.json | cfssl-json -bare server
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=json_file/ca-config.json -profile=kubernetes json_file/admin-csr.json | cfssl-json -bare admin
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=json_file/ca-config.json -profile=kubernetes json_file/kube-proxy-csr.json | cfssl-json -bare kube-proxy