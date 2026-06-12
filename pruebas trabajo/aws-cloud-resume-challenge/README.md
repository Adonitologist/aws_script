# Cloud Resume Challenge

This repository contains the complete infrastructure-as-code and automation logic for my cloud-hosted resume. This project demonstrates proficiency in AWS serverless architecture, CI/CD automation, and software testing.

## Architecture
* **Frontend:** Hosted on **AWS S3** and served globally via **Amazon CloudFront**.
* **Backend:** Serverless API powered by **AWS Lambda** (Python 3.13) and **Amazon API Gateway**.
* **Database:** **Amazon DynamoDB** stores the visitor count.
* **IaC:** Entire stack deployed using **Terraform** with remote state management in S3.
* **CI/CD:** Fully automated pipeline using **GitHub Actions** with OIDC-based secure AWS authentication.

## CI/CD Pipeline
Every push to the `main` branch triggers an automated workflow:
1. **Authentication:** Uses OpenID Connect (OIDC) to assume a secure AWS IAM role.
2. **Testing:** Executes Python unit tests using `unittest` and `moto` to validate backend logic in a mocked environment.
3. **Infrastructure:** Runs `terraform apply` to provision or update AWS resources.
4. **Deployment:** Syncs frontend assets to S3 and invalidates the CloudFront cache.

## Backend Automated Testing
To ensure the visitor counter logic is robust, I implemented automated testing:
* **Framework:** Python `unittest`.
* **Mocking:** Used `moto` to simulate DynamoDB locally, ensuring tests run in the CI pipeline without needing live infrastructure access.

## Repository Structure
* `/backend`: Contains the Lambda function logic (`lambda_function.py`) and unit tests (`test_lambda.py`).
* `/frontend`: Contains the static website assets.
* `main.tf`: Terraform configuration file for the entire infrastructure stack.
* `.github/workflows/`: Contains the CI/CD pipeline definition (`frontend-deploy.yml`).

## Technologies Used
* **AWS:** S3, CloudFront, Lambda, API Gateway, DynamoDB, IAM, OIDC.
* **Tools:** Terraform, Python, GitHub Actions, Moto.