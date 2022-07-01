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
**Note**: Set this property if a more recent version of node is installed `yarn config set ignore-engines true`

Next, build the image and upload it within your local registry (or kind cluster)
```bash
yarn add --cwd packages/backend better-sqlite3
yarn build
yarn build-image -t backstage:dev
kind load docker-image backstage:dev
```
**Note**: For the rancher desktop users, use the `nerdctl tool` and this command: `nerdctl build -f Dockerfile -t backstage:dev ../..` instead of `yarn build-image -t backstage:dev`

We can now create the YAML values file used by the Helm chart to install backstage on a k8s cluster
```bash
DOMAIN_NAME="<VM_IP>.sslip.io"
cat <<EOF > $HOME/code/backstage/app-config.extra.yaml
app:
  baseUrl: http://backstage.$DOMAIN_NAME
  title: Backstage
backend:
  baseUrl: http://backstage.$DOMAIN_NAME
  cors:
    origin: http://backstage.$DOMAIN_NAME
    methods: [GET, POST, PUT, DELETE]
    credentials: true      
  csp:
    connect-src: ["'self'", 'http:', 'https:']
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
  className: nginx
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
and deploy it
```bash
helm upgrade --install \
  my-backstage \
  backstage \
  --repo https://vinzscam.github.io/backstage-chart \
  -f $HOME/code/backstage/my-values.yml \
  --create-namespace \
  -n backstage
  
kubectl create configmap my-app-config -n backstage \
  --from-file=app-config.extra.yaml=$HOME/code/backstage/app-config.extra.yaml
  
kubectl rollout restart deployment/my-backstage -n backstage
```
Grab the URL of backstage and access it from your browser
```bash
BACKSTAGE_URL=$(kubectl get ingress/my-backstage -n backstage -o json | jq -r '.spec.rules[0].host')
echo "http://${BACKSTAGE_URL}"
```

## Cleanup

To uninstall the chart
```bash
helm uninstall my-backstage -n backstage
```
**Note**: If the resources of the chart must be changed locally, then pull/untar the project:
```bash
helm pull https://github.com/vinzscam/backstage-chart/releases/download/backstage-0.2.0/backstage-0.2.0.tgz --untar --untardir ./
```
