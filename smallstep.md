## Instructions

See: https://smallstep.com/practical-zero-trust/kubernetes-ingress-tls?deployment=linux&provisioner=acme

```sh
brew install step

rm -rf /Users/cmoullia/.step/
echo "I'm_ToT007" > temp/step-pwd.txt
step ca init \
  --deployment-type=standalone \
  --name=snowdrop \
  --address=localhost:9943 \
  --dns=localhost \
  --provisioner=admin@snowdrop.dev \
  --password-file=temp/step-pwd.txt

Generating root certificate... done!
Generating intermediate certificate... done!

✔ Root certificate: /Users/cmoullia/.step/certs/root_ca.crt
✔ Root private key: /Users/cmoullia/.step/secrets/root_ca_key
✔ Root fingerprint: 9c4eb45ee1180b4eaa555a41af0f340a960a353f0ce722c1e953c64ea69a545c
✔ Intermediate certificate: /Users/cmoullia/.step/certs/intermediate_ca.crt
✔ Intermediate private key: /Users/cmoullia/.step/secrets/intermediate_ca_key
✔ Database folder: /Users/cmoullia/.step/db
✔ Default configuration: /Users/cmoullia/.step/config/defaults.json
✔ Certificate Authority configuration: /Users/cmoullia/.step/config/ca.json
```

Launch the CA Server
```sh
step-ca $(step path)/config/ca.json --password-file ./temp/step-pwd.txt
```
Get the root CA
```sh
step ca root ca.crt
```