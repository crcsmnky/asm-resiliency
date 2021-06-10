# Demo: Understanding & Implementing Resiliency using Anthos Service Mesh

> “Since failure is unavoidable, why not deliberately introduce it to ensure your systems and processes can deal with the failure"
>
> -- (via [What is Chaos Testing / Engineering](https://boyter.org/2016/07/chaos-testing-engineering/))

## Prerequisites

1. A GCP project with billing set up. 
2. [gcloud](https://cloud.google.com/sdk/docs/quickstarts) 
3. [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
4. [kpt](https://github.com/GoogleContainerTools/kpt)
5. [jq](https://stedolan.github.io/jq/)
6. [terraform](https://www.terraform.io/downloads.html)
7. [httpie](https://httpie.io/docs#installation)

## Infrastructure Setup

Move to the `infrastructure` directory

```
cd infrastructure
```

Initialize the `terraform` environment

```
terraform init
```

Review the changes that Terraform will make using `plan`

```
terraform plan -var project_id=[PROJECT_ID]
```

Use `apply` to deploy the changes and create the base infrastructure

```
terraform apply -auto-approve -var project_id=[PROJECT_ID]
```

Grab the cluster credentials and activate ASM proxy auto-injection on the `default` Namespace

```
gcloud container clusters get-credentials [CLUSTER_NAME]
REV=$(kubectl get pods -n istio-system -l app=istiod -o jsonpath='{.items[0].metadata.labels.istio\.io\/rev}')
kubectl label ns default istio.io/rev=$REV
```

Deploy sample app (and associated traffic configurations)

```
cd ..
kubectl apply -f bookinfo/
```

Open the app

```
INGRESS=$(kubectl get svc -n istio-system -l istio=ingressgateway -o jsonpath='{.items..status.loadBalancer.ingress..ip}')

echo $INGRESS

http $INGRESS/productpage
```

## Part 1 - Delays and Aborts

Let's start by develop an understanding of how our sample app will operate in the face of failure, by introducing a series of delays and aborts.

Setup "connection aborts" to `details` and `ratings`

```
kubectl apply -f understanding/ratings-abort.yaml -f understanding/details-abort.yaml
```

Now let's send some traffic, using a simple load generating script

```
bookinfo/loadgen.sh 10 $INGRESS/productpage
```

The script sends 10 requests per iteration, and with 10 iterations it sent 100 requests. The script itself splits the requests 60/40 between a standard user and a logged-in user. With the aborts applied, logged-in users would see 500 errors from the ratings service, while all users would see 500 errors from the details service.

Head to the [Anthos Service Mesh console](https://console.cloud.google.com/anthos/services) to view the health of the deployed services.

## Part 2 - Timeouts, Retries, and Circuit Breakers

Now, let's update the deployment to make the app more resilient in the face of outages.

Apply some retry logic to the reviews service, so that in case of 500 errors, it will automatically retry calls to a downstream service

```
kubectly apply -f implementing/ratings-retries.yaml
```

Again, let's send some traffic using the load generating script

```
bookinfo/loadgen.sh 10 $INGRESS/productpage
```

Head to the [Anthos Service Mesh console](https://console.cloud.google.com/anthos/services) to view the health of the deployed services.

## Cleanup

Use `destroy` to remove all of the deployed infrastructure

```
cd infrastructure
terraform destroy
```

## Learn More

- [Anthos Service Mesh documentation](https://cloud.google.com/service-mesh/docs)
- [Network resilience and testing](https://istio.io/latest/docs/concepts/traffic-management/#network-resilience-and-testing)