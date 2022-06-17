# Backstage

## Prerequisites

- Node (>= 16), npm and npx installed
- docker and kind available

## Instructions

Here are the steps I followed to install backstage on a k8s cluster according to the backstage documentation
and feedback that I got from the backstage engineers

Open a terminal and execute this command within the folder where you want to launch backstage
```bash
npx @backstage/create-app
npx: installed 70 in 12.614s
? Enter a name for the app [required] my-backstage
...
🥇  Successfully created my-backstage

 All set! Now you might want to:
  Run the app: cd my-backstage && yarn dev
  Set up the software catalog: https://backstage.io/docs/features/software-catalog/configuration
  Add authentication: https://backstage.io/docs/auth/
```
When the `yarn build` is over, move to the folder of the created project and test it locally using the URL `http://localhost:3000/`
```bash
cd my-backstage && yarn dev
```

Next, build it like the backend image and upload it within your local registry (or kind cluster)
```bash
#yarn add --cwd packages/app graphql-ws
yarn build
yarn build-image -t backstage:dev
kind load docker-image backstage:dev
```

When the image has been uploaded we can create the YAML values file used by the Helm chart to install backstage on a k8s cluster

```bash
git clone https://github.com/backstage/backstage.git
cd contrib/chart/backstage
helm dependency update

DOMAIN_NAME="192.168.1.90.nip.io"
cat <<EOF > $HOME/code/backstage/my-values.yml
backend:
  image:
    repository: backstage
    tag: dev
postgresql:
  enabled: false
# primary:
#    initdb:
#      scriptsSecret: backstage-postgresql-initdb 
#  service:
#   port: 5432 

lighthouse:
  # enabled: false
  database:
    connection:
      host: dummy
      user: dummy
      password: dummy
         
appConfig:
  app:
    baseUrl: https://backstage.$DOMAIN_NAME
    title: Backstage
    
  backend:
    database:
      connection:
        host: dummy
        user: dummy
        password: dummy
    baseUrl: https://backstage.$DOMAIN_NAME
    cors:
      origin: https://backstage.$DOMAIN_NAME
      
  lighthouse:
    enabled: false
    baseUrl: https://backstage.$DOMAIN_NAME/lighthouse-api
    
  techdocs:
    storageUrl: https://backstage.$DOMAIN_NAME/api/techdocs/static/docs
    requestUrl: https://backstage.$DOMAIN_NAME/api/techdocs
EOF

helm install --create-namespace -f $HOME/code/backstage/my-values.yml -n backstage backstage .
```
To uninstall the chart
```bash
helm uninstall backstage -n backstage
```

## Error

## To be checked

```
cd ../app
yarn build

kind load docker-image backstage-app:dev
```
