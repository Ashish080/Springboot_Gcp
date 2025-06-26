# Infrastructure Setup with Terraform and Google Cloud

## 📦 Step-by-Step Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/Ashish080/Springboot_Gcp.git
cd Springboot_Gcp
```

### 2. Prepare Terraform Variables

Copy the provided `terraform.tfvars` file to the root of the repo and edit it with your GCP project details:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit the `terraform.tfvars` file:

```hcl
project_id   = "your-gcp-project-id"
region  = "your-gcp-project-region"

```
open the `application.properties`

```bash
cd src/main/resources
vim application.properties
```
```hcl
spring.cloud.gcp.sql.database-name=studentdb
spring.cloud.gcp.sql.instance-connection-name=<your-gcp-project-id>:<your-gcp-project-region>:postgres-instance
spring.cloud.gcp.project-id=your-gcp-project-id

spring.datasource.username=postgres
spring.datasource.password=${SPRING_DATASOURCE_PASSWORD}

spring.sql.init.mode=always
server.error.include-message=always
server.port=${PORT:8080}
```

### 3. Navigate to the Terraform Directory

```bash
cd intra
```

### 4. Authenticate with GCP

Run the following commands to authenticate and set your project:

```bash
gcloud auth login
gcloud config set project <your-project-id>
gcloud auth application-default login
```

### 5. Initialize and Plan Terraform

```bash
terraform init
terraform plan -var-file=../terraform.tfvars -out=tfplan
```

> This command checks the configuration and prepares the infrastructure plan.

### 6. Apply the Terraform Plan

```bash
terraform apply tfplan
```

After a successful apply, your infrastructure should be provisioned. You can verify it in the GCP Console.

---

## 🚀 Deploying the Application

Before running Cloud run, ensure your Docker image is ready.

### 7. Submit the Cloud Build

```bash
gcloud builds submit --config=cloudbuild.yaml
```
---

