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
yarn add --cwd packages/backend better-sqlite3
yarn build
yarn build-image -t backstage:dev
kind load docker-image backstage:dev
```

When the image has been uploaded, install the backstage repository:
```bash
helm repo add backstage https://vinzscam.github.io/backstage-chart
```

If the resources of the chart must be changed locally, then pull/untar the project:
```bash
helm pull https://github.com/vinzscam/backstage-chart/releases/download/backstage-0.2.0/backstage-0.2.0.tgz --untar --untardir ./
```

We can now create the YAML values file used by the Helm chart to install backstage on a k8s cluster
```bash
DOMAIN_NAME="192.168.1.90.nip.io"
cat <<EOF > $HOME/code/backstage/app-config.extra.yaml
app:
  baseUrl: http://backstage.$DOMAIN_NAME
  title: Backstage
backend:
  baseUrl: http://backstage.$DOMAIN_NAME
  cors:
    origin: http://backstage.$DOMAIN_NAME

  # This is for local development only, it is not recommended to use this in production
  # The production database configuration is stored in app-config.production.yaml
  database:
    client: better-sqlite3
    connection: ':memory:'
  cache:
    store: memory
techdocs:
  builder: 'local' # Alternatives - 'external'
  generator:
    runIn: 'docker' # Alternatives - 'local'
  publisher:
    type: 'local' # Alternatives - 'googleGcs' or 'awsS3'. Read documentation for using alternatives.
EOF

cat <<EOF > $HOME/code/backstage/my-values.yml
ingress:
  enabled: true
  host: backstage.$DOMAIN_NAME
backstage:
  image:
    registry: "docker.io/library"
    repository: "backstage"
    tag: "dev"
  extraAppConfig:
    - filename: app-config.extra.yaml
      configMapRef: my-app-config      
EOF
```
We can deploy it
```bash
helm install -f $HOME/code/backstage/my-values.yml --create-namespace -n backstage my-backstage ./backstage
kubectl delete configmap my-app-config -n backstage && kubectl create configmap my-app-config -n backstage --from-file=app-config.extra.yaml=$HOME/code/backstage/app-config.extra.yaml
```
To uninstall the chart
```bash
helm uninstall my-backstage -n backstage
```

## Deprecated

Instructions using the backstage contrib helm chart

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

The backend's pod cannot start successfully as it reports the following error
```bash
(node:1) [DEP0148] DeprecationWarning: Use of deprecated folder mapping "./" in the "exports" field module resolution of the package at /app/node_modules/yaml/package.json.
Update this package.json to use a subpath pattern like "./*".
(Use `node --trace-deprecation ...` to show where the warning was created)
2022-06-17T11:18:54.432Z backstage info Loaded config from app-config.yaml, app-config.development.yaml, env
2022-06-17T11:18:54.445Z backstage info 1 secrets found in the config which will be redacted
2022-06-17T11:18:54.464Z backstage info Created UrlReader predicateMux{readers=azure{host=dev.azure.com,authed=false},bitbucketCloud{host=bitbucket.org,authed=false},github{host
=github.com,authed=true},gitlab{host=gitlab.com,authed=false},awsS3{host=amazonaws.com,authed=false},fetch{}
Backend failed to start up, Error: Failed to connect to the database to make sure that 'backstage_plugin_catalog' exists, Error: getaddrinfo ENOTFOUND dummy
```
To uninstall the chart
```bash
helm uninstall backstage -n backstage
```

## To be checked

```
cd ../app
yarn build

kind load docker-image backstage-app:dev
```
