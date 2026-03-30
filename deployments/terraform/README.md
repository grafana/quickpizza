# QuickPizza Terraform Deployment

This directory contains Terraform configuration to deploy QuickPizza to a Kubernetes cluster (using Minikube) with Grafana Cloud integration.

## Setup

### 1. Start Minikube

```bash
minikube start
```

### 2. Configure Terraform Variables

Copy the reference configuration file:

```bash
cp terraform.tfvars.local terraform.tfvars
```

Edit `terraform.tfvars` and set your Grafana Cloud credentials:

- `grafana_cloud_stack`: Your Grafana Cloud stack name (e.g., "mystack")
- `grafana_cloud_token`: Your [Grafana Cloud  Access Policy Token](https://grafana.com/docs/grafana-cloud/account-management/authentication-and-permissions/access-policies/) that includes the following scopes for the selected Grafana Cloud Stack: `stacks:read`, `metrics:write`, `logs:write`, `traces:write`, and `profiles:write`.


See also `variables.tf` for all available configuration options you can setup in `terraform.tfvars`

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Preview Changes

```bash
terraform plan
```

### 5. Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm the deployment.

### 6. Access the Application

Set up port forwarding to access QuickPizza locally:

```bash
minikube tunnel
```

Keep this terminal open. 

QuickPizza should now be accessible at http://localhost:3333

## Using a Local Docker Image

To use a locally built QuickPizza image instead of the default from the registry:

1. Build the Docker image:
   ```bash
   docker build -t local-quickpizza:latest .
   ```

2. Load the image into Minikube:
   ```bash
   minikube image load local-quickpizza:latest
   ```

3. Update `terraform.tfvars`:
   ```hcl
   quickpizza_image = "local-quickpizza:latest"
   quickpizza_image_pull_policy = "Never"
   ```

4. Apply the changes:
   ```bash
   terraform apply
   ```

## Enable Kubernetes Monitoring

Update `terraform.tfvars` and set the required settings:

```hcl
enable_k8s_monitoring = true
cluster_name = ""
externalservices_prometheus_host = ""
externalservices_prometheus_basicauth_username = ""
externalservices_prometheus_basicauth_password = ""

externalservices_loki_host = ""
externalservices_loki_basicauth_username = ""
externalservices_loki_basicauth_password = ""
```